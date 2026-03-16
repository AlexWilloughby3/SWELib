/-!
# File Descriptors

The atom everything else in the OS module is built on.
Every file, socket, pipe, and epoll instance is a file descriptor.

References:
- close(2): https://man7.org/linux/man-pages/man2/close.2.html
- dup(2):   https://man7.org/linux/man-pages/man2/dup.2.html
- fcntl(2): https://man7.org/linux/man-pages/man2/fcntl.2.html
-/

namespace SWELib.OS

/-! ## Error model -/

/-- POSIX error codes relevant to file descriptor operations. -/
inductive Errno where
  /-- Bad file descriptor: fd is not valid or not open. -/
  | EBADF
  /-- Interrupted system call. -/
  | EINTR
  /-- I/O error. -/
  | EIO
  /-- Permission denied. -/
  | EACCES
  /-- No such file or directory. -/
  | ENOENT
  /-- File exists. -/
  | EEXIST
  /-- Is a directory. -/
  | EISDIR
  /-- Not a directory. -/
  | ENOTDIR
  /-- Invalid argument. -/
  | EINVAL
  /-- Too many open files. -/
  | EMFILE
  /-- Read-only file system. -/
  | EROFS
  /-- No space left on device. -/
  | ENOSPC
  /-- No such process. -/
  | ESRCH
  /-- No child processes. -/
  | ECHILD
  /-- Operation not permitted. -/
  | EPERM
  /-- Broken pipe. -/
  | EPIPE
  /-- Connection refused. -/
  | ECONNREFUSED
  /-- Address already in use. -/
  | EADDRINUSE
  /-- Transport endpoint is not connected. -/
  | ENOTCONN
  /-- Transport endpoint is already connected. -/
  | EISCONN
  /-- Connection reset by peer. -/
  | ECONNRESET
  /-- Connection aborted. -/
  | ECONNABORTED
  /-- Network is unreachable. -/
  | ENETUNREACH
  /-- Address family not supported. -/
  | EAFNOSUPPORT
  /-- Protocol wrong type for socket. -/
  | EPROTOTYPE
  /-- Resource temporarily unavailable. -/
  | EAGAIN
  /-- Operation already in progress. -/
  | EALREADY
  /-- Cannot allocate memory. -/
  | ENOMEM
  /-- Too many open files in system. -/
  | ENFILE
  /-- No such device. -/
  | ENODEV
  /-- Value too large for defined data type. -/
  | EOVERFLOW
  /-- Text file busy. -/
  | ETXTBSY
  deriving DecidableEq, Repr

/-! ## File descriptor types -/

/-- What kind of resource a file descriptor points to. -/
inductive FdKind where
  | file
  | socket
  | pipe
  | epoll
  deriving DecidableEq, Repr

/-- State of a single file descriptor entry. -/
inductive FdState where
  /-- The fd is open and points to a resource of the given kind. -/
  | open (kind : FdKind)
  /-- The fd has been closed. -/
  | closed
  deriving DecidableEq, Repr

/-- A file descriptor: an opaque index into the per-process fd table.
    Wraps a `Nat` matching the POSIX convention (non-negative integer). -/
structure FileDescriptor where
  fd : Nat
  deriving DecidableEq, Repr

instance : ToString FileDescriptor where
  toString d := s!"fd({d.fd})"

/-! ## The fd table -/

/-- The per-process file descriptor table: a partial map from fd numbers
    to their current state. `none` means the slot has never been used. -/
def FdTable := Nat → Option FdState

/-- The empty fd table (no fds allocated). -/
def FdTable.empty : FdTable := fun _ => none

/-- Look up an fd in the table. -/
def FdTable.lookup (t : FdTable) (fd : FileDescriptor) : Option FdState :=
  t fd.fd

/-- Whether an fd is currently open. -/
def FdTable.isOpen (t : FdTable) (fd : FileDescriptor) : Bool :=
  match t fd.fd with
  | some (.open _) => true
  | _ => false

/-- Update a single entry in the fd table. -/
def FdTable.update (t : FdTable) (n : Nat) (s : FdState) : FdTable :=
  fun i => if i = n then some s else t i

/-! ## close(2) -/

/-- `close(2)`: release a file descriptor.
    - If the fd is open, transitions it to closed and returns `ok`.
    - If the fd is already closed or was never opened, returns `EBADF`. -/
def FdTable.close (t : FdTable) (fd : FileDescriptor) :
    FdTable × Except Errno Unit :=
  match t fd.fd with
  | some (.open _) => (t.update fd.fd .closed, .ok ())
  | some .closed   => (t, .error .EBADF)
  | none           => (t, .error .EBADF)

/-! ## dup(2) / dup2(2) -/

/-- `dup(2)`: duplicate a file descriptor to a specific new slot.
    - If the source fd is open, creates a new open fd of the same kind.
    - If the source fd is not open, returns `EBADF`. -/
def FdTable.dup (t : FdTable) (src : FileDescriptor) (newFd : Nat) :
    FdTable × Except Errno FileDescriptor :=
  match t src.fd with
  | some (.open k) =>
    (t.update newFd (.open k), .ok ⟨newFd⟩)
  | _ => (t, .error .EBADF)

/-! ## Theorems -/

/-- A closed fd cannot be closed again — returns EBADF.
    Key invariant: double-close is an error, not undefined behavior. -/
theorem FdTable.close_closed_ebadf (t : FdTable) (fd : FileDescriptor)
    (h : t fd.fd = some .closed) :
    (FdTable.close t fd).2 = .error .EBADF := by
  simp [FdTable.close, h]

/-- An fd that was never opened cannot be closed — returns EBADF. -/
theorem FdTable.close_none_ebadf (t : FdTable) (fd : FileDescriptor)
    (h : t fd.fd = none) :
    (FdTable.close t fd).2 = .error .EBADF := by
  simp [FdTable.close, h]

/-- After a successful close, the fd is no longer open. -/
theorem FdTable.close_makes_not_open (t : FdTable) (fd : FileDescriptor)
    (k : FdKind) (h : t fd.fd = some (.open k)) :
    (FdTable.close t fd).1.isOpen fd = false := by
  simp [FdTable.close, h, FdTable.isOpen, FdTable.update]

/-- Closing an fd does not affect other fds. -/
theorem FdTable.close_preserves_other (t : FdTable) (fd other : FileDescriptor)
    (hne : fd.fd ≠ other.fd) :
    (FdTable.close t fd).1 other.fd = t other.fd := by
  simp [FdTable.close]
  split <;> simp [FdTable.update, Ne.symm hne]

/-- A dup'd fd is open with the same kind as the source. -/
theorem FdTable.dup_is_open (t : FdTable) (src : FileDescriptor) (n : Nat)
    (k : FdKind) (h : t src.fd = some (.open k)) :
    (FdTable.dup t src n).1 n = some (.open k) := by
  simp [FdTable.dup, h, FdTable.update]

/-- Dup does not affect fds other than the target. -/
theorem FdTable.dup_preserves_other (t : FdTable) (src : FileDescriptor)
    (newFd : Nat) (other : Nat) (hne : other ≠ newFd) :
    (FdTable.dup t src newFd).1 other = t other := by
  simp [FdTable.dup]
  split <;> simp [FdTable.update, hne]

end SWELib.OS
