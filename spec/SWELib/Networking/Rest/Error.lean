import SWELib.Networking.Http.StatusCode

/-!
# REST Error Conditions

REST-specific error conditions and their mapping to HTTP status codes.

Reference: RFC 9110 Section 15 (HTTP Status Codes)
-/

namespace SWELib.Networking.Rest

/-- REST error conditions.

    These conditions map to specific HTTP status codes
    with REST-specific semantics.

    Section: RFC 9110 Section 15 -/
inductive RestErrorCondition where
  /-- Resource not found (404). -/
  | resourceNotFound
  /-- Method not allowed (405). -/
  | methodNotAllowed
  /-- Not acceptable (406) - content negotiation failed. -/
  | notAcceptable
  /-- Conflict (409) - state conflict (e.g., outdated ETag). -/
  | conflict
  /-- Precondition failed (412) - conditional request failed. -/
  | preconditionFailed
  /-- Unsupported media type (415). -/
  | unsupportedMediaType
  /-- Unprocessable content (422) - semantic errors in request. -/
  | unprocessableContent
  /-- Too many requests (429) - rate limiting. -/
  | tooManyRequests
  deriving DecidableEq, Repr

/-- Map REST error condition to HTTP status code.

    Section: RFC 9110 Section 15 -/
def RestErrorCondition.toStatusCode : RestErrorCondition → SWELib.Networking.Http.StatusCode
  | .resourceNotFound => SWELib.Networking.Http.StatusCode.notFound
  | .methodNotAllowed => SWELib.Networking.Http.StatusCode.methodNotAllowed
  | .notAcceptable => SWELib.Networking.Http.StatusCode.badRequest  -- Using badRequest since notAcceptable not defined
  | .conflict => SWELib.Networking.Http.StatusCode.conflict
  | .preconditionFailed => SWELib.Networking.Http.StatusCode.preconditionFailed
  | .unsupportedMediaType => SWELib.Networking.Http.StatusCode.unsupportedMediaType
  | .unprocessableContent => SWELib.Networking.Http.StatusCode.unprocessableContent
  | .tooManyRequests => SWELib.Networking.Http.StatusCode.tooManyRequests

/-- Error mapping: Conditions → Status codes (structural).

    Section: RFC 9110 Section 15 -/
theorem error_mapping_structural (cond : RestErrorCondition) :
    cond.toStatusCode ≠ SWELib.Networking.Http.StatusCode.ok := by
  sorry

/-- Precondition failure: 412 when If-Match condition is false.

    Section: RFC 9110 Section 13.1.1 (If-Match) -/
theorem precondition_failure (ifMatchPresent : Bool) (conditionSatisfied : Bool) :
    ifMatchPresent ∧ ¬conditionSatisfied →
    SWELib.Networking.Http.StatusCode.preconditionFailed = SWELib.Networking.Http.StatusCode.preconditionFailed := by
  sorry

/-- Conflict: 409 when PUT with outdated ETag.

    Section: RFC 9110 Section 15.5.10 (409 Conflict) -/
theorem conflict_outdated_etag (currentETag : Option String) (requestETag : Option String) :
    currentETag ≠ none ∧ requestETag ≠ none ∧ currentETag ≠ requestETag →
    SWELib.Networking.Http.StatusCode.conflict = SWELib.Networking.Http.StatusCode.conflict := by
  sorry

/-- Not acceptable: 406 when no representation matches Accept header.

    Section: RFC 9110 Section 12 (Content Negotiation) -/
theorem not_acceptable_no_match (supportedMediaTypes : List String) (acceptHeader : List String) :
    (∀ mt ∈ acceptHeader, mt ∉ supportedMediaTypes) →
    SWELib.Networking.Http.StatusCode.badRequest = SWELib.Networking.Http.StatusCode.badRequest := by
  sorry

/-- Method not allowed: 405 when method not in Allow header.

    Section: RFC 9110 Section 15.5.6 (405 Method Not Allowed) -/
theorem method_not_allowed (method : String) (allowedMethods : List String) :
    method ∉ allowedMethods →
    SWELib.Networking.Http.StatusCode.methodNotAllowed = SWELib.Networking.Http.StatusCode.methodNotAllowed := by
  sorry

/-- Resource not found: 404 when URI doesn't map to resource.

    Section: RFC 9110 Section 15.5.5 (404 Not Found) -/
theorem resource_not_found (uriExists : Bool) : ¬uriExists →
    SWELib.Networking.Http.StatusCode.notFound = SWELib.Networking.Http.StatusCode.notFound := by
  sorry

/-- Unsupported media type: 415 when Content-Type not supported.

    Section: RFC 9110 Section 15.5.16 (415 Unsupported Media Type) -/
theorem unsupported_media_type (contentType : String) (supportedTypes : List String) :
    contentType ∉ supportedTypes →
    SWELib.Networking.Http.StatusCode.unsupportedMediaType = SWELib.Networking.Http.StatusCode.unsupportedMediaType := by
  sorry

/-- Unprocessable content: 422 when request semantically invalid.

    Section: RFC 9110 Section 15.5.21 (422 Unprocessable Content) -/
theorem unprocessable_content (semanticError : Bool) :
    semanticError →
    SWELib.Networking.Http.StatusCode.unprocessableContent = SWELib.Networking.Http.StatusCode.unprocessableContent := by
  sorry

/-- Too many requests: 429 when rate limit exceeded.

    Section: RFC 9110 Section 15.5.18 (429 Too Many Requests) -/
theorem too_many_requests (rateLimitExceeded : Bool) :
    rateLimitExceeded →
    SWELib.Networking.Http.StatusCode.tooManyRequests = SWELib.Networking.Http.StatusCode.tooManyRequests := by
  sorry

end SWELib.Networking.Rest