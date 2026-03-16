import SWELib
import SWELibBridge
import SWELibCode.Ffi.Syscalls

/-!
# TCP Server

A TCP listener that binds, listens, and accepts connections.
-/

namespace SWELibCode.Networking.TcpServer

open SWELib.OS
open SWELibCode.Ffi.Syscalls

/-- A bound and listening TCP server socket. -/
structure TcpListener where
  fd   : UInt32
  host : String
  port : UInt16

/-- An accepted client connection. -/
structure AcceptedConn where
  fd       : UInt32
  clientIp : String
  clientPort : UInt16

/-- Create a TCP listener bound to host:port.
    Sets SO_REUSEADDR and starts listening with the given backlog. -/
def listen (host : String := "0.0.0.0") (port : UInt16) (backlog : UInt32 := 128) :
    IO TcpListener := do
  -- Create socket
  let sockResult ← socket AF_INET SOCK_STREAM 0
  let fd ← match sockResult with
    | .ok fd => pure fd
    | .error e => throw <| IO.userError s!"socket() failed: {repr e}"
  -- Set SO_REUSEADDR
  let _ ← setsockoptInt fd SOL_SOCKET SO_REUSEADDR 1
  -- Bind
  let bindResult ← bind_ fd host port
  match bindResult with
  | .error e =>
    let _ ← closeSocket fd
    throw <| IO.userError s!"bind() to {host}:{port} failed: {repr e}"
  | .ok () => pure ()
  -- Listen
  let listenResult ← listen_ fd backlog
  match listenResult with
  | .error e =>
    let _ ← closeSocket fd
    throw <| IO.userError s!"listen() failed: {repr e}"
  | .ok () => return ⟨fd, host, port⟩

/-- Accept a single incoming connection. Blocks until a client connects. -/
def TcpListener.accept (listener : TcpListener) : IO AcceptedConn := do
  let result ← accept_ listener.fd
  match result with
  | .ok (clientFd, clientIp, clientPort) =>
    return ⟨clientFd, clientIp, clientPort⟩
  | .error e =>
    throw <| IO.userError s!"accept() failed: {repr e}"

/-- Close the listener socket. -/
def TcpListener.close (listener : TcpListener) : IO Unit := do
  let result ← closeSocket listener.fd
  match result with
  | .ok () => return ()
  | .error e => throw <| IO.userError s!"close() failed: {repr e}"

/-- Send data on an accepted connection. -/
def AcceptedConn.send (conn : AcceptedConn) (data : ByteArray) : IO USize := do
  let result ← send_ conn.fd data
  match result with
  | .ok n => return n
  | .error e => throw <| IO.userError s!"send() failed: {repr e}"

/-- Send all data on an accepted connection. -/
def AcceptedConn.sendAll (conn : AcceptedConn) (data : ByteArray) : IO Unit := do
  let mut offset : Nat := 0
  while offset < data.size do
    let slice := data.extract offset data.size
    let sent ← conn.send slice
    offset := offset + sent.toNat

/-- Receive data on an accepted connection. -/
def AcceptedConn.recv (conn : AcceptedConn) (maxBytes : USize := 65536) :
    IO ByteArray := do
  let result ← recv_ conn.fd maxBytes
  match result with
  | .ok data => return data
  | .error e => throw <| IO.userError s!"recv() failed: {repr e}"

/-- Close an accepted connection. -/
def AcceptedConn.close (conn : AcceptedConn) : IO Unit := do
  let result ← closeSocket conn.fd
  match result with
  | .ok () => return ()
  | .error e => throw <| IO.userError s!"close() failed: {repr e}"

end SWELibCode.Networking.TcpServer
