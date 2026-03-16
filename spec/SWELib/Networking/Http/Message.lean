import SWELib.Networking.Http.Method
import SWELib.Networking.Http.StatusCode
import SWELib.Networking.Http.Field
import SWELib.Networking.Http.Target

/-!
# HTTP Messages

RFC 9110 Section 6: Request and Response message structures.
Implements representation decision D-001.
-/

namespace SWELib.Networking.Http

/-- HTTP version identifier. -/
structure Version where
  major : Nat
  minor : Nat
  deriving DecidableEq, Repr

/-- HTTP/1.0 -/
def Version.http10 : Version := ⟨1, 0⟩
/-- HTTP/1.1 -/
def Version.http11 : Version := ⟨1, 1⟩
/-- HTTP/2 -/
def Version.http2 : Version := ⟨2, 0⟩
/-- HTTP/3 -/
def Version.http3 : Version := ⟨3, 0⟩

instance : ToString Version where
  toString v := s!"HTTP/{v.major}.{v.minor}"

/-- HTTP request message (RFC 9110 Section 6, decision D-001).

    A request is the combination of a method, target, headers, and
    optional body. The version is included for protocol-level concerns. -/
structure Request where
  /-- The request method (Section 9). -/
  method : Method
  /-- The request target (Section 7.1). -/
  target : RequestTarget
  /-- Header fields (Section 5). Ordered, may contain duplicates. -/
  headers : Headers := []
  /-- Optional message body. `none` means no body is present. -/
  body : Option ByteArray := none
  /-- HTTP version. -/
  version : Version := Version.http11

/-- HTTP response message (RFC 9110 Section 6, decision D-001). -/
structure Response where
  /-- The response status code (Section 15). -/
  status : StatusCode
  /-- Header fields (Section 5). Ordered, may contain duplicates. -/
  headers : Headers := []
  /-- Optional message body. `none` means no body is present. -/
  body : Option ByteArray := none
  /-- HTTP version. -/
  version : Version := Version.http11

-- Convenience accessors

/-- Get the Host header value from a request. -/
def Request.host (r : Request) : Option String :=
  r.headers.get? FieldName.host

/-- Get the Content-Length from a request's headers. -/
def Request.contentLength (r : Request) : Option Nat :=
  r.headers.getContentLength

/-- Get the Content-Length from a response's headers. -/
def Response.contentLength (r : Response) : Option Nat :=
  r.headers.getContentLength

/-- Get the Content-Type header value from a response. -/
def Response.contentType (r : Response) : Option String :=
  r.headers.get? FieldName.contentType

/-- Get the Location header value from a response. -/
def Response.location (r : Response) : Option String :=
  r.headers.get? FieldName.location

/-- Whether this response is a redirect (3xx with Location). -/
def Response.isRedirect (r : Response) : Bool :=
  r.status.statusClass == some .redirection && r.headers.contains FieldName.location

end SWELib.Networking.Http
