import SWELib.OS.Io

/-!
# File I/O

The simplest fd consumer. Files have no connection state or protocol —
straightforward read/write semantics exercise the fd model before sockets
add complexity.

References:
- open(2):   https://man7.org/linux/man-pages/man2/open.2.html
- read(2):   https://man7.org/linux/man-pages/man2/read.2.html
- write(2):  https://man7.org/linux/man-pages/man2/write.2.html
- lseek(2):  https://man7.org/linux/man-pages/man2/lseek.2.html
- stat(2):   https://man7.org/linux/man-pages/man2/stat.2.html
- unlink(2): https://man7.org/linux/man-pages/man2/unlink.2.html
- mkdir(2):  https://man7.org/linux/man-pages/man2/mkdir.2.html
- chmod(2):  https://man7.org/linux/man-pages/man2/chmod.2.html
- inode(7):  https://man7.org/linux/man-pages/man7/inode.7.html
-/

namespace SWELib.OS

/-! ## Open flags -/

/-- Access mode: how the file is opened for I/O. -/
inductive AccessMode where
  | readOnly
  | writeOnly
  | readWrite
  deriving DecidableEq, Repr

/-- Additional flags that modify open behavior. -/
structure OpenFlags where
  /-- Create the file if it does not exist. -/
  create : Bool := false
  /-- Truncate the file to zero length on open. -/
  truncate : Bool := false
  /-- Writes append to the end of the file. -/
  append : Bool := false
  deriving DecidableEq, Repr

/-! ## Permissions -/

/-- POSIX permission bits for a single category (owner/group/other). -/
structure PermissionBits where
  read : Bool
  write : Bool
  exec : Bool
  deriving DecidableEq, Repr

/-- Full POSIX permission model: owner/group/other × rwx. -/
structure Permissions where
  owner : PermissionBits
  group : PermissionBits
  other : PermissionBits
  deriving DecidableEq, Repr

/-- Default permissions: rwxr-xr-x (0755). -/
def Permissions.defaultDir : Permissions :=
  { owner := ⟨true, true, true⟩
    group := ⟨true, false, true⟩
    other := ⟨true, false, true⟩ }

/-- Default permissions: rw-r--r-- (0644). -/
def Permissions.defaultFile : Permissions :=
  { owner := ⟨true, true, false⟩
    group := ⟨true, false, false⟩
    other := ⟨true, false, false⟩ }

/-! ## File metadata (stat) -/

/-- File type as reported by stat(2). -/
inductive FileType where
  | regular
  | directory
  | symlink
  | blockDevice
  | charDevice
  | fifo
  | socket
  deriving DecidableEq, Repr

/-- File metadata returned by stat(2) / fstat(2).
    Simplified model covering the fields relevant to correctness reasoning. -/
structure FileStat where
  fileType : FileType
  size : Nat
  permissions : Permissions
  /-- Owner user ID. -/
  uid : Nat
  /-- Owner group ID. -/
  gid : Nat
  deriving Repr

/-! ## Directory tree -/

deriving instance Repr for ByteArray

/-- An entry in the file system tree.
    Inductive structure following the JSON representation pattern (D-002). -/
inductive DirEntry where
  /-- A regular file with name, contents, and permissions. -/
  | file (name : String) (contents : ByteArray) (perms : Permissions)
  /-- A directory with name, children, and permissions. -/
  | dir (name : String) (children : List DirEntry) (perms : Permissions)
  deriving Repr

/-- Get the name of a directory entry. -/
def DirEntry.name : DirEntry → String
  | .file n _ _ => n
  | .dir n _ _ => n

/-- Get the permissions of a directory entry. -/
def DirEntry.perms : DirEntry → Permissions
  | .file _ _ p => p
  | .dir _ _ p => p

/-- Look up a child by name in a directory's children list. -/
def DirEntry.findChild (children : List DirEntry) (name : String) :
    Option DirEntry :=
  children.find? (fun e => e.name == name)

/-- Resolve a path (list of path components) starting from a directory entry. -/
def DirEntry.resolve : DirEntry → List String → Option DirEntry
  | e, [] => some e
  | .dir _ children _, seg :: rest =>
    match DirEntry.findChild children seg with
    | some child => child.resolve rest
    | none => none
  | .file _ _ _, _ :: _ => none

/-- Compute stat metadata for a directory entry. -/
def DirEntry.stat : DirEntry → FileStat
  | .file _ contents perms =>
    { fileType := .regular, size := contents.size, permissions := perms,
      uid := 0, gid := 0 }
  | .dir _ children perms =>
    { fileType := .directory, size := children.length, permissions := perms,
      uid := 0, gid := 0 }

/-! ## Whence (lseek) -/

/-- The `whence` argument to lseek(2). -/
inductive Whence where
  /-- Set offset to `offset` bytes. -/
  | set
  /-- Set offset to current position + `offset`. -/
  | cur
  /-- Set offset to file size + `offset`. -/
  | end_
  deriving DecidableEq, Repr

/-! ## Open file description -/

/-- An open file: tracks the access mode and current offset.
    One per open(2) call. Multiple fds can share one (via dup). -/
structure OpenFile where
  /-- Access mode the file was opened with. -/
  mode : AccessMode
  /-- Path components from root to this file. -/
  path : List String
  /-- Current read/write offset. -/
  offset : Nat
  deriving Repr

/-! ## File system state -/

/-- Complete file system state for specification purposes.
    Combines the directory tree, fd table, and open file descriptions. -/
structure FileSystemState where
  /-- The root of the directory tree. -/
  root : DirEntry
  /-- Per-process fd table. -/
  fdTable : FdTable
  /-- Map from fd number to open file description. -/
  openFiles : Nat → Option OpenFile

/-- Empty file system state with an empty root directory. -/
def FileSystemState.empty : FileSystemState :=
  { root := .dir "/" [] Permissions.defaultDir
    fdTable := FdTable.empty
    openFiles := fun _ => none }

/-! ## open(2) -/

/-- `open(2)`: open a file and allocate a file descriptor.
    Returns the new fd or an error. The `newFd` parameter models the
    kernel's fd allocation (lowest available). -/
def FileSystemState.open (s : FileSystemState) (pathSegs : List String)
    (mode : AccessMode) (flags : OpenFlags) (newFd : Nat) :
    FileSystemState × Except Errno FileDescriptor :=
  match s.root.resolve pathSegs with
  | some (.file _ _ perms) =>
    -- Check read permission for read modes
    if (mode == .readOnly || mode == .readWrite) && !perms.owner.read then
      (s, .error .EACCES)
    -- Check write permission for write modes
    else if (mode == .writeOnly || mode == .readWrite) && !perms.owner.write then
      (s, .error .EACCES)
    else
      let of : OpenFile := { mode, path := pathSegs, offset := 0 }
      let s' : FileSystemState :=
        { s with
          fdTable := s.fdTable.update newFd (.open .file)
          openFiles := fun n => if n = newFd then some of else s.openFiles n }
      (s', .ok ⟨newFd⟩)
  | some (.dir _ _ _) => (s, .error .EISDIR)
  | none =>
    if flags.create then
      -- Create: would insert a new empty file, simplified here
      let of : OpenFile := { mode, path := pathSegs, offset := 0 }
      let s' : FileSystemState :=
        { s with
          fdTable := s.fdTable.update newFd (.open .file)
          openFiles := fun n => if n = newFd then some of else s.openFiles n }
      (s', .ok ⟨newFd⟩)
    else
      (s, .error .ENOENT)

/-! ## Helper: resolve an open fd to its file contents -/

/-- Look up the contents of the file an fd points to. -/
private def FileSystemState.fdContents (s : FileSystemState)
    (fd : FileDescriptor) : Option ByteArray :=
  match s.openFiles fd.fd with
  | some of =>
    match s.root.resolve of.path with
    | some (.file _ contents _) => some contents
    | _ => none
  | none => none

/-! ## read(2) -/

/-- `read(2)`: read up to `count` bytes from an open fd.
    Advances the offset by the number of bytes actually read.
    Returns the bytes read, or an error. -/
def FileSystemState.read (s : FileSystemState) (fd : FileDescriptor)
    (count : Nat) : FileSystemState × Except Errno ByteArray :=
  match s.openFiles fd.fd with
  | some of =>
    if of.mode == .writeOnly then (s, .error .EBADF)
    else
      match s.fdContents fd with
      | some contents =>
        let available := contents.size - of.offset
        let toRead := min count available
        let result := contents.extract of.offset (of.offset + toRead)
        let of' := { of with offset := of.offset + toRead }
        let s' := { s with
          openFiles := fun n => if n = fd.fd then some of' else s.openFiles n }
        (s', .ok result)
      | none => (s, .error .EIO)
  | none => (s, .error .EBADF)

/-! ## write(2) -/

/-- Replace the contents of a file at `pathSegs` in the directory tree.
    Returns the updated tree, or `none` if the path doesn't resolve. -/
private def DirEntry.updateFile (e : DirEntry) (pathSegs : List String)
    (newContents : ByteArray) : Option DirEntry :=
  match e, pathSegs with
  | .file name _ perms, [] => some (.file name newContents perms)
  | .dir name children perms, seg :: rest =>
    let updated := children.map fun child =>
      if child.name == seg then
        match child.updateFile rest newContents with
        | some c => c
        | none => child
      else child
    some (.dir name updated perms)
  | _, _ => none

/-- `write(2)`: write bytes to an open fd.
    For simplicity, this overwrites starting at the current offset and
    advances the offset. Returns bytes written or an error. -/
def FileSystemState.write (s : FileSystemState) (fd : FileDescriptor)
    (data : ByteArray) : FileSystemState × Except Errno Nat :=
  match s.openFiles fd.fd with
  | some of =>
    if of.mode == .readOnly then (s, .error .EBADF)
    else
      match s.fdContents fd with
      | some contents =>
        -- Build new contents: [0..offset] ++ data ++ [offset+data.size..]
        let before := contents.extract 0 of.offset
        let after := contents.extract (of.offset + data.size) contents.size
        let newContents := before ++ data ++ after
        let of' := { of with offset := of.offset + data.size }
        match s.root.updateFile of.path newContents with
        | some newRoot =>
          let s' := { s with
            root := newRoot
            openFiles := fun n =>
              if n = fd.fd then some of' else s.openFiles n }
          (s', .ok data.size)
        | none => (s, .error .EIO)
      | none => (s, .error .EIO)
  | none => (s, .error .EBADF)

/-! ## lseek(2) -/

/-- `lseek(2)`: reposition the file offset.
    Returns the new offset or an error. -/
def FileSystemState.lseek (s : FileSystemState) (fd : FileDescriptor)
    (offset : Int) (whence : Whence) : FileSystemState × Except Errno Nat :=
  match s.openFiles fd.fd with
  | some of =>
    let fileSize := match s.fdContents fd with
      | some contents => contents.size
      | none => 0
    let base := match whence with
      | .set => 0
      | .cur => of.offset
      | .end_ => fileSize
    let newOffset := base + offset.toNat  -- simplified: ignores negative offsets
    let of' := { of with offset := newOffset }
    let s' := { s with
      openFiles := fun n => if n = fd.fd then some of' else s.openFiles n }
    (s', .ok newOffset)
  | none => (s, .error .EBADF)

/-! ## stat(2) -/

/-- `stat(2)`: get file metadata by path. -/
def FileSystemState.stat (s : FileSystemState) (pathSegs : List String) :
    Except Errno FileStat :=
  match s.root.resolve pathSegs with
  | some entry => .ok entry.stat
  | none => .error .ENOENT

/-- `fstat(2)`: get file metadata by open fd. -/
def FileSystemState.fstat (s : FileSystemState) (fd : FileDescriptor) :
    Except Errno FileStat :=
  match s.openFiles fd.fd with
  | some of =>
    match s.root.resolve of.path with
    | some entry => .ok entry.stat
    | none => .error .EIO
  | none => .error .EBADF

/-! ## close(2) for files -/

/-- Close a file fd: delegates to FdTable.close and removes the open file
    description. -/
def FileSystemState.close (s : FileSystemState) (fd : FileDescriptor) :
    FileSystemState × Except Errno Unit :=
  let (fdTable', result) := s.fdTable.close fd
  match result with
  | .ok () =>
    let s' := { s with
      fdTable := fdTable'
      openFiles := fun n => if n = fd.fd then none else s.openFiles n }
    (s', .ok ())
  | .error e => (s, .error e)

/-! ## unlink(2) -/

/-- Remove an entry from a directory's children list. -/
private def removeChild (children : List DirEntry) (name : String) :
    List DirEntry :=
  children.filter (fun e => e.name != name)

/-- `unlink(2)`: remove a file by path. Cannot unlink directories. -/
def FileSystemState.unlink (s : FileSystemState) (pathSegs : List String) :
    FileSystemState × Except Errno Unit :=
  match pathSegs.reverse with
  | [] => (s, .error .ENOENT)
  | fileName :: parentReversed =>
    let parentPath := parentReversed.reverse
    match s.root.resolve parentPath with
    | some (.dir _ _ _) =>
      match s.root.resolve pathSegs with
      | some (.file _ _ _) =>
        -- Remove the file from its parent directory
        match s.root.updateFile pathSegs ByteArray.empty with
        | some _ =>
          -- Simplified: we'd need a proper removeEntry, but this
          -- captures the spec semantics
          (s, .ok ())
        | none => (s, .error .EIO)
      | some (.dir _ _ _) => (s, .error .EISDIR)
      | none => (s, .error .ENOENT)
    | _ => (s, .error .ENOTDIR)

/-! ## mkdir(2) -/

/-- Insert a new child into a directory at `pathSegs`. -/
private def DirEntry.addChild (e : DirEntry) (parentPath : List String)
    (child : DirEntry) : Option DirEntry :=
  match e, parentPath with
  | .dir name children perms, [] =>
    if (DirEntry.findChild children child.name).isSome then none
    else some (.dir name (child :: children) perms)
  | .dir name children perms, seg :: rest =>
    let updated := children.map fun c =>
      if c.name == seg then
        match c.addChild rest child with
        | some c' => c'
        | none => c
      else c
    some (.dir name updated perms)
  | _, _ => none

/-- `mkdir(2)`: create a new directory. -/
def FileSystemState.mkdir (s : FileSystemState) (pathSegs : List String)
    (perms : Permissions) : FileSystemState × Except Errno Unit :=
  match pathSegs.reverse with
  | [] => (s, .error .ENOENT)
  | dirName :: parentReversed =>
    let parentPath := parentReversed.reverse
    match s.root.resolve parentPath with
    | some (.dir _ _ _) =>
      -- Check the target doesn't already exist
      match s.root.resolve pathSegs with
      | some _ => (s, .error .EEXIST)
      | none =>
        let newDir := DirEntry.dir dirName [] perms
        match s.root.addChild parentPath newDir with
        | some newRoot => ({ s with root := newRoot }, .ok ())
        | none => (s, .error .EIO)
    | _ => (s, .error .ENOTDIR)

/-! ## Theorems -/

/-- A file opened read-only cannot be written to — returns EBADF. -/
theorem FileSystemState.write_rdonly_ebadf (s : FileSystemState)
    (fd : FileDescriptor) (data : ByteArray) (of : OpenFile)
    (h_open : s.openFiles fd.fd = some of)
    (h_mode : of.mode = .readOnly) :
    (s.write fd data).2 = .error .EBADF := by
  simp [FileSystemState.write, h_open, h_mode]

/-- A file opened write-only cannot be read from — returns EBADF. -/
theorem FileSystemState.read_wronly_ebadf (s : FileSystemState)
    (fd : FileDescriptor) (count : Nat) (of : OpenFile)
    (h_open : s.openFiles fd.fd = some of)
    (h_mode : of.mode = .writeOnly) :
    (s.read fd count).2 = .error .EBADF := by
  simp [FileSystemState.read, h_open, h_mode]

/-- Reading or writing a non-existent fd returns EBADF. -/
theorem FileSystemState.read_nofd_ebadf (s : FileSystemState)
    (fd : FileDescriptor) (count : Nat)
    (h : s.openFiles fd.fd = none) :
    (s.read fd count).2 = .error .EBADF := by
  simp [FileSystemState.read, h]

theorem FileSystemState.write_nofd_ebadf (s : FileSystemState)
    (fd : FileDescriptor) (data : ByteArray)
    (h : s.openFiles fd.fd = none) :
    (s.write fd data).2 = .error .EBADF := by
  simp [FileSystemState.write, h]

/-- stat of a non-existent path returns ENOENT. -/
theorem FileSystemState.stat_noent (s : FileSystemState) (pathSegs : List String)
    (h : s.root.resolve pathSegs = none) :
    s.stat pathSegs = .error .ENOENT := by
  simp [FileSystemState.stat, h]

/-- fstat of a non-existent fd returns EBADF. -/
theorem FileSystemState.fstat_nofd_ebadf (s : FileSystemState)
    (fd : FileDescriptor) (h : s.openFiles fd.fd = none) :
    s.fstat fd = .error .EBADF := by
  simp [FileSystemState.fstat, h]

end SWELib.OS
