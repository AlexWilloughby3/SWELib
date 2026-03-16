/-!
# HTTP Methods

RFC 9110 Section 9: Request methods and their properties.
-/

namespace SWELib.Networking.Http

/-- Standard HTTP request methods per RFC 9110 Section 9.3,
    plus an `extension` constructor for method extensibility (Section 16.1). -/
inductive Method where
  | GET
  | HEAD
  | POST
  | PUT
  | PATCH
  | DELETE
  | CONNECT
  | OPTIONS
  | TRACE
  /-- Extension methods per RFC 9110 Section 16.1.
      The token must be a valid HTTP method token. -/
  | extension (token : String)
  deriving DecidableEq, Repr

instance : ToString Method where
  toString
    | .GET => "GET"
    | .HEAD => "HEAD"
    | .POST => "POST"
    | .PUT => "PUT"
    | .PATCH => "PATCH"
    | .DELETE => "DELETE"
    | .CONNECT => "CONNECT"
    | .OPTIONS => "OPTIONS"
    | .TRACE => "TRACE"
    | .extension t => t

/-- A method is safe if it is essentially read-only (RFC 9110 Section 9.2.1).
    Safe methods do not request modification of resource state. -/
def Method.isSafe : Method → Bool
  | .GET | .HEAD | .OPTIONS | .TRACE => true
  | _ => false

/-- A method is idempotent if multiple identical requests have the same
    effect as a single request (RFC 9110 Section 9.2.2). -/
def Method.isIdempotent : Method → Bool
  | .GET | .HEAD | .PUT | .DELETE | .OPTIONS | .TRACE => true
  | _ => false

/-- A method's response is cacheable by default (RFC 9110 Section 9.2.3).
    Only GET and HEAD responses are cacheable by default. -/
def Method.isCacheableByDefault : Method → Bool
  | .GET | .HEAD => true
  | _ => false

/-- RFC 9110 Section 9.2.2: Every safe method is also idempotent. -/
theorem Method.safe_implies_idempotent (m : Method) :
    m.isSafe = true → m.isIdempotent = true := by
  cases m <;> simp [isSafe, isIdempotent]

/-- RFC 9110 Section 9.2.3: Every cacheable-by-default method is safe. -/
theorem Method.cacheableByDefault_implies_safe (m : Method) :
    m.isCacheableByDefault = true → m.isSafe = true := by
  cases m <;> simp [isCacheableByDefault, isSafe]

/-- Whether a request with this method is expected to have a body.
    RFC 9110 Section 9.3.8: TRACE MUST NOT include body.
    GET/HEAD/DELETE/CONNECT/OPTIONS: body has no defined semantics but is not prohibited. -/
def Method.requestBodyExpected : Method → Bool
  | .POST | .PUT | .PATCH => true
  | _ => false

/-- Methods that MUST NOT include a request body.
    RFC 9110 Section 9.3.8: TRACE MUST NOT include a body. -/
def Method.requestBodyForbidden : Method → Bool
  | .TRACE => true
  | _ => false

/-- A method cannot both expect and forbid a body. -/
theorem Method.bodyExpected_not_forbidden (m : Method) :
    m.requestBodyExpected = true → m.requestBodyForbidden = false := by
  cases m <;> simp [requestBodyExpected, requestBodyForbidden]

/-- PATCH is not a safe method (RFC 5789 Section 2). -/
theorem Method.patch_not_safe : Method.PATCH.isSafe = false := by rfl

/-- PATCH is not idempotent (RFC 5789 Section 2). -/
theorem Method.patch_not_idempotent : Method.PATCH.isIdempotent = false := by rfl

/-- The string representation of each standard method is its canonical name. -/
theorem Method.toString_PATCH : toString Method.PATCH = "PATCH" := rfl

/-- Safe methods are a strict subset of idempotent methods:
    there exist idempotent methods that are not safe. -/
theorem Method.idempotent_not_implies_safe :
    ∃ m : Method, m.isIdempotent = true ∧ m.isSafe = false := by
  exact ⟨.PUT, by decide, by decide⟩

/-- Extension methods are never safe by default. -/
theorem Method.extension_not_safe (token : String) :
    (Method.extension token).isSafe = false := by rfl

/-- Extension methods are never idempotent by default. -/
theorem Method.extension_not_idempotent (token : String) :
    (Method.extension token).isIdempotent = false := by rfl

end SWELib.Networking.Http
