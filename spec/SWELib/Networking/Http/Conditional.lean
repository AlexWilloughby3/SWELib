import SWELib.Networking.Http.Message
import SWELib.Networking.Http.Representation

/-!
# HTTP Conditional Requests

RFC 9110 Section 13: Conditional request headers and evaluation precedence.

Conditional requests allow a client to attach preconditions to a request,
asking the server to perform the action only if the precondition holds.
-/

namespace SWELib.Networking.Http

/-- The result of evaluating HTTP preconditions (RFC 9110 Section 13.2). -/
inductive PreconditionResult where
  /-- Precondition is satisfied: proceed with the request normally. -/
  | proceed
  /-- Precondition failed: respond with 412 Precondition Failed (Section 15.5.13). -/
  | preconditionFailed
  /-- Not modified: respond with 304 Not Modified (Section 15.4.5). -/
  | notModified
  deriving DecidableEq, Repr

/-- The conditional headers present in a request. -/
structure ConditionalHeaders where
  /-- If-Match: precondition on current ETag (RFC 9110 Section 13.1.1). -/
  ifMatch        : Option String := none
  /-- If-None-Match: precondition on absent or different ETag (Section 13.1.2). -/
  ifNoneMatch    : Option String := none
  /-- If-Modified-Since: precondition on modification time (Section 13.1.3). -/
  ifModifiedSince    : Option String := none
  /-- If-Unmodified-Since: precondition on unmodified since (Section 13.1.4). -/
  ifUnmodifiedSince  : Option String := none
  /-- If-Range: precondition for partial range requests (Section 13.1.5). -/
  ifRange        : Option String := none
  deriving Repr

/-- Extract conditional headers from a request's header fields. -/
def ConditionalHeaders.fromRequest (req : Request) : ConditionalHeaders :=
  { ifMatch            := req.headers.get? FieldName.ifMatch
    ifNoneMatch        := req.headers.get? FieldName.ifNoneMatch
    ifModifiedSince    := req.headers.get? FieldName.ifModifiedSince
    ifUnmodifiedSince  := req.headers.get? FieldName.ifUnmodifiedSince
    ifRange            := req.headers.get? FieldName.ifRange }

/-- Whether a request carries any conditional headers (RFC 9110 Section 13.1). -/
def Request.isConditional (req : Request) : Bool :=
  req.headers.contains FieldName.ifMatch          ||
  req.headers.contains FieldName.ifNoneMatch      ||
  req.headers.contains FieldName.ifModifiedSince  ||
  req.headers.contains FieldName.ifUnmodifiedSince ||
  req.headers.contains FieldName.ifRange

/-- RFC 9110 Section 13.2.2: Evaluate If-Match against current ETag.
    Returns false (precondition fails) when `*` is sent and resource
    doesn't exist, or the ETags don't strongly match. -/
def evalIfMatch (ifMatchValue : String) (currentETag : Option ETag) : Bool :=
  if ifMatchValue.trim == "*" then
    currentETag.isSome
  else
    match currentETag with
    | none => false
    | some etag =>
      -- Split comma-separated list and check for strong match
      let tags := ifMatchValue.splitOn ","
      tags.any fun t =>
        let tv := t.trim.replace "\"" ""
        ETag.strongEq { value := tv, weak := false } etag

/-- RFC 9110 Section 13.2.3: Evaluate If-None-Match against current ETag.
    Returns false (condition fails) when the ETags weakly match. -/
def evalIfNoneMatch (ifNoneMatchValue : String) (currentETag : Option ETag) : Bool :=
  if ifNoneMatchValue.trim == "*" then
    currentETag.isNone
  else
    match currentETag with
    | none => true
    | some etag =>
      let tags := ifNoneMatchValue.splitOn ","
      !tags.any fun t =>
        let tv := t.trim.replace "\"" ""
        ETag.weakEq { value := tv, weak := false } etag

/-- RFC 9110 Section 13.2: Apply preconditions in the correct evaluation order.
    The order is: If-Match -> If-Unmodified-Since -> If-None-Match -> If-Modified-Since.

    Parameters:
    - `cond`: the conditional headers from the request
    - `method`: the request method (affects how If-None-Match is interpreted)
    - `currentETag`: the current ETag of the resource, if any
    - `resourceExists`: whether the target resource exists

    Returns the required action per RFC 9110 Section 13.2.1. -/
def evaluatePreconditions
    (cond        : ConditionalHeaders)
    (method      : Method)
    (currentETag : Option ETag)
    (resourceExists : Bool) : PreconditionResult :=
  -- Step 1: If-Match (Section 13.1.1)
  let step1 : Option PreconditionResult :=
    cond.ifMatch.bind fun v =>
      if !evalIfMatch v currentETag then some .preconditionFailed else none
  -- Step 2: If-Unmodified-Since (Section 13.1.4) -- only evaluated if If-Match absent
  -- (Cannot compare timestamps without a Time type; modelled as always passing here)
  -- Step 3: If-None-Match (Section 13.1.2)
  let step3 : Option PreconditionResult :=
    cond.ifNoneMatch.bind fun v =>
      if !evalIfNoneMatch v currentETag then
        if method.isSafe then some .notModified else some .preconditionFailed
      else none
  -- Step 4: If-Modified-Since (Section 13.1.3) -- only when If-None-Match absent
  -- (Cannot compare timestamps without a Time type; modelled as always passing here)
  step1.getD (step3.getD .proceed)

-- Theorems

/-- If there are no conditional headers, evaluation always proceeds. -/
theorem evaluatePreconditions_no_conditionals (method : Method) (etag : Option ETag) (exists_ : Bool) :
    evaluatePreconditions {} method etag exists_ = .proceed := by
  simp [evaluatePreconditions]

/-- A safe method failing If-None-Match yields NotModified, not PreconditionFailed. -/
theorem evalIfNoneMatch_safe_gives_notModified
    (cond : ConditionalHeaders) (m : Method) (etag : Option ETag) (exists_ : Bool)
    (v : String)
    (hSafe : m.isSafe = true)
    (hNoneMatch : cond.ifNoneMatch = some v)
    (hFails : evalIfNoneMatch v etag = false) :
    evaluatePreconditions { cond with ifMatch := none } m etag exists_ = .notModified := by
  simp [evaluatePreconditions, hNoneMatch, hFails, hSafe]

end SWELib.Networking.Http
