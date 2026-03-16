import SWELib.Networking.Http.Field
import SWELib.Networking.Http.Message
import SWELib.Networking.Http.StatusCode

/-!
# HTTP Expect Header

RFC 9110 Section 10.1.1: The Expect header field.
The "100-continue" expectation allows clients to check if a server
will accept a large request body before sending it.
-/

namespace SWELib.Networking.Http

/-- Expectation values for the Expect header (RFC 9110 Section 10.1.1). -/
inductive Expectation where
  /-- 100-continue: client wants acknowledgment before sending the body. -/
  | continue100
  /-- An unrecognized expectation. -/
  | other (value : String)
  deriving DecidableEq, Repr

instance : BEq Expectation := ⟨fun a b => decide (a = b)⟩

instance : ToString Expectation where
  toString
    | .continue100  => "100-continue"
    | .other s      => s

/-- Parse the Expect header value (case-insensitive per RFC 9110 Section 10.1.1). -/
def Expectation.parse (v : String) : Expectation :=
  if v.trimAscii.toString.toLower == "100-continue" then .continue100
  else .other v

/-- A request carries 100-continue expectation. -/
def Request.expects100Continue (req : Request) : Bool :=
  match req.headers.get? FieldName.expect with
  | none => false
  | some v => (Expectation.parse v) == .continue100

/-- RFC 9110 Section 10.1.1: A server MUST respond with 417 Expectation
    Failed if it cannot meet an expectation other than 100-continue. -/
def expectationCanBeMet (expectation : Expectation) : Bool :=
  match expectation with
  | .continue100 => true  -- servers should always handle 100-continue
  | .other _     => false -- unknown expectations cannot be met

/-- RFC 9110 Section 10.1.1: The Expect header MUST NOT be sent to HTTP/1.0 recipients.
    HTTP/2+ has major > 1, so only the (major=1, minor=0) case is prohibited. -/
def Request.expectValidForVersion (req : Request) : Prop :=
  req.headers.contains FieldName.expect = true →
    ¬(req.version.major = 1 ∧ req.version.minor = 0)

-- Theorems

/-- Parsing "100-continue" yields the continue100 expectation. -/
theorem parse_100continue :
    Expectation.parse "100-continue" = .continue100 := by
  native_decide

/-- Parsing "100-CONTINUE" (uppercase) also yields continue100 (case-insensitive). -/
theorem parse_100continue_upper :
    Expectation.parse "100-CONTINUE" = .continue100 := by
  native_decide

/-- The 100-continue expectation can always be met. -/
theorem continue100_can_be_met :
    expectationCanBeMet .continue100 = true := by rfl

end SWELib.Networking.Http
