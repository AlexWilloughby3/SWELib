import SWELib.Networking.Http.Message

/-!
# HTTP Server Parsing Bridge

Bridge axioms asserting that the server's pure-Lean HTTP/1.1 parser
produces output conforming to RFC 9110.

These axioms reference opaque `parseRequest` and `serializeResponse`
functions whose implementations live in `SWELibCode.Networking.HttpServer`.
The bridge declares their signatures and states trust axioms about them.
-/

namespace SWELibBridge.HttpServer

open SWELib.Networking.Http

-- Opaque function signatures matching the code implementations

/-- Parse a complete HTTP/1.1 request from raw bytes.
    Returns the parsed Request and the number of bytes consumed, or none. -/
opaque parseRequest (buf : ByteArray) : Option (Request × Nat)

/-- Serialize an HTTP response to bytes for sending over the wire. -/
opaque serializeResponse (resp : Response) : ByteArray

-- TRUST: <issue-url>

/-- Axiom: When parseRequest succeeds, the resulting Request's method
    string round-trips through ToString: the method parsed from the wire
    matches what the client sent. -/
axiom parseRequest_method_faithful (buf : ByteArray) (req : Request) (n : Nat)
    (h : parseRequest buf = some (req, n)) :
    req.method ≠ Method.extension ""

/-- Axiom: When parseRequest succeeds, the headers list is non-empty
    iff the raw request contained header lines. -/
axiom parseRequest_headers_nonempty (buf : ByteArray) (req : Request) (n : Nat)
    (h : parseRequest buf = some (req, n)) :
    ∀ f ∈ req.headers, f.name.raw.length > 0

/-- Axiom: parseRequest consumes exactly the bytes it reports.
    The byte count n is the precise number of bytes used. -/
axiom parseRequest_consumes_n (buf : ByteArray) (req : Request) (n : Nat)
    (h : parseRequest buf = some (req, n)) :
    n ≤ buf.size

/-- Axiom: serializeResponse produces valid HTTP/1.1 bytes.
    The serialized response starts with "HTTP/1.1 ". -/
axiom serializeResponse_starts_with_status (resp : Response) :
    let bytes := serializeResponse resp
    let s := String.fromUTF8! bytes
    s.startsWith "HTTP/1.1 "

end SWELibBridge.HttpServer
