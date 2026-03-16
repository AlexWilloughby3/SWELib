import SWELib

/-!
# File Syscall Bridge Axioms

Axioms asserting that Linux file-related syscalls conform to the
specifications in `SWELib.OS.Io` and `SWELib.OS.FileSystem`.

Each axiom represents an unproven trust assumption about the kernel.
-/

namespace SWELibBridge.Syscalls.File

open SWELib.OS

/-! ## Step 0: File descriptor axioms -/

-- TRUST: <issue-url>
/-- Linux `close(2)` conforms to `FdTable.close`:
    closing an open fd succeeds, closing a non-open fd yields EBADF. -/
axiom close_conforms (t : FdTable) (fd : FileDescriptor) :
    ∀ (linuxResult : Except Errno Unit),
    linuxResult = (FdTable.close t fd).2

-- TRUST: <issue-url>
/-- Linux `dup2(2)` conforms to `FdTable.dup`:
    duplicating an open fd succeeds with the same kind. -/
axiom dup2_conforms (t : FdTable) (src : FileDescriptor) (newFd : Nat) :
    ∀ (linuxResult : Except Errno FileDescriptor),
    linuxResult = (FdTable.dup t src newFd).2

/-! ## Step 1: File I/O axioms -/

-- TRUST: <issue-url>
/-- Linux `open(2)` conforms to `FileSystemState.open`:
    permission checks and O_CREAT behavior match the spec. -/
axiom open_conforms (s : FileSystemState) (path : List String)
    (mode : AccessMode) (flags : OpenFlags) (newFd : Nat) :
    ∀ (linuxResult : Except Errno FileDescriptor),
    linuxResult = (s.open path mode flags newFd).2

-- TRUST: <issue-url>
/-- Linux `read(2)` conforms to `FileSystemState.read`:
    reads up to `count` bytes from the current offset and advances it. -/
axiom read_conforms (s : FileSystemState) (fd : FileDescriptor) (count : Nat) :
    ∀ (linuxResult : Except Errno ByteArray),
    linuxResult = (s.read fd count).2

-- TRUST: <issue-url>
/-- Linux `write(2)` conforms to `FileSystemState.write`:
    writes data at the current offset and advances it. -/
axiom write_conforms (s : FileSystemState) (fd : FileDescriptor)
    (data : ByteArray) :
    ∀ (linuxResult : Except Errno Nat),
    linuxResult = (s.write fd data).2

-- TRUST: <issue-url>
/-- Linux `lseek(2)` conforms to `FileSystemState.lseek`:
    repositions the file offset according to whence. -/
axiom lseek_conforms (s : FileSystemState) (fd : FileDescriptor)
    (offset : Int) (whence : Whence) :
    ∀ (linuxResult : Except Errno Nat),
    linuxResult = (s.lseek fd offset whence).2

-- TRUST: <issue-url>
/-- Linux `stat(2)` conforms to `FileSystemState.stat`:
    returns metadata matching the directory tree. -/
axiom stat_conforms (s : FileSystemState) (path : List String) :
    ∀ (linuxResult : Except Errno FileStat),
    linuxResult = s.stat path

-- TRUST: <issue-url>
/-- Linux `fstat(2)` conforms to `FileSystemState.fstat`:
    returns metadata for the file an fd points to. -/
axiom fstat_conforms (s : FileSystemState) (fd : FileDescriptor) :
    ∀ (linuxResult : Except Errno FileStat),
    linuxResult = s.fstat fd

-- TRUST: <issue-url>
/-- Linux `mkdir(2)` conforms to `FileSystemState.mkdir`:
    creates a new directory entry in the tree. -/
axiom mkdir_conforms (s : FileSystemState) (path : List String)
    (perms : Permissions) :
    ∀ (linuxResult : Except Errno Unit),
    linuxResult = (s.mkdir path perms).2

end SWELibBridge.Syscalls.File
