import SWELib
import SWELibImpl.Bridge
import SWELibImpl.Ffi.Syscalls
import SWELibImpl.Ffi.Libssl
import SWELibImpl.Networking.TcpServer
import SWELibImpl.Networking.HttpServer

/-!
# HTTPS Server

Accept loop with per-connection TLS handshake + the existing HTTP/1.1 parser.
Uses OpenSSL server-side (TLS_server_method, SSL_accept) over TCP sockets.

The architecture:
1. TCP accept → raw socket fd
2. SSL_new + SSL_set_fd + SSL_accept → TLS-wrapped fd
3. SSL_read/SSL_write → encrypted HTTP/1.1 parsing/serialization
4. SSL_shutdown + close → clean teardown
-/

namespace SWELibImpl.Networking.HttpsServer

open SWELib.Networking.Http
open SWELibImpl.Ffi.Libssl
open SWELibImpl.Ffi.Syscalls
open SWELibImpl.Networking.TcpServer
open SWELibImpl.Networking.HttpServer

/-- TLS configuration for the HTTPS server. -/
structure TlsConfig where
  /-- Path to PEM-encoded certificate file. -/
  certFile : String
  /-- Path to PEM-encoded private key file. -/
  keyFile  : String

/-- An HTTPS server wrapping a TCP listener with a TLS context. -/
structure HttpsServer where
  listener : TcpListener
  ctx      : SslCtx

/-- A TLS-wrapped client connection.
    Reads/writes go through OpenSSL's SSL_read/SSL_write. -/
structure TlsConn where
  fd   : UInt32
  conn : SslConn

/-- Create and start an HTTPS server on host:port with the given TLS config. -/
def serve (config : TlsConfig) (host : String := "0.0.0.0") (port : UInt16) :
    IO HttpsServer := do
  let ctx ← sslServerCtxNew config.certFile config.keyFile
  let listener ← TcpServer.listen host port
  return ⟨listener, ctx⟩

/-- Perform TLS handshake on an accepted TCP connection.
    Returns a TlsConn on success. -/
private def tlsAccept (ctx : SslCtx) (accepted : AcceptedConn) : IO TlsConn := do
  let sslConn ← sslNew ctx accepted.fd
  let result ← sslAccept sslConn
  if result != 1 then
    accepted.close
    throw <| IO.userError "TLS handshake failed on accepted connection"
  return ⟨accepted.fd, sslConn⟩

/-- Read data from a TLS connection. -/
private def tlsRecv (conn : TlsConn) (maxBytes : USize := 65536) : IO ByteArray :=
  sslRead conn.conn maxBytes

/-- Write data to a TLS connection. Returns bytes written. -/
private def tlsSend (conn : TlsConn) (data : ByteArray) : IO USize :=
  sslWrite conn.conn data

/-- Send all data over TLS. -/
private def tlsSendAll (conn : TlsConn) (data : ByteArray) : IO Unit := do
  let mut offset : Nat := 0
  while offset < data.size do
    let slice := data.extract offset data.size
    let sent ← tlsSend conn slice
    offset := offset + sent.toNat

/-- Close a TLS connection (close_notify + TCP close). -/
private def tlsClose (conn : TlsConn) : IO Unit := do
  sslShutdown conn.conn
  let _ ← closeSocket conn.fd

/-- Handle a single HTTPS client connection.
    Reads encrypted HTTP request, calls handler, sends encrypted response. -/
private def handleClient (ctx : SslCtx) (accepted : AcceptedConn)
    (handler : Handler) : IO Unit := do
  -- TLS handshake
  let conn ← tlsAccept ctx accepted
  -- Read request data (up to 64KB)
  let mut buf := ByteArray.empty
  let mut done := false
  while !done && buf.size < 65536 do
    let chunk ← tlsRecv conn 8192
    if chunk.isEmpty then
      done := true
    else
      buf := buf ++ chunk
      match HttpServer.findHeaderEnd buf with
      | some headerEnd =>
        let headerStr := String.fromUTF8! (buf.extract 0 headerEnd)
        let lines := headerStr.splitOn "\r\n"
        let headerLines := (lines.drop 1).filter (!·.isEmpty)
        let headers := headerLines.filterMap HttpServer.parseHeaderLine
        let contentLength := Headers.getContentLength headers
        let needed := headerEnd + contentLength.getD 0
        if buf.size ≥ needed then done := true
      | none => pure ()
  -- Parse and handle
  match HttpServer.parseRequest buf with
  | some (req, _) =>
    match SWELibImpl.Validators.validateRequest req with
    | .error msg =>
      let errResp : Response := {
        status := StatusCode.badRequest
        headers := [{ name := FieldName.contentType, value := "text/plain" }]
        body := some msg.toUTF8
      }
      tlsSendAll conn (HttpServer.serializeResponse errResp)
    | .ok _ =>
      let resp ← handler req
      match SWELibImpl.Validators.validateResponse req resp with
      | .error msg => let _ ← IO.eprintln s!"[HTTPS] Response contract violation: {msg}"
      | .ok _ => pure ()
      tlsSendAll conn (HttpServer.serializeResponse resp)
  | none =>
    let resp : Response := {
      status := StatusCode.badRequest
      headers := [{ name := FieldName.contentType, value := "text/plain" }]
      body := some "Bad Request".toUTF8
    }
    tlsSendAll conn (HttpServer.serializeResponse resp)
  tlsClose conn

/-- Run the HTTPS accept loop, handling one connection at a time.
    Each connection gets a fresh TLS handshake before HTTP processing. -/
def HttpsServer.acceptLoop (server : HttpsServer) (handler : Handler) : IO Unit := do
  while true do
    let accepted ← server.listener.accept
    try
      handleClient server.ctx accepted handler
    catch e =>
      let _ ← IO.eprintln s!"[HTTPS] Error handling request: {e}"
      try
        let _ ← closeSocket accepted.fd
      catch _ => pure ()

/-- Close the HTTPS server. -/
def HttpsServer.close (server : HttpsServer) : IO Unit :=
  server.listener.close

end SWELibImpl.Networking.HttpsServer
