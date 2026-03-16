import Std
import Std.Time

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

/-- Convert from `Std.Time.Timestamp`.
    Truncates sub-second precision; pre-epoch timestamps (negative seconds) become 0,
    since RFC 7519 NumericDate is non-negative. -/
def NumericDate.ofTimestamp (ts : Std.Time.Timestamp) : NumericDate :=
  ⟨ts.toSecondsSinceUnixEpoch.val.toNat⟩

/-- Convert to `Std.Time.Timestamp` (whole seconds only, no sub-second precision). -/
def NumericDate.toTimestamp (nd : NumericDate) : Std.Time.Timestamp :=
  .ofSecondsSinceUnixEpoch (.ofNat nd.seconds)

/-- Fetch the current time as a NumericDate via `Std.Time.Timestamp.now`. -/
def NumericDate.now : IO NumericDate := do
  return .ofTimestamp (← Std.Time.Timestamp.now)

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
  cases nd; simp [NumericDate.addSeconds, NumericDate.subSeconds]

/-- `addSeconds` is monotone: a larger offset gives a later timestamp. -/
theorem NumericDate.addSeconds_mono (nd : NumericDate) {m n : Nat} (h : m ≤ n) :
    nd.addSeconds m ≤ nd.addSeconds n := by
  show (nd.addSeconds m).seconds ≤ (nd.addSeconds n).seconds
  simp [NumericDate.addSeconds]; omega

/-- Adding a positive number of seconds strictly advances the timestamp. -/
theorem NumericDate.addSeconds_lt (nd : NumericDate) {n : Nat} (hn : 0 < n) :
    nd < nd.addSeconds n := by
  show nd.seconds < (nd.addSeconds n).seconds
  simp [NumericDate.addSeconds]; omega

/-- `<` is transitive. -/
theorem NumericDate.lt_trans {a b c : NumericDate} (hab : a < b) (hbc : b < c) : a < c :=
  Nat.lt_trans hab hbc

/-- `<` is asymmetric. -/
theorem NumericDate.lt_asymm {a b : NumericDate} (h : a < b) : ¬(b < a) :=
  Nat.lt_asymm h

/-- `toTimestamp`/`ofTimestamp` round-trip for any NumericDate.
    Follows from `Duration.ofSeconds s |>.second = s` and `Int.toNat_ofNat`. -/
theorem NumericDate.ofTimestamp_toTimestamp (nd : NumericDate) :
    NumericDate.ofTimestamp nd.toTimestamp = nd := by
  cases nd with | mk n =>
  simp only [NumericDate.ofTimestamp, NumericDate.toTimestamp,
             Std.Time.Timestamp.toSecondsSinceUnixEpoch,
             Std.Time.Timestamp.ofSecondsSinceUnixEpoch,
             Std.Time.Second.Offset.ofNat]
  simp [Std.Time.Duration.ofSeconds]
  -- Goal reduces to: (Duration.ofSeconds { val := ↑n }).second.val.toNat = n
  -- Duration.ofSeconds s builds { second := s, nano := 0, proof := _ }, so .second = s
  -- s = { val := ↑n }, so .val = (n : Int), and Int.toNat (↑n) = n

end SWELib.Basics
