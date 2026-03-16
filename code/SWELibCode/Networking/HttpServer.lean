import SWELib
import SWELibBridge
import SWELibCode.Ffi.Syscalls
import SWELibCode.Networking.TcpServer
import SWELibCode.Validators.HttpContractValidator

/-!
# HTTP Server

Accept loop + pure-Lean HTTP/1.1 request parser + response serializer.
Uses the socket path (not libcurl).
-/

namespace SWELibCode.Networking.HttpServer

open SWELib.Networking.Http
open SWELib.OS
open SWELibCode.Ffi.Syscalls
open SWELibCode.Networking.TcpServer

/-! ## HTTP/1.1 Request Parsing -/

/-- Parse an HTTP method string into a spec Method. -/
private def parseMethod (s : String) : Option Method :=
  match s with
  | "GET"     => some .GET
  | "HEAD"    => some .HEAD
  | "POST"    => some .POST
  | "PUT"     => some .PUT
  | "PATCH"   => some .PATCH
  | "DELETE"  => some .DELETE
  | "CONNECT" => some .CONNECT
  | "OPTIONS" => some .OPTIONS
  | "TRACE"   => some .TRACE
  | other     => if other.isEmpty then none else some (.extension other)

/-- Parse a request target string into a spec RequestTarget.
    Only supports origin-form for now. -/
private def parseTarget (s : String) : RequestTarget :=
  if s == "*" then .asteriskForm
  else
    match s.splitOn "?" with
    | [path] => .originForm path none
    | [path, query] => .originForm path (some query)
    | _ => .originForm s none

/-- Parse a single header line "Name: Value" into a Field. -/
private def parseHeaderLine (line : String) : Option Field :=
  match line.splitOn ": " with
  | name :: rest =>
    let value := (": ".intercalate rest).trimAscii.toString
    if name.isEmpty then none
    else some { name := ⟨name⟩, value }
  | _ => none

/-- Find the end of headers (double CRLF) in a byte buffer.
    Returns the index right after "\r\n\r\n", or none. -/
private def findHeaderEnd (buf : ByteArray) : Option Nat := do
  let crlfcrlf := "\r\n\r\n".toUTF8
  let mut i := 0
  while i + 3 < buf.size do
    if buf.get! i == crlfcrlf.get! 0 &&
       buf.get! (i+1) == crlfcrlf.get! 1 &&
       buf.get! (i+2) == crlfcrlf.get! 2 &&
       buf.get! (i+3) == crlfcrlf.get! 3 then
      return i + 4
    i := i + 1
  none

/-- Parse a complete HTTP/1.1 request from raw bytes.
    Returns the parsed Request and the number of bytes consumed. -/
def parseRequest (buf : ByteArray) : Option (Request × Nat) := do
  -- Find end of headers
  let headerEnd ← findHeaderEnd buf
  let headerStr := String.fromUTF8! (buf.extract 0 headerEnd)
  let lines := headerStr.splitOn "\r\n"
  -- Parse request line
  let requestLine ← lines.head?
  let parts := requestLine.splitOn " "
  guard (parts.length ≥ 2)
  let methodStr ← parts.head?
  let targetStr ← (parts.drop 1).head?
  let method ← parseMethod methodStr
  let target := parseTarget targetStr
  -- Parse headers
  let headerLines := (lines.drop 1).filter (!·.isEmpty)
  let headers := headerLines.filterMap parseHeaderLine
  -- Determine body
  let contentLength := Headers.getContentLength headers
  let bodyEnd := headerEnd + contentLength.getD 0
  let body := match contentLength with
    | some n =>
      if n > 0 && bodyEnd ≤ buf.size then
        some (buf.extract headerEnd bodyEnd)
      else if n == 0 then none
      else none
    | none => none
  return ({ method, target, headers, body : Request }, bodyEnd)

/-! ## HTTP/1.1 Response Serialization -/

/-- Reason phrase for common status codes. -/
private def reasonPhrase (code : Nat) : String :=
  match code with
  | 100 => "Continue"
  | 101 => "Switching Protocols"
  | 200 => "OK"
  | 201 => "Created"
  | 202 => "Accepted"
  | 203 => "Non-Authoritative Information"
  | 204 => "No Content"
  | 205 => "Reset Content"
  | 206 => "Partial Content"
  | 300 => "Multiple Choices"
  | 301 => "Moved Permanently"
  | 302 => "Found"
  | 303 => "See Other"
  | 304 => "Not Modified"
  | 307 => "Temporary Redirect"
  | 308 => "Permanent Redirect"
  | 400 => "Bad Request"
  | 401 => "Unauthorized"
  | 402 => "Payment Required"
  | 403 => "Forbidden"
  | 404 => "Not Found"
  | 405 => "Method Not Allowed"
  | 406 => "Not Acceptable"
  | 408 => "Request Timeout"
  | 409 => "Conflict"
  | 410 => "Gone"
  | 411 => "Length Required"
  | 412 => "Precondition Failed"
  | 413 => "Content Too Large"
  | 414 => "URI Too Long"
  | 415 => "Unsupported Media Type"
  | 416 => "Range Not Satisfiable"
  | 422 => "Unprocessable Content"
  | 429 => "Too Many Requests"
  | 500 => "Internal Server Error"
  | 501 => "Not Implemented"
  | 502 => "Bad Gateway"
  | 503 => "Service Unavailable"
  | 504 => "Gateway Timeout"
  | 505 => "HTTP Version Not Supported"
  | _ => "Unknown"

/-- Serialize an HTTP response to bytes for sending over the wire. -/
def serializeResponse (resp : Response) : ByteArray :=
  let statusLine := s!"HTTP/1.1 {resp.status.code} {reasonPhrase resp.status.code}\r\n"
  let headerLines := resp.headers.map fun f => s!"{f.name.raw}: {f.value}\r\n"
  let headerStr := statusLine ++ String.join headerLines ++ "\r\n"
  let headerBytes := headerStr.toUTF8
  match resp.body with
  | some body => headerBytes ++ body
  | none => headerBytes

/-! ## Server -/

/-- A request handler: takes a Request and returns a Response. -/
def Handler := Request → IO Response

/-- An HTTP server wrapping a TCP listener. -/
structure HttpServer where
  listener : TcpListener

/-- Create and start an HTTP server on host:port. -/
def serve (host : String := "0.0.0.0") (port : UInt16) : IO HttpServer := do
  let listener ← TcpServer.listen host port
  return ⟨listener⟩

/-- Handle a single client connection.
    Reads the request, calls the handler, sends the response. -/
private def handleClient (conn : AcceptedConn) (handler : Handler) : IO Unit := do
  -- Read request data (up to 64KB for now)
  let mut buf := ByteArray.empty
  let mut done := false
  while !done && buf.size < 65536 do
    let chunk ← conn.recv 8192
    if chunk.isEmpty then
      done := true
    else
      buf := buf ++ chunk
      -- Check if we have complete headers
      match findHeaderEnd buf with
      | some headerEnd =>
        -- Check if we have the complete body
        let headerStr := String.fromUTF8! (buf.extract 0 headerEnd)
        let lines := headerStr.splitOn "\r\n"
        let headerLines := (lines.drop 1).filter (!·.isEmpty)
        let headers := headerLines.filterMap parseHeaderLine
        let contentLength := Headers.getContentLength headers
        let needed := headerEnd + contentLength.getD 0
        if buf.size ≥ needed then done := true
      | none => pure ()
  -- Parse and handle
  match parseRequest buf with
  | some (req, _) =>
    -- Validate request contract before dispatching
    match SWELibCode.Validators.validateRequest req with
    | .error msg =>
      let errResp : Response := {
        status := StatusCode.badRequest
        headers := [{ name := FieldName.contentType, value := "text/plain" }]
        body := some msg.toUTF8
      }
      conn.sendAll (serializeResponse errResp)
    | .ok _ =>
      let resp ← handler req
      -- Validate response contract before sending; log violations but still send.
      match SWELibCode.Validators.validateResponse req resp with
      | .error msg => let _ ← IO.eprintln s!"[HTTP] Response contract violation: {msg}"
      | .ok _ => pure ()
      let respBytes := serializeResponse resp
      conn.sendAll respBytes
  | none =>
    -- Send 400 Bad Request
    let resp : Response := {
      status := StatusCode.badRequest
      headers := [{ name := FieldName.contentType, value := "text/plain" }]
      body := some "Bad Request".toUTF8
    }
    conn.sendAll (serializeResponse resp)
  conn.close

/-- Run the accept loop, handling one connection at a time.
    Calls `handler` for each incoming request.
    Runs indefinitely until an error occurs. -/
def HttpServer.acceptLoop (server : HttpServer) (handler : Handler) : IO Unit := do
  while true do
    let conn ← server.listener.accept
    try
      handleClient conn handler
    catch e =>
      -- Log error but keep accepting
      let _ ← IO.eprintln s!"Error handling request: {e}"
      try conn.close catch _ => pure ()

/-- Close the HTTP server. -/
def HttpServer.close (server : HttpServer) : IO Unit :=
  server.listener.close

end SWELibCode.Networking.HttpServer
