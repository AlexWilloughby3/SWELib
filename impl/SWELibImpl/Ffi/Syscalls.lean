import SWELib
import SWELibImpl.Bridge

/-!
# Syscalls FFI

Raw `@[extern]` declarations for Linux syscalls.
These bind to C shim functions that wrap the actual syscalls.
-/

namespace SWELibImpl.Ffi.Syscalls

open SWELib.OS

/-! ## File descriptor operations -/

/-- Raw close(2) via C shim. -/
@[extern "swelib_close"]
opaque close (fd : UInt32) : IO (Except Errno Unit)

/-- Raw dup2(2) via C shim. -/
@[extern "swelib_dup2"]
opaque dup2 (oldfd newfd : UInt32) : IO (Except Errno UInt32)

/-! ## File I/O operations -/

/-- Raw open(2) via C shim.
    `flags` is the bitwise OR of O_RDONLY/O_WRONLY/etc.
    `mode` is the permission bits for O_CREAT. -/
@[extern "swelib_open"]
opaque open_ (path : @& String) (flags : UInt32) (mode : UInt32) :
    IO (Except Errno UInt32)

/-- Raw read(2) via C shim. -/
@[extern "swelib_read"]
opaque read (fd : UInt32) (count : USize) : IO (Except Errno ByteArray)

/-- Raw write(2) via C shim. -/
@[extern "swelib_write"]
opaque write (fd : UInt32) (data : @& ByteArray) : IO (Except Errno USize)

/-- Raw lseek(2) via C shim. -/
@[extern "swelib_lseek"]
opaque lseek (fd : UInt32) (offset : Int64) (whence : UInt32) :
    IO (Except Errno UInt64)

/-- Raw stat(2) via C shim. Returns (fileType, size, mode, uid, gid). -/
@[extern "swelib_stat"]
opaque stat (path : @& String) :
    IO (Except Errno (UInt32 × UInt64 × UInt32 × UInt32 × UInt32))

/-- Raw fstat(2) via C shim. -/
@[extern "swelib_fstat"]
opaque fstat (fd : UInt32) :
    IO (Except Errno (UInt32 × UInt64 × UInt32 × UInt32 × UInt32))

/-- Raw unlink(2) via C shim. -/
@[extern "swelib_unlink"]
opaque unlink (path : @& String) : IO (Except Errno Unit)

/-- Raw mkdir(2) via C shim. -/
@[extern "swelib_mkdir"]
opaque mkdir (path : @& String) (mode : UInt32) : IO (Except Errno Unit)

/-! ## Process operations -/

/-- Raw fork(2) via C shim. Returns child PID in parent, 0 in child. -/
@[extern "swelib_fork"]
opaque fork : IO (Except Errno Int32)

/-- Raw _exit(2) via C shim. -/
@[extern "swelib_exit"]
opaque exit_ (code : UInt8) : IO Unit

/-- Raw waitpid(2) via C shim. Returns (pid, status). -/
@[extern "swelib_waitpid"]
opaque waitpid (pid : Int32) (options : UInt32) : IO (Except Errno (Int32 × UInt32))

/-- Raw kill(2) via C shim. -/
@[extern "swelib_kill"]
opaque kill (pid : Int32) (sig : UInt32) : IO (Except Errno Unit)

/-- Raw getpid(2) via C shim. -/
@[extern "swelib_getpid"]
opaque getpid : IO Int32

/-- Raw getppid(2) via C shim. -/
@[extern "swelib_getppid"]
opaque getppid : IO Int32

/-! ## Environment operations -/

/-- Raw getenv(3) via C shim. -/
@[extern "swelib_getenv"]
opaque getenv (name : @& String) : IO (Option String)

/-- Raw setenv(3) via C shim. -/
@[extern "swelib_setenv"]
opaque setenv (name : @& String) (value : @& String) (overwrite : UInt32) :
    IO (Except Errno Unit)

/-- Raw unsetenv(3) via C shim. -/
@[extern "swelib_unsetenv"]
opaque unsetenv (name : @& String) : IO (Except Errno Unit)

/-- Raw getcwd(3) via C shim. -/
@[extern "swelib_getcwd"]
opaque getcwd : IO (Except Errno String)

/-- Raw chdir(2) via C shim. -/
@[extern "swelib_chdir"]
opaque chdir (path : @& String) : IO (Except Errno Unit)

/-! ## User/group operations -/

/-- Raw getuid(2) via C shim. -/
@[extern "swelib_getuid"]
opaque getuid : IO UInt32

/-- Raw geteuid(2) via C shim. -/
@[extern "swelib_geteuid"]
opaque geteuid : IO UInt32

/-- Raw getgid(2) via C shim. -/
@[extern "swelib_getgid"]
opaque getgid : IO UInt32

/-- Raw getegid(2) via C shim. -/
@[extern "swelib_getegid"]
opaque getegid : IO UInt32

/-! ## Socket operations -/

/-- Raw socket(2) via C shim.
    `domain`: AF_INET=2, AF_INET6=10/30
    `type_`: SOCK_STREAM=1, SOCK_DGRAM=2
    `protocol`: 0 for default -/
@[extern "swelib_socket"]
opaque socket (domain : UInt32) (type_ : UInt32) (protocol : UInt32) :
    IO (Except Errno UInt32)

/-- Raw connect(2) via C shim. Connects fd to host:port. -/
@[extern "swelib_connect"]
opaque connect_ (fd : UInt32) (host : @& String) (port : UInt16) :
    IO (Except Errno Unit)

/-- Raw bind(2) via C shim. Binds fd to host:port. -/
@[extern "swelib_bind"]
opaque bind_ (fd : UInt32) (host : @& String) (port : UInt16) :
    IO (Except Errno Unit)

/-- Raw listen(2) via C shim. -/
@[extern "swelib_listen"]
opaque listen_ (fd : UInt32) (backlog : UInt32) :
    IO (Except Errno Unit)

/-- Raw accept(2) via C shim.
    Returns (clientFd, clientIp, clientPort). -/
@[extern "swelib_accept"]
opaque accept_ (fd : UInt32) :
    IO (Except Errno (UInt32 × String × UInt16))

/-- Raw send(2) via C shim. Returns number of bytes sent. -/
@[extern "swelib_send"]
opaque send_ (fd : UInt32) (data : @& ByteArray) :
    IO (Except Errno USize)

/-- Raw recv(2) via C shim. Returns received bytes. -/
@[extern "swelib_recv"]
opaque recv_ (fd : UInt32) (maxBytes : USize) :
    IO (Except Errno ByteArray)

/-- Raw setsockopt(2) with int value via C shim. -/
@[extern "swelib_setsockopt_int"]
opaque setsockoptInt (fd : UInt32) (level : UInt32) (optname : UInt32)
    (value : UInt32) : IO (Except Errno Unit)

/-- Raw getaddrinfo(3) via C shim.
    Returns array of (addressFamily, ipString). -/
@[extern "swelib_getaddrinfo"]
opaque getaddrinfo (host : @& String) (service : @& String) :
    IO (Except Errno (Array (UInt32 × String)))

/-- Close a socket fd via C shim. -/
@[extern "swelib_close_socket"]
opaque closeSocket (fd : UInt32) : IO (Except Errno Unit)

/-! ## Shutdown -/

/-- Raw shutdown(2) via C shim. `how`: SHUT_RD=0, SHUT_WR=1, SHUT_RDWR=2. -/
@[extern "swelib_shutdown"]
opaque shutdown_ (fd : UInt32) (how : UInt32) : IO (Except Errno Unit)

/-! ## Datagram operations -/

/-- Raw sendto(2) via C shim. Returns bytes sent. -/
@[extern "swelib_sendto"]
opaque sendto_ (fd : UInt32) (data : @& ByteArray) (host : @& String)
    (port : UInt16) : IO (Except Errno USize)

/-- Raw recvfrom(2) via C shim. Returns (data, senderIp, senderPort). -/
@[extern "swelib_recvfrom"]
opaque recvfrom_ (fd : UInt32) (maxBytes : USize) :
    IO (Except Errno (ByteArray × String × UInt16))

/-! ## Non-blocking I/O -/

/-- Raw fcntl(2) F_SETFL via C shim. Sets fd status flags. -/
@[extern "swelib_fcntl_setfl"]
opaque fcntl_setfl (fd : UInt32) (flags : UInt32) : IO (Except Errno Unit)

/-! ## Epoll operations -/

/-- Raw epoll_create1(2) via C shim. `flags`: 0 or EPOLL_CLOEXEC. -/
@[extern "swelib_epoll_create1"]
opaque epoll_create (flags : UInt32) : IO (Except Errno UInt32)

/-- Raw epoll_ctl(2) via C shim.
    `op`: EPOLL_CTL_ADD=1, EPOLL_CTL_DEL=2, EPOLL_CTL_MOD=3.
    `events`: bitmask of EPOLLIN, EPOLLOUT, etc. -/
@[extern "swelib_epoll_ctl"]
opaque epoll_ctl (epfd : UInt32) (op : UInt32) (fd : UInt32)
    (events : UInt32) : IO (Except Errno Unit)

/-- Raw epoll_wait(2) via C shim.
    Returns array of (fd, events) pairs. -/
@[extern "swelib_epoll_wait"]
opaque epoll_wait (epfd : UInt32) (maxEvents : UInt32) (timeoutMs : Int32) :
    IO (Except Errno (Array (UInt32 × UInt32)))

/-! ## Socket constants -/

/-! ## Signal operations -/

/-- Raw sigaction(2) via C shim.
    `queryOnly=1`: read-only; ignores dispKind/mask/flags.
    `dispKind`: 0=SIG_DFL, 1=SIG_IGN, 2=stub handler.
    `mask`: sa_mask as bitmask (signal N → bit N-1).
    `flags`: sa_flags bits (SA_NOCLDSTOP=0x1, SA_RESTART=0x10000000, etc.).
    Returns (old_dispKind, old_mask, old_flags). -/
@[extern "swelib_sigaction"]
opaque sigaction_ (signum : UInt32) (queryOnly : UInt32) (dispKind : UInt32)
    (mask : UInt64) (flags : UInt32) :
    IO (Except Errno (UInt32 × UInt64 × UInt32))

/-- Raw sigprocmask(2) via C shim.
    `how`: SIG_BLOCK=0, SIG_UNBLOCK=1, SIG_SETMASK=2.
    `queryOnly=1`: pass NULL for set; just returns current mask.
    `newMask`: signal set as bitmask (signal N → bit N-1).
    Returns old blocked mask as bitmask. -/
@[extern "swelib_sigprocmask"]
opaque sigprocmask_ (how : UInt32) (queryOnly : UInt32) (newMask : UInt64) :
    IO (Except Errno UInt64)

/-- Raw sigpending(2) via C shim.
    Returns the set of pending signals as a bitmask. -/
@[extern "swelib_sigpending"]
opaque sigpending_ : IO (Except Errno UInt64)

/-! ## Socket constants -/

def AF_INET  : UInt32 := 2
def AF_INET6 : UInt32 := 10  -- Linux
def SOCK_STREAM : UInt32 := 1
def SOCK_DGRAM  : UInt32 := 2
def SOL_SOCKET  : UInt32 := 1  -- Linux
def SO_REUSEADDR : UInt32 := 2  -- Linux

end SWELibImpl.Ffi.Syscalls
