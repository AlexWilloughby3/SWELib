import SWELib
import SWELibBridge

/-!
# HTTP Contract Validator

Executable validator for HTTP request/response contracts derived from
RFC 9110. Implements the propositions in SWELib.Networking.Http.Contract
as decidable functions returning structured error messages.
-/

namespace SWELibCode.Validators

open SWELib.Networking.Http

/-- Validate an HTTP request against RFC 9110 constraints.
    Returns `Except.ok ()` if valid, or `Except.error msg` describing the violation. -/
def validateRequest (r : Request) : Except String Unit := do
  -- RFC 9110 §7.2: Host header is mandatory for HTTP/1.1
  if !r.hasHost then
    throw "Missing required Host header (RFC 9110 §7.2)"
  -- RFC 9110 §9.3.8: TRACE MUST NOT include a request body
  if r.method == .TRACE && r.body != none then
    throw "TRACE request MUST NOT include a body (RFC 9110 §9.3.8)"
  -- RFC 9110 §10.1.1: Expect header MUST NOT be sent to HTTP/1.0 recipients
  if r.headers.contains FieldName.expect then
    if r.version.major == 1 && r.version.minor == 0 then
      throw "Expect header MUST NOT be sent to HTTP/1.0 recipients (RFC 9110 §10.1.1)"
  -- RFC 9112 §6.3: Multiple inconsistent Content-Length values → reject with 400
  let reqClValues := r.headers.getAll FieldName.contentLength
  if reqClValues.length > 1 && !(reqClValues.all (· == reqClValues.head!)) then
    throw "Inconsistent Content-Length values in request (RFC 9112 §6.3)"
  -- RFC 9110 §7.1: asterisk-form only valid with OPTIONS
  match r.target with
  | .asteriskForm =>
    if r.method != .OPTIONS then
      throw "Asterisk-form target is only valid with OPTIONS method (RFC 9110 §7.1)"
  | .authorityForm _ _ =>
    if r.method != .CONNECT then
      throw "Authority-form target is only valid with CONNECT method (RFC 9110 §7.1)"
  | _ => pure ()

/-- Validate an HTTP response against RFC 9110 constraints.
    Returns `Except.ok ()` if valid, or `Except.error msg` describing the violation. -/
def validateResponse (req : Request) (resp : Response) : Except String Unit := do
  -- RFC 9110 §9.3.2: HEAD responses MUST NOT have a body
  if req.method == .HEAD && resp.body != none then
    throw "HEAD response MUST NOT contain a body (RFC 9110 §9.3.2)"
  -- RFC 9110 §15.2: 1xx responses MUST NOT have a body
  if resp.status.isInterim && resp.body != none then
    throw "1xx (Informational) response MUST NOT contain a body (RFC 9110 §15.2)"
  -- RFC 9110 §15.3.5: 204 No Content MUST NOT have a body
  if resp.status.code == 204 && resp.body != none then
    throw "204 No Content response MUST NOT contain a body (RFC 9110 §15.3.5)"
  -- RFC 9110 §15.4.5: 304 Not Modified MUST NOT have a body
  if resp.status.code == 304 && resp.body != none then
    throw "304 Not Modified response MUST NOT contain a body (RFC 9110 §15.4.5)"
  -- RFC 9110 §8.6: Content-Length MUST NOT appear in 1xx or 204 responses
  if (resp.status.isInterim || resp.status.code == 204) && resp.contentLength != none then
    throw "Content-Length MUST NOT be present in 1xx or 204 responses (RFC 9110 §8.6)"
  -- RFC 9110 §15.5.6: 405 MUST include Allow header
  if resp.status.code == 405 && !resp.headers.contains FieldName.allow then
    throw "405 Method Not Allowed response MUST include Allow header (RFC 9110 §15.5.6)"
  -- RFC 9110 §9.3.6: CONNECT 2xx MUST NOT have a body
  if req.method == .CONNECT && resp.status.statusClass == some .successful && resp.body != none then
    throw "CONNECT 2xx response MUST NOT contain a body (RFC 9110 §9.3.6)"
  -- RFC 9110 §8.6: CONNECT 2xx MUST NOT have Content-Length
  if req.method == .CONNECT && resp.status.statusClass == some .successful && resp.contentLength != none then
    throw "CONNECT 2xx response MUST NOT include Content-Length header (RFC 9110 §8.6)"
  -- RFC 9110 §11.6.1: 401 Unauthorized MUST include WWW-Authenticate
  if resp.status.code == 401 && !resp.headers.contains FieldName.wwwAuthenticate then
    throw "401 Unauthorized MUST include WWW-Authenticate header (RFC 9110 §11.6.1)"
  -- RFC 9110 §11.7.2: 407 Proxy Authentication Required MUST include Proxy-Authenticate
  if resp.status.code == 407 && !resp.headers.contains FieldName.proxyAuthenticate then
    throw "407 Proxy Authentication Required MUST include Proxy-Authenticate header (RFC 9110 §11.7.2)"
  -- RFC 9112 §6.3: Multiple inconsistent Content-Length values are a protocol error
  let clValues := resp.headers.getAll FieldName.contentLength
  if clValues.length > 1 && !(clValues.all (· == clValues.head!)) then
    throw "Inconsistent Content-Length values in response (RFC 9112 §6.3)"
  -- RFC 9110 §8.6: Content-Length must match actual body size
  match resp.contentLength, resp.body with
  | some n, some b =>
    if b.size != n then
      throw s!"Content-Length ({n}) does not match body size ({b.size}) (RFC 9110 §8.6)"
  | some _, none =>
    throw "Content-Length is present but no body was sent (RFC 9110 §8.6)"
  | none, _ => pure ()
  -- RFC 9112 §6.3: Transfer-Encoding and Content-Length MUST NOT both be present
  if resp.headers.contains FieldName.transferEncoding && resp.contentLength != none then
    throw "Transfer-Encoding and Content-Length MUST NOT both be present (RFC 9112 §6.3)"
  -- RFC 9110 §15.3.7: 206 Partial Content MUST include Content-Range
  if resp.status.code == 206 && !resp.headers.contains FieldName.contentRange then
    throw "206 Partial Content MUST include Content-Range header (RFC 9110 §15.3.7)"
  -- RFC 9110 §15.5.17: 416 Range Not Satisfiable MUST include Content-Range
  if resp.status.code == 416 && !resp.headers.contains FieldName.contentRange then
    throw "416 Range Not Satisfiable MUST include Content-Range header (RFC 9110 §15.5.17)"

/-- Validate both request and response together.
    Returns `Except.ok ()` if both are valid. -/
def validateExchange (req : Request) (resp : Response) : Except String Unit := do
  validateRequest req
  validateResponse req resp

end SWELibCode.Validators
