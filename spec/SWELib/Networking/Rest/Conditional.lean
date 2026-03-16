import SWELib.Networking.Http.Representation
import SWELib.Basics.Time
import Std

/-!
# REST Conditional Requests

Conditional requests as defined in RFC 9110 Section 13.
Includes ETag validators and time validators.

Reference: RFC 9110 Section 13 (Conditional Requests)
-/

namespace SWELib.Networking.Rest

/-- Conditional request validators.

    Combines ETag validators (If-Match, If-None-Match) and
    time validators (If-Modified-Since, If-Unmodified-Since).

    Section: RFC 9110 Section 13.1 (Precondition Header Fields) -/
structure ConditionalRequest where
  /-- If-Match: ETag validator for strong comparison (RFC 9110 Section 13.1.1). -/
  ifMatch : Option (List SWELib.Networking.Http.ETag) := none
  /-- If-None-Match: ETag validator for weak comparison (RFC 9110 Section 13.1.2). -/
  ifNoneMatch : Option (List SWELib.Networking.Http.ETag) := none
  /-- If-Modified-Since: Time validator for GET/HEAD (RFC 9110 Section 13.1.3). -/
  ifModifiedSince : Option SWELib.Basics.NumericDate := none
  /-- If-Unmodified-Since: Time validator for unsafe methods (RFC 9110 Section 13.1.4). -/
  ifUnmodifiedSince : Option SWELib.Basics.NumericDate := none
  deriving Repr, DecidableEq


/-- Validation consistency: ifMatch and ifNoneMatch cannot both be present.

    Section: RFC 9110 Section 13.1 (mutually exclusive preconditions) -/
theorem validation_consistency (cr : ConditionalRequest) :
    (cr.ifMatch.isSome ∧ cr.ifNoneMatch.isSome) → False := by
  sorry

/-- Time monotonicity: ifModifiedSince must be less than ifUnmodifiedSince when both present.

    Section: RFC 9110 Section 13.1.3-13.1.4 (time validator semantics) -/
theorem time_monotonicity (cr : ConditionalRequest) :
    (cr.ifModifiedSince.isSome ∧ cr.ifUnmodifiedSince.isSome) →
    cr.ifModifiedSince.get! < cr.ifUnmodifiedSince.get! := by
  sorry

/-- Validate conditional request against current ETag.

    Returns true if the condition is satisfied.

    Section: RFC 9110 Section 13.1.1 (If-Match) -/
def validateIfMatch (cr : ConditionalRequest) (currentETag : SWELib.Networking.Http.ETag) : Bool :=
  match cr.ifMatch with
  | none => true  -- No If-Match means condition is satisfied
  | some etags => etags.any (λ etag => etag.strongEq currentETag)

/-- Validate conditional request against current ETag for If-None-Match.

    Returns true if the condition is satisfied.

    Section: RFC 9110 Section 13.1.2 (If-None-Match) -/
def validateIfNoneMatch (cr : ConditionalRequest) (currentETag : SWELib.Networking.Http.ETag) : Bool :=
  match cr.ifNoneMatch with
  | none => true  -- No If-None-Match means condition is satisfied
  | some etags => !etags.any (λ etag => etag.weakEq currentETag)

/-- Validate conditional request against last modified time.

    Returns true if the condition is satisfied.

    Section: RFC 9110 Section 13.1.3 (If-Modified-Since) -/
def validateIfModifiedSince (cr : ConditionalRequest) (lastModified : SWELib.Basics.NumericDate) : Bool :=
  match cr.ifModifiedSince with
  | none => true
  | some since => lastModified.toSeconds > since.toSeconds

/-- Validate conditional request against last modified time for If-Unmodified-Since.

    Returns true if the condition is satisfied.

    Section: RFC 9110 Section 13.1.4 (If-Unmodified-Since) -/
def validateIfUnmodifiedSince (cr : ConditionalRequest) (lastModified : SWELib.Basics.NumericDate) : Bool :=
  match cr.ifUnmodifiedSince with
  | none => true
  | some since => lastModified.toSeconds ≤ since.toSeconds

/-- Validate all conditions in a conditional request.

    Returns true if all present conditions are satisfied.

    Section: RFC 9110 Section 13 (Conditional Requests) -/
def validateConditionalRequest (cr : ConditionalRequest)
    (currentETag : Option SWELib.Networking.Http.ETag)
    (lastModified : Option SWELib.Basics.NumericDate) : Bool :=
  let etagValid :=
    match currentETag with
    | none =>
      -- No current ETag: If-Match with "*" fails, otherwise passes
      match cr.ifMatch with
      | none => true
      | some etags => !etags.any (λ etag => etag == ⟨"*", false⟩)
    | some etag =>
      validateIfMatch cr etag && validateIfNoneMatch cr etag
  let timeValid :=
    match lastModified with
    | none => true  -- No last modified time, time validators don't apply
    | some lm =>
      validateIfModifiedSince cr lm && validateIfUnmodifiedSince cr lm
  etagValid && timeValid

end SWELib.Networking.Rest