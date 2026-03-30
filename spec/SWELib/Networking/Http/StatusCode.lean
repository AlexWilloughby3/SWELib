/-!
# HTTP Status Codes

RFC 9110 Section 15: Status codes and their classes.
-/

namespace SWELib.Networking.Http

/-- HTTP status code class (RFC 9110 Section 15.1). -/
inductive StatusClass where
  /-- 1xx: The request was received, continuing process. -/
  | informational
  /-- 2xx: The request was successfully received, understood, and accepted. -/
  | successful
  /-- 3xx: Further action needs to be taken to complete the request. -/
  | redirection
  /-- 4xx: The request contains bad syntax or cannot be fulfilled. -/
  | clientError
  /-- 5xx: The server failed to fulfill an apparently valid request. -/
  | serverError
  deriving DecidableEq, Repr

/-- HTTP status code: a three-digit integer (RFC 9110 Section 15).
    Valid codes range from 100 to 999. -/
structure StatusCode where
  /-- The numeric status code. -/
  code : Nat
  /-- Proof that the code is a valid three-digit number. -/
  h_range : 100 ≤ code ∧ code ≤ 999
  deriving Repr

instance : DecidableEq StatusCode := fun a b =>
  if h : a.code = b.code then
    have : a = b := by
      cases a; cases b; simp_all
    isTrue this
  else
    isFalse (fun heq => h (by cases heq; rfl))

instance : ToString StatusCode where
  toString s := toString s.code

/-- Determine the class of a status code from its first digit. -/
def StatusCode.statusClass (s : StatusCode) : Option StatusClass :=
  if s.code < 200 then some .informational
  else if s.code < 300 then some .successful
  else if s.code < 400 then some .redirection
  else if s.code < 500 then some .clientError
  else if s.code < 600 then some .serverError
  else none

/-- Whether a response with this status code may include a message body.
    RFC 9110: 1xx, 204, and 304 responses MUST NOT contain body. -/
def StatusCode.mayHaveBody (s : StatusCode) : Bool :=
  s.code ≥ 200 && s.code != 204 && s.code != 304

/-- Whether this is an interim (1xx) response. -/
def StatusCode.isInterim (s : StatusCode) : Bool :=
  s.code < 200

/-- Whether this is a final (non-1xx) response. -/
def StatusCode.isFinal (s : StatusCode) : Bool :=
  s.code ≥ 200

/-- Whether this status code indicates an error (4xx or 5xx per RFC 9110 Section 15).
    Codes 6xx-9xx are unassigned and not classified as errors by the spec. -/
def StatusCode.isError (s : StatusCode) : Bool :=
  400 ≤ s.code && s.code < 600

/-- Helper to construct a StatusCode with proof by decide. -/
private def mkCode (n : Nat) (h : 100 ≤ n ∧ n ≤ 999 := by decide) : StatusCode :=
  ⟨n, h⟩

-- Well-known status codes (RFC 9110 Section 15)

/-- 100 Continue -/
def StatusCode.continue_ : StatusCode := mkCode 100
/-- 101 Switching Protocols -/
def StatusCode.switchingProtocols : StatusCode := mkCode 101

/-- 200 OK -/
def StatusCode.ok : StatusCode := mkCode 200
/-- 201 Created -/
def StatusCode.created : StatusCode := mkCode 201
/-- 202 Accepted -/
def StatusCode.accepted : StatusCode := mkCode 202
/-- 203 Non-Authoritative Information -/
def StatusCode.nonAuthoritativeInformation : StatusCode := mkCode 203
/-- 204 No Content -/
def StatusCode.noContent : StatusCode := mkCode 204
/-- 205 Reset Content -/
def StatusCode.resetContent : StatusCode := mkCode 205
/-- 206 Partial Content -/
def StatusCode.partialContent : StatusCode := mkCode 206

/-- 300 Multiple Choices -/
def StatusCode.multipleChoices : StatusCode := mkCode 300
/-- 301 Moved Permanently -/
def StatusCode.movedPermanently : StatusCode := mkCode 301
/-- 302 Found -/
def StatusCode.found : StatusCode := mkCode 302
/-- 303 See Other -/
def StatusCode.seeOther : StatusCode := mkCode 303
/-- 304 Not Modified -/
def StatusCode.notModified : StatusCode := mkCode 304
/-- 307 Temporary Redirect -/
def StatusCode.temporaryRedirect : StatusCode := mkCode 307
/-- 308 Permanent Redirect -/
def StatusCode.permanentRedirect : StatusCode := mkCode 308

/-- 400 Bad Request -/
def StatusCode.badRequest : StatusCode := mkCode 400
/-- 401 Unauthorized -/
def StatusCode.unauthorized : StatusCode := mkCode 401
/-- 402 Payment Required -/
def StatusCode.paymentRequired : StatusCode := mkCode 402
/-- 403 Forbidden -/
def StatusCode.forbidden : StatusCode := mkCode 403
/-- 404 Not Found -/
def StatusCode.notFound : StatusCode := mkCode 404
/-- 405 Method Not Allowed -/
def StatusCode.methodNotAllowed : StatusCode := mkCode 405
/-- 406 Not Acceptable -/
def StatusCode.notAcceptable : StatusCode := mkCode 406
/-- 407 Proxy Authentication Required -/
def StatusCode.proxyAuthRequired : StatusCode := mkCode 407
/-- 408 Request Timeout -/
def StatusCode.requestTimeout : StatusCode := mkCode 408
/-- 409 Conflict -/
def StatusCode.conflict : StatusCode := mkCode 409
/-- 410 Gone -/
def StatusCode.gone : StatusCode := mkCode 410
/-- 411 Length Required -/
def StatusCode.lengthRequired : StatusCode := mkCode 411
/-- 412 Precondition Failed -/
def StatusCode.preconditionFailed : StatusCode := mkCode 412
/-- 413 Content Too Large -/
def StatusCode.contentTooLarge : StatusCode := mkCode 413
/-- 414 URI Too Long -/
def StatusCode.uriTooLong : StatusCode := mkCode 414
/-- 415 Unsupported Media Type -/
def StatusCode.unsupportedMediaType : StatusCode := mkCode 415
/-- 416 Range Not Satisfiable -/
def StatusCode.rangeNotSatisfiable : StatusCode := mkCode 416
/-- 421 Misdirected Request -/
def StatusCode.misdirectedRequest : StatusCode := mkCode 421
/-- 417 Expectation Failed -/
def StatusCode.expectationFailed : StatusCode := mkCode 417
/-- 422 Unprocessable Content -/
def StatusCode.unprocessableContent : StatusCode := mkCode 422
/-- 426 Upgrade Required -/
def StatusCode.upgradeRequired : StatusCode := mkCode 426
/-- 429 Too Many Requests (RFC 6585) -/
def StatusCode.tooManyRequests : StatusCode := mkCode 429

/-- 500 Internal Server Error -/
def StatusCode.internalServerError : StatusCode := mkCode 500
/-- 501 Not Implemented -/
def StatusCode.notImplemented : StatusCode := mkCode 501
/-- 502 Bad Gateway -/
def StatusCode.badGateway : StatusCode := mkCode 502
/-- 503 Service Unavailable -/
def StatusCode.serviceUnavailable : StatusCode := mkCode 503
/-- 504 Gateway Timeout -/
def StatusCode.gatewayTimeout : StatusCode := mkCode 504
/-- 505 HTTP Version Not Supported -/
def StatusCode.httpVersionNotSupported : StatusCode := mkCode 505

-- Theorems

/-- Interim responses never have bodies. -/
theorem StatusCode.interim_no_body (s : StatusCode) :
    s.isInterim = true → s.mayHaveBody = false := by
  simp only [isInterim, mayHaveBody]
  intro h
  have hlt := of_decide_eq_true h
  have : ¬(s.code ≥ 200) := Nat.not_le_of_lt hlt
  simp [decide_eq_false this]

/-- All error status codes are final responses. -/
theorem StatusCode.error_is_final (s : StatusCode) :
    s.isError = true → s.isFinal = true := by
  intro h
  simp only [StatusCode.isError, Bool.and_eq_true, decide_eq_true_eq] at h
  simp only [StatusCode.isFinal, decide_eq_true_eq]
  omega

/-- 2xx responses are always final (RFC 9110 Section 15.1). -/
theorem StatusCode.successful_is_final (s : StatusCode) :
    s.statusClass = some .successful → s.isFinal = true := by
  unfold statusClass isFinal
  intro h
  split at h
  · exact absurd h (by decide)
  · exact decide_eq_true (by omega)
  all_goals exact absurd h (by decide)

/-- The status class of a 200 response is .successful. -/
theorem StatusCode.ok_is_successful :
    StatusCode.ok.statusClass = some .successful := by native_decide

/-- All 4xx codes are errors. -/
theorem StatusCode.clientError_is_error (s : StatusCode) :
    s.statusClass = some .clientError → s.isError = true := by
  unfold statusClass isError
  intro h
  split at h
  · simp at h
  · split at h
    · simp at h
    · split at h
      · simp at h
      · split at h
        · -- 400 ≤ s.code < 500
          simp [Bool.and_eq_true, decide_eq_true_eq]
          constructor <;> omega
        · split at h <;> simp at h

/-- 5xx server errors are also errors. -/
theorem StatusCode.serverError_is_error (s : StatusCode) :
    s.statusClass = some .serverError → s.isError = true := by
  unfold statusClass isError
  simp only [Bool.and_eq_true, decide_eq_true_eq]
  intro h
  split at h
  · exact absurd h (by decide)
  · split at h
    · exact absurd h (by decide)
    · split at h
      · exact absurd h (by decide)
      · split at h
        · exact absurd h (by decide)
        · split at h
          · -- 500 ≤ s.code < 600
            constructor <;> omega
          · exact absurd h (by decide)

end SWELib.Networking.Http
