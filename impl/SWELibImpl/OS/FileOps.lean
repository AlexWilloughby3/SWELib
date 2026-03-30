import SWELib
import SWELibImpl.Bridge
import SWELibImpl.Ffi.Syscalls

/-!
# FileOps

Executable file operations that wrap the raw FFI syscalls with
spec-level types from `SWELib.OS`.
-/

namespace SWELibImpl.OS.FileOps

open SWELib.OS

/-! ## Flag encoding -/

/-- Encode `AccessMode` as the Linux O_ flag value. -/
def accessModeToFlags : AccessMode → UInt32
  | .readOnly  => 0   -- O_RDONLY
  | .writeOnly => 1   -- O_WRONLY
  | .readWrite => 2   -- O_RDWR

/-- Encode `OpenFlags` as additional Linux O_ bits. -/
def openFlagsBits (f : OpenFlags) : UInt32 :=
  let c := if f.create   then 0x40  else 0  -- O_CREAT
  let t := if f.truncate  then 0x200 else 0  -- O_TRUNC
  let a := if f.append    then 0x400 else 0  -- O_APPEND
  c ||| t ||| a

/-- Encode `Permissions` as a POSIX mode_t value. -/
def permissionsToMode (p : Permissions) : UInt32 :=
  let o := (if p.owner.read then 0x100 else 0) |||
           (if p.owner.write then 0x80 else 0) |||
           (if p.owner.exec then 0x40 else 0)
  let g := (if p.group.read then 0x20 else 0) |||
           (if p.group.write then 0x10 else 0) |||
           (if p.group.exec then 0x8 else 0)
  let r := (if p.other.read then 0x4 else 0) |||
           (if p.other.write then 0x2 else 0) |||
           (if p.other.exec then 0x1 else 0)
  o ||| g ||| r

/-- Encode `Whence` as the Linux SEEK_ constant. -/
def whenceToUInt32 : Whence → UInt32
  | .set  => 0  -- SEEK_SET
  | .cur  => 1  -- SEEK_CUR
  | .end_ => 2  -- SEEK_END

/-! ## Wrapped operations -/

/-- Open a file, returning a `FileDescriptor`. -/
def openFile (path : String) (mode : AccessMode) (flags : OpenFlags)
    (perms : Permissions := Permissions.defaultFile) :
    IO (Except Errno FileDescriptor) := do
  let bits := accessModeToFlags mode ||| openFlagsBits flags
  let result ← SWELibImpl.Ffi.Syscalls.open_ path bits (permissionsToMode perms)
  return result.map (fun fd => ⟨fd.toNat⟩)

/-- Read up to `count` bytes from an open fd. -/
def read (fd : FileDescriptor) (count : Nat) :
    IO (Except Errno ByteArray) :=
  SWELibImpl.Ffi.Syscalls.read fd.fd.toUInt32 count.toUSize

/-- Write bytes to an open fd. Returns number of bytes written. -/
def write (fd : FileDescriptor) (data : ByteArray) :
    IO (Except Errno Nat) := do
  let result ← SWELibImpl.Ffi.Syscalls.write fd.fd.toUInt32 data
  return result.map (fun n => n.toNat)

/-- Close a file descriptor. -/
def close (fd : FileDescriptor) : IO (Except Errno Unit) :=
  SWELibImpl.Ffi.Syscalls.close fd.fd.toUInt32

/-- Reposition the file offset. -/
def lseek (fd : FileDescriptor) (offset : Int) (whence : Whence) :
    IO (Except Errno Nat) := do
  let result ← SWELibImpl.Ffi.Syscalls.lseek fd.fd.toUInt32 offset.toInt64 (whenceToUInt32 whence)
  return result.map (fun n => n.toNat)

/-- Get file metadata by path. -/
def stat (path : String) : IO (Except Errno FileStat) := do
  let result ← SWELibImpl.Ffi.Syscalls.stat path
  return result.map fun (ftype, size, mode, uid, gid) =>
    { fileType := match ftype with
        | 1 => .regular | 2 => .directory | 3 => .symlink
        | 4 => .blockDevice | 5 => .charDevice | 6 => .fifo
        | 7 => .socket | _ => .regular
      size := size.toNat
      permissions := decodeMode mode
      uid := uid.toNat
      gid := gid.toNat }
where
  decodeMode (m : UInt32) : Permissions :=
    { owner := ⟨m &&& 0x100 != 0, m &&& 0x80 != 0, m &&& 0x40 != 0⟩
      group := ⟨m &&& 0x20 != 0,  m &&& 0x10 != 0, m &&& 0x8 != 0⟩
      other := ⟨m &&& 0x4 != 0,   m &&& 0x2 != 0,  m &&& 0x1 != 0⟩ }

/-- Get file metadata by open fd. -/
def fstat (fd : FileDescriptor) : IO (Except Errno FileStat) := do
  let result ← SWELibImpl.Ffi.Syscalls.fstat fd.fd.toUInt32
  return result.map fun (ftype, size, mode, uid, gid) =>
    { fileType := match ftype with
        | 1 => .regular | 2 => .directory | 3 => .symlink
        | 4 => .blockDevice | 5 => .charDevice | 6 => .fifo
        | 7 => .socket | _ => .regular
      size := size.toNat
      permissions := decodeMode mode
      uid := uid.toNat
      gid := gid.toNat }
where
  decodeMode (m : UInt32) : Permissions :=
    { owner := ⟨m &&& 0x100 != 0, m &&& 0x80 != 0, m &&& 0x40 != 0⟩
      group := ⟨m &&& 0x20 != 0,  m &&& 0x10 != 0, m &&& 0x8 != 0⟩
      other := ⟨m &&& 0x4 != 0,   m &&& 0x2 != 0,  m &&& 0x1 != 0⟩ }

/-- Remove a file by path. -/
def unlink (path : String) : IO (Except Errno Unit) :=
  SWELibImpl.Ffi.Syscalls.unlink path

/-- Create a directory. -/
def mkdir (path : String) (perms : Permissions := Permissions.defaultDir) :
    IO (Except Errno Unit) :=
  SWELibImpl.Ffi.Syscalls.mkdir path (permissionsToMode perms)

/-- Duplicate a file descriptor. -/
def dup2 (oldFd newFd : FileDescriptor) : IO (Except Errno FileDescriptor) := do
  let result ← SWELibImpl.Ffi.Syscalls.dup2 oldFd.fd.toUInt32 newFd.fd.toUInt32
  return result.map (fun fd => ⟨fd.toNat⟩)

end SWELibImpl.OS.FileOps
