import SWELib
import SWELibImpl.Bridge
import SWELibImpl.Ffi.Syscalls

/-!
# SocketOps

Executable wrappers translating between spec-level socket types and
FFI `UInt32` values. Thin layer over `SWELibImpl.Ffi.Syscalls`.
-/

namespace SWELibImpl.OS.SocketOps

open SWELib.OS

/-! ## Address family conversion -/

def addressFamilyToUInt32 : AddressFamily → UInt32
  | .AF_INET  => SWELibImpl.Ffi.Syscalls.AF_INET
  | .AF_INET6 => SWELibImpl.Ffi.Syscalls.AF_INET6
  | .AF_UNIX  => 1  -- AF_UNIX = 1 on both Linux and macOS

/-! ## Socket type conversion -/

def socketTypeToUInt32 : SocketType → UInt32
  | .SOCK_STREAM => SWELibImpl.Ffi.Syscalls.SOCK_STREAM
  | .SOCK_DGRAM  => SWELibImpl.Ffi.Syscalls.SOCK_DGRAM

/-! ## Shutdown direction conversion -/

def shutdownHowToUInt32 : ShutdownHow → UInt32
  | .SHUT_RD   => 0
  | .SHUT_WR   => 1
  | .SHUT_RDWR => 2

/-! ## Socket option conversion -/

def socketOptionToLevel (_opt : SocketOption) : UInt32 :=
  SWELibImpl.Ffi.Syscalls.SOL_SOCKET

def socketOptionToName : SocketOption → UInt32
  | .SO_REUSEADDR => SWELibImpl.Ffi.Syscalls.SO_REUSEADDR
  | .SO_REUSEPORT => 15  -- Linux SO_REUSEPORT
  | .SO_KEEPALIVE => 9   -- Linux SO_KEEPALIVE

/-! ## High-level operations -/

/-- Create a socket. -/
def socket (family : AddressFamily) (sockType : SocketType) :
    IO (Except Errno UInt32) :=
  SWELibImpl.Ffi.Syscalls.socket
    (addressFamilyToUInt32 family) (socketTypeToUInt32 sockType) 0

/-- Bind a socket to host:port. -/
def bind (fd : UInt32) (host : String) (port : UInt16) :
    IO (Except Errno Unit) :=
  SWELibImpl.Ffi.Syscalls.bind_ fd host port

/-- Listen on a socket. -/
def listen (fd : UInt32) (backlog : UInt32) :
    IO (Except Errno Unit) :=
  SWELibImpl.Ffi.Syscalls.listen_ fd backlog

/-- Accept a connection. Returns (clientFd, clientIp, clientPort). -/
def accept (fd : UInt32) :
    IO (Except Errno (UInt32 × String × UInt16)) :=
  SWELibImpl.Ffi.Syscalls.accept_ fd

/-- Connect to a remote address. -/
def connect (fd : UInt32) (host : String) (port : UInt16) :
    IO (Except Errno Unit) :=
  SWELibImpl.Ffi.Syscalls.connect_ fd host port

/-- Send data on a connected socket. -/
def send (fd : UInt32) (data : ByteArray) :
    IO (Except Errno USize) :=
  SWELibImpl.Ffi.Syscalls.send_ fd data

/-- Receive data from a connected socket. -/
def recv (fd : UInt32) (maxBytes : USize) :
    IO (Except Errno ByteArray) :=
  SWELibImpl.Ffi.Syscalls.recv_ fd maxBytes

/-- Shutdown a socket. -/
def shutdown (fd : UInt32) (how : ShutdownHow) :
    IO (Except Errno Unit) :=
  SWELibImpl.Ffi.Syscalls.shutdown_ fd (shutdownHowToUInt32 how)

/-- Set a socket option (int value = 1 to enable). -/
def setsockopt (fd : UInt32) (opt : SocketOption) :
    IO (Except Errno Unit) :=
  SWELibImpl.Ffi.Syscalls.setsockoptInt fd
    (socketOptionToLevel opt) (socketOptionToName opt) 1

/-- Close a socket. -/
def close (fd : UInt32) : IO (Except Errno Unit) :=
  SWELibImpl.Ffi.Syscalls.closeSocket fd

/-! ## Epoll wrappers -/

/-- Create an epoll instance. -/
def epollCreate : IO (Except Errno UInt32) :=
  SWELibImpl.Ffi.Syscalls.epoll_create 0

/-- Epoll ctl operations. -/
def epollCtlAdd (epfd fd : UInt32) (events : UInt32) :
    IO (Except Errno Unit) :=
  SWELibImpl.Ffi.Syscalls.epoll_ctl epfd 1 fd events  -- EPOLL_CTL_ADD = 1

def epollCtlMod (epfd fd : UInt32) (events : UInt32) :
    IO (Except Errno Unit) :=
  SWELibImpl.Ffi.Syscalls.epoll_ctl epfd 3 fd events  -- EPOLL_CTL_MOD = 3

def epollCtlDel (epfd fd : UInt32) :
    IO (Except Errno Unit) :=
  SWELibImpl.Ffi.Syscalls.epoll_ctl epfd 2 fd 0  -- EPOLL_CTL_DEL = 2

/-- Wait for epoll events. -/
def epollWait (epfd : UInt32) (maxEvents : UInt32) (timeoutMs : Int32) :
    IO (Except Errno (Array (UInt32 × UInt32))) :=
  SWELibImpl.Ffi.Syscalls.epoll_wait epfd maxEvents timeoutMs

end SWELibImpl.OS.SocketOps
