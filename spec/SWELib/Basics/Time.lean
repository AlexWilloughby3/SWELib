/-!
# Time

Specification of time-related types for SWELib.
NumericDate (RFC 7519 Section 2): seconds since Unix epoch.
-/

namespace SWELib.Basics

/-- NumericDate (RFC 7519 Section 2).
    Represents seconds since 1970-01-01T00:00:00Z UTC, ignoring leap seconds.
    The value is a non-negative integer (Nat), matching the RFC 7519 definition exactly. -/
structure NumericDate where
  /-- Seconds since Unix epoch -/
  seconds : Nat
  deriving DecidableEq, Repr, Inhabited

/-- Create a NumericDate from a non-negative integer seconds count. -/
def NumericDate.ofSeconds (seconds : Nat) : NumericDate :=
  ⟨seconds⟩

/-- Convert NumericDate to seconds since Unix epoch. -/
def NumericDate.toSeconds (nd : NumericDate) : Nat :=
  nd.seconds

/-- Add seconds to a NumericDate. -/
def NumericDate.addSeconds (nd : NumericDate) (seconds : Nat) : NumericDate :=
  ⟨nd.seconds + seconds⟩

/-- Subtract seconds from a NumericDate (saturates at 0 per Nat subtraction). -/
def NumericDate.subSeconds (nd : NumericDate) (seconds : Nat) : NumericDate :=
  ⟨nd.seconds - seconds⟩

/-- Compare two NumericDates for less-than. -/
def NumericDate.lt (a b : NumericDate) : Prop := a.seconds < b.seconds

/-- Compare two NumericDates for less-than-or-equal. -/
def NumericDate.le (a b : NumericDate) : Prop := a.seconds ≤ b.seconds

instance : LT NumericDate where lt := NumericDate.lt
instance : LE NumericDate where le := NumericDate.le

instance : DecidableRel (α := NumericDate) (· < ·) :=
  fun a b => inferInstanceAs (Decidable (a.seconds < b.seconds))

instance : DecidableRel (α := NumericDate) (· ≤ ·) :=
  fun a b => inferInstanceAs (Decidable (a.seconds ≤ b.seconds))

/-- Roundtrip: `ofSeconds` and `toSeconds` are inverse. -/
theorem NumericDate.ofSeconds_toSeconds (nd : NumericDate) :
    NumericDate.ofSeconds nd.toSeconds = nd := by
  cases nd; simp [NumericDate.ofSeconds, NumericDate.toSeconds]

/-- `addSeconds` then `subSeconds` by the same amount returns the original. -/
theorem NumericDate.add_sub_cancel (nd : NumericDate) (n : Nat) :
    (nd.addSeconds n).subSeconds n = nd := by
  simp [NumericDate.addSeconds, NumericDate.subSeconds, Nat.add_sub_cancel]

end SWELib.Basics
