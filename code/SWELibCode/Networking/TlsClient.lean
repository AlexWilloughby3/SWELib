import SWELib
import SWELibBridge
import SWELibCode.Ffi.Syscalls
import SWELibCode.Ffi.Libssl
import SWELibCode.Networking.TcpClient

/-!
# TLS Client

A TLS stream wrapping OpenSSL over a TCP connection.
Provides connect/send/recv/close with encryption.
-/

namespace SWELibCode.Networking.TlsClient

open SWELibCode.Ffi.Libssl
open SWELibCode.Networking.TcpClient

/-- A connected TLS stream. Wraps an SSL connection over a TCP socket. -/
structure TlsStream where
  tcp  : TcpStream
  ctx  : SslCtx
  conn : SslConn

/-- Establish a TLS connection to host:port.
    1. Opens a TCP connection
    2. Creates SSL context and connection
    3. Sets SNI hostname
    4. Performs TLS handshake -/
def connect (host : String) (port : UInt16 := 443) : IO TlsStream := do
  -- TCP connect
  let tcp ← TcpClient.connect host port
  -- Create SSL context
  let ctx ← sslCtxNew
  -- Create SSL connection over the socket
  let conn ← sslNew ctx tcp.fd
  -- Set SNI hostname for virtual hosting
  sslSetHostname conn host
  -- Perform TLS handshake
  let result ← sslConnect conn
  if result != 1 then
    tcp.close
    throw <| IO.userError s!"TLS handshake failed for {host}:{port}"
  return ⟨tcp, ctx, conn⟩

/-- Send data over the TLS stream. Returns bytes written. -/
def TlsStream.send (stream : TlsStream) (data : ByteArray) : IO USize :=
  sslWrite stream.conn data

/-- Send all data over the TLS stream. -/
def TlsStream.sendAll (stream : TlsStream) (data : ByteArray) : IO Unit := do
  let mut offset : Nat := 0
  while offset < data.size do
    let slice := data.extract offset data.size
    let sent ← stream.send slice
    offset := offset + sent.toNat

/-- Receive up to `maxBytes` from the TLS stream.
    Returns empty ByteArray on EOF. -/
def TlsStream.recv (stream : TlsStream) (maxBytes : USize := 65536) :
    IO ByteArray :=
  sslRead stream.conn maxBytes

/-- Close the TLS stream (sends close_notify, then closes TCP). -/
def TlsStream.close (stream : TlsStream) : IO Unit := do
  sslShutdown stream.conn
  stream.tcp.close

end SWELibCode.Networking.TlsClient
