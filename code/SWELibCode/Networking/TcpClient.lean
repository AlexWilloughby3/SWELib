import SWELib
import SWELibBridge
import SWELibCode.Ffi.Syscalls
import SWELibCode.Networking.DnsResolver

/-!
# TCP Client

A TCP stream wrapping a raw socket fd.
Provides connect/send/recv/close operations.
-/

namespace SWELibCode.Networking.TcpClient

open SWELib.OS
open SWELibCode.Ffi.Syscalls
open SWELibCode.Networking.DnsResolver

/-- A connected TCP stream. Wraps a socket file descriptor. -/
structure TcpStream where
  fd   : UInt32
  host : String
  port : UInt16

/-- Connect to a remote host:port via TCP.
    Resolves the hostname first, then connects. -/
def connect (host : String) (port : UInt16) : IO TcpStream := do
  -- Resolve hostname to IP
  let ip ← resolveFirst host
  -- Create socket
  let sockResult ← socket AF_INET SOCK_STREAM 0
  let fd ← match sockResult with
    | .ok fd => pure fd
    | .error e => throw <| IO.userError s!"socket() failed: {repr e}"
  -- Connect
  let connResult ← connect_ fd ip port
  match connResult with
  | .ok () => return ⟨fd, host, port⟩
  | .error e =>
    let _ ← closeSocket fd
    throw <| IO.userError s!"connect() to {host}:{port} failed: {repr e}"

/-- Send data over the TCP stream. Returns number of bytes sent. -/
def TcpStream.send (stream : TcpStream) (data : ByteArray) : IO USize := do
  let result ← send_ stream.fd data
  match result with
  | .ok n => return n
  | .error e => throw <| IO.userError s!"send() failed: {repr e}"

/-- Send all data, retrying until everything is sent. -/
def TcpStream.sendAll (stream : TcpStream) (data : ByteArray) : IO Unit := do
  let mut offset : Nat := 0
  while offset < data.size do
    let slice := data.extract offset data.size
    let sent ← stream.send slice
    offset := offset + sent.toNat

/-- Receive up to `maxBytes` from the TCP stream.
    Returns empty ByteArray on EOF. -/
def TcpStream.recv (stream : TcpStream) (maxBytes : USize := 65536) :
    IO ByteArray := do
  let result ← recv_ stream.fd maxBytes
  match result with
  | .ok data => return data
  | .error e => throw <| IO.userError s!"recv() failed: {repr e}"

/-- Close the TCP stream. -/
def TcpStream.close (stream : TcpStream) : IO Unit := do
  let result ← closeSocket stream.fd
  match result with
  | .ok () => return ()
  | .error e => throw <| IO.userError s!"close() failed: {repr e}"

end SWELibCode.Networking.TcpClient
