import SWELib.OS.Io
import SWELib.OS.FileSystem

/-!
# Socket Types

Core types for the POSIX sockets specification: address families, socket
types, addresses, socket options, and the socket state machine.

References:
- socket(2):     https://man7.org/linux/man-pages/man2/socket.2.html
- bind(2):       https://man7.org/linux/man-pages/man2/bind.2.html
- setsockopt(2): https://man7.org/linux/man-pages/man2/setsockopt.2.html
- shutdown(2):   https://man7.org/linux/man-pages/man2/shutdown.2.html
-/

namespace SWELib.OS

/-! ## Address family -/

/-- POSIX address families. -/
inductive AddressFamily where
  | AF_INET
  | AF_INET6
  | AF_UNIX
  deriving DecidableEq, Repr

/-! ## Socket type -/

/-- POSIX socket types. -/
inductive SocketType where
  | SOCK_STREAM
  | SOCK_DGRAM
  deriving DecidableEq, Repr

/-! ## Addresses -/

/-- IPv4 address as a 4-tuple of octets. -/
structure IPv4Addr where
  a : UInt8
  b : UInt8
  c : UInt8
  d : UInt8
  deriving DecidableEq, Repr

/-- IPv6 address as an 8-tuple of 16-bit groups. -/
structure IPv6Addr where
  g0 : UInt16
  g1 : UInt16
  g2 : UInt16
  g3 : UInt16
  g4 : UInt16
  g5 : UInt16
  g6 : UInt16
  g7 : UInt16
  deriving DecidableEq, Repr

/-- A socket address: inet4, inet6, or unix domain. -/
inductive SockAddr where
  | inet4 (addr : IPv4Addr) (port : UInt16)
  | inet6 (addr : IPv6Addr) (port : UInt16)
  | unix (path : String)
  deriving DecidableEq, Repr

/-- Extract the address family from a SockAddr. -/
def SockAddr.family : SockAddr → AddressFamily
  | .inet4 .. => .AF_INET
  | .inet6 .. => .AF_INET6
  | .unix ..  => .AF_UNIX

/-! ## Socket options -/

/-- Common socket options for setsockopt/getsockopt. -/
inductive SocketOption where
  | SO_REUSEADDR
  | SO_REUSEPORT
  | SO_KEEPALIVE
  deriving DecidableEq, Repr

/-! ## Shutdown direction -/

/-- The `how` argument to shutdown(2). -/
inductive ShutdownHow where
  | SHUT_RD
  | SHUT_WR
  | SHUT_RDWR
  deriving DecidableEq, Repr

/-! ## Socket state machine -/

/-- The phase of a socket's lifecycle.
    Transitions: unbound → bound → listening → connected → shutdown.
    `connected` is also reachable directly from `unbound`/`bound` via connect(). -/
inductive SocketPhase where
  | unbound
  | bound
  | listening
  | connected
  | shutdown
  deriving DecidableEq, Repr

/-! ## Socket entry -/

/-- A single socket's state in the system. -/
structure SocketEntry where
  /-- Address family this socket was created with. -/
  family : AddressFamily
  /-- Socket type (stream or datagram). -/
  sockType : SocketType
  /-- Current lifecycle phase. -/
  phase : SocketPhase
  /-- Enabled socket options. -/
  options : List SocketOption
  /-- Receive buffer: FIFO list of received data chunks. -/
  recvBuf : List ByteArray
  /-- Send buffer capacity in bytes. -/
  sendBufCapacity : Nat
  /-- Send buffer currently used bytes. -/
  sendBufUsed : Nat
  /-- Local address, if bound. -/
  localAddr : Option SockAddr
  /-- Remote address, if connected. -/
  remoteAddr : Option SockAddr
  deriving Repr

/-- Create a fresh unbound socket entry. -/
def SocketEntry.fresh (family : AddressFamily) (sockType : SocketType) : SocketEntry :=
  { family
    sockType
    phase := .unbound
    options := []
    recvBuf := []
    sendBufCapacity := 65536
    sendBufUsed := 0
    localAddr := none
    remoteAddr := none }

end SWELib.OS
