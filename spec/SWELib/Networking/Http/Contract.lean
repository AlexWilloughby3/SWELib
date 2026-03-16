import SWELib.Networking.Http.Message
import SWELib.Networking.Http.Representation

/-!
# HTTP Request-Response Contracts

Cross-cutting constraints from RFC 9110 that define validity of
HTTP requests and responses. These bundle the normative MUST/MUST NOT
requirements into provable/decidable propositions.
-/

namespace SWELib.Networking.Http

/-! ## Request Validity -/

/-- A request MUST include a Host header unless it uses the :authority
    pseudo-header (HTTP/2+). For HTTP/1.1, Host is mandatory
    (RFC 9110 Section 7.2). -/
def Request.hasHost (r : Request) : Bool :=
  r.headers.contains FieldName.host

/-- TRACE requests MUST NOT include a body (RFC 9110 Section 9.3.8). -/
def Request.traceHasNoBody (r : Request) : Prop :=
  r.method = .TRACE → r.body = none

/-- Asterisk-form target is only valid with OPTIONS (RFC 9110 Section 7.1). -/
def Request.asteriskOnlyWithOptions (r : Request) : Prop :=
  r.target = .asteriskForm → r.method = .OPTIONS

/-- Authority-form target is only valid with CONNECT (RFC 9110 Section 7.1). -/
def Request.authorityOnlyWithConnect (r : Request) : Prop :=
  match r.target with
  | .authorityForm _ _ => r.method = .CONNECT
  | _ => True

/-- Expect header MUST NOT be sent to HTTP/1.0 recipients (RFC 9110 Section 10.1.1).
    HTTP/2+ has major > 1, so only (major=1, minor=0) is prohibited. -/
def expectVersionValid (req : Request) : Prop :=
  req.headers.contains FieldName.expect = true →
    ¬(req.version.major = 1 ∧ req.version.minor = 0)

/-- Bundle of all RFC 9110 request validity constraints. -/
structure ValidRequest (r : Request) : Prop where
  /-- Host header is present (Section 7.2). -/
  hasHost : r.hasHost = true
  /-- TRACE must not have a body (Section 9.3.8). -/
  traceNoBody : r.traceHasNoBody
  /-- Asterisk form only with OPTIONS (Section 7.1). -/
  asteriskOptions : r.asteriskOnlyWithOptions
  /-- Authority form only with CONNECT (Section 7.1). -/
  authorityConnect : r.authorityOnlyWithConnect
  /-- Expect header version constraint (Section 10.1.1). -/
  expectVersion : expectVersionValid r

/-! ## Response Validity -/

/-- A HEAD response MUST NOT contain a message body
    (RFC 9110 Section 9.3.2). -/
def headResponseNoBody (req : Request) (resp : Response) : Prop :=
  req.method = .HEAD → resp.body = none

/-- 1xx (Informational) responses MUST NOT contain a body
    (RFC 9110 Section 15.2). -/
def interimResponseNoBody (resp : Response) : Prop :=
  resp.status.isInterim = true → resp.body = none

/-- 204 (No Content) responses MUST NOT contain a body
    (RFC 9110 Section 15.3.5). -/
def noContentResponseNoBody (resp : Response) : Prop :=
  resp.status.code = 204 → resp.body = none

/-- 304 (Not Modified) responses MUST NOT contain a body
    (RFC 9110 Section 15.4.5). -/
def notModifiedResponseNoBody (resp : Response) : Prop :=
  resp.status.code = 304 → resp.body = none

/-- CONNECT 2xx responses MUST NOT contain a body in the traditional sense
    (RFC 9110 Section 9.3.6). -/
def connectSuccessNoBody (req : Request) (resp : Response) : Prop :=
  req.method = .CONNECT → resp.status.statusClass = some .successful →
    resp.body = none

/-- A server MUST NOT send Content-Length in 1xx or 204 responses
    (RFC 9110 Section 8.6). -/
def noContentLengthOnBodylessStatus (resp : Response) : Prop :=
  (resp.status.isInterim = true ∨ resp.status.code = 204) →
    resp.contentLength = none

/-- A CONNECT 2xx response MUST NOT include a Content-Length header
    (RFC 9110 Section 8.6, RFC 9112 Section 6.1). -/
def connectSuccessNoContentLength (req : Request) (resp : Response) : Prop :=
  req.method = .CONNECT → resp.status.statusClass = some .successful →
    resp.contentLength = none

/-- A 407 Proxy Authentication Required response MUST include a Proxy-Authenticate
    header (RFC 9110 Section 11.7.2). -/
def proxyAuthRequiredHasProxyAuthenticate (resp : Response) : Prop :=
  resp.status.code = 407 →
    resp.headers.contains FieldName.proxyAuthenticate = true

/-- 405 (Method Not Allowed) response MUST include an Allow header
    (RFC 9110 Section 15.5.6). -/
def methodNotAllowedHasAllow (resp : Response) : Prop :=
  resp.status.code = 405 → resp.headers.contains FieldName.allow = true

/-- Transfer-Encoding takes precedence over Content-Length for message framing.
    When Transfer-Encoding is present, Content-Length MUST NOT be used for
    determining the body length (RFC 9112 Section 6.3). -/
def transferEncodingPrecedence (resp : Response) : Prop :=
  resp.headers.contains FieldName.transferEncoding = true →
    resp.contentLength = none

/-- A 206 Partial Content response MUST include a Content-Range header
    (RFC 9110 Section 15.3.7). -/
def partialContentHasContentRange (resp : Response) : Prop :=
  resp.status.code = 206 →
    resp.headers.contains FieldName.contentRange = true

/-- A 416 Range Not Satisfiable response MUST include a Content-Range header
    with an unsatisfied-range value (RFC 9110 Section 15.5.17). -/
def rangeNotSatisfiableHasContentRange (resp : Response) : Prop :=
  resp.status.code = 416 →
    resp.headers.contains FieldName.contentRange = true

/-- A 401 Unauthorized response MUST include WWW-Authenticate header
    (RFC 9110 Section 11.6.1). -/
def unauthorizedHasWWWAuthenticate' (resp : Response) : Prop :=
  resp.status.code = 401 →
    resp.headers.contains FieldName.wwwAuthenticate = true

/-- Bundle of all RFC 9110 response validity constraints.
    Takes the corresponding request because some constraints
    depend on the request method. -/
structure ValidResponse (req : Request) (resp : Response) : Prop where
  /-- HEAD responses have no body (Section 9.3.2). -/
  headNoBody : headResponseNoBody req resp
  /-- 1xx responses have no body (Section 15.2). -/
  interimNoBody : interimResponseNoBody resp
  /-- 204 responses have no body (Section 15.3.5). -/
  noContentNoBody : noContentResponseNoBody resp
  /-- 304 responses have no body (Section 15.4.5). -/
  notModifiedNoBody : notModifiedResponseNoBody resp
  /-- CONNECT 2xx responses have no body (Section 9.3.6). -/
  connectNoBody : connectSuccessNoBody req resp
  /-- Content-Length absent on bodyless statuses (Section 8.6). -/
  noContentLengthBodyless : noContentLengthOnBodylessStatus resp
  /-- CONNECT 2xx responses have no Content-Length (Section 8.6). -/
  connectNoContentLength : connectSuccessNoContentLength req resp
  /-- 405 responses include Allow header (Section 15.5.6). -/
  methodNotAllowed : methodNotAllowedHasAllow resp
  /-- Content-Length matches body size when present (Section 8.6). -/
  contentLengthValid : contentLengthValid resp
  /-- Transfer-Encoding takes precedence over Content-Length (RFC 9112 §6.3). -/
  transferEncodingPrec : transferEncodingPrecedence resp
  /-- 206 responses include Content-Range (Section 15.3.7). -/
  partialContentRange : partialContentHasContentRange resp
  /-- 416 responses include Content-Range (Section 15.5.17). -/
  rangeNotSatisfiableRange : rangeNotSatisfiableHasContentRange resp
  /-- 401 responses include WWW-Authenticate (Section 11.6.1). -/
  unauthorizedHasAuth : unauthorizedHasWWWAuthenticate' resp
  /-- 407 responses include Proxy-Authenticate (Section 11.7.2). -/
  proxyAuthHasAuth : proxyAuthRequiredHasProxyAuthenticate resp

-- Additional theorems

/-- A valid response for a HEAD request has no body. -/
theorem ValidResponse.head_no_body {req : Request} {resp : Response}
    (v : ValidResponse req resp) (h : req.method = .HEAD) : resp.body = none :=
  v.headNoBody h

/-- A valid interim response has no body. -/
theorem ValidResponse.interim_no_body {req : Request} {resp : Response}
    (v : ValidResponse req resp) (h : resp.status.isInterim = true) : resp.body = none :=
  v.interimNoBody h

/-- Transfer-Encoding and Content-Length are mutually exclusive in a valid response. -/
theorem ValidResponse.te_excludes_cl {req : Request} {resp : Response}
    (v : ValidResponse req resp)
    (hte : resp.headers.contains FieldName.transferEncoding = true) :
    resp.contentLength = none :=
  v.transferEncodingPrec hte

/-- A valid 206 response always carries a Content-Range header. -/
theorem ValidResponse.partial_content_has_range {req : Request} {resp : Response}
    (v : ValidResponse req resp) (h : resp.status.code = 206) :
    resp.headers.contains FieldName.contentRange = true :=
  v.partialContentRange h

end SWELib.Networking.Http
