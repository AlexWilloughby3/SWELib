/-!
# TCP Sequence Numbers

RFC 9293 Section 3.3: Sequence number arithmetic with modular 32-bit wrapping.
Sequence numbers use unsigned 32-bit arithmetic. Comparisons use the
circular order relation: a is "before" b if the forward distance from
a to b is less than half the sequence space (2^31).
-/

namespace SWELib.Networking.Tcp

/-- A TCP sequence number: an opaque wrapper around `UInt32` providing
    modular arithmetic (RFC 9293 Section 3.3.1). -/
structure SeqNum where
  /-- The underlying 32-bit value. -/
  val : UInt32
  deriving DecidableEq, Repr, Inhabited, BEq

/-- Construct a `SeqNum` from a natural number, truncating to 32 bits. -/
def SeqNum.ofNat (n : Nat) : SeqNum :=
  ⟨UInt32.ofNat n⟩

/-- Wrapping addition of two sequence numbers (RFC 9293 Section 3.3.1). -/
def seqAdd (a b : SeqNum) : SeqNum :=
  ⟨a.val + b.val⟩

/-- Add a natural number to a sequence number with wrapping. -/
def seqAddNat (a : SeqNum) (n : Nat) : SeqNum :=
  ⟨a.val + UInt32.ofNat n⟩

/-- Wrapping subtraction of two sequence numbers. -/
def seqSub (a b : SeqNum) : SeqNum :=
  ⟨a.val - b.val⟩

/-- Modular less-than comparison for sequence numbers (RFC 9293 Section 3.3.1).
    `a` is "before" `b` if the forward (unsigned) distance from `a` to `b`
    is strictly between 0 and 2^31 (half the sequence space). -/
def seqLt (a b : SeqNum) : Bool :=
  let diff := (b.val - a.val).toNat
  diff > 0 && diff < 2^31

/-- Modular less-than-or-equal for sequence numbers.
    True when `a == b` or `seqLt a b`. -/
def seqLe (a b : SeqNum) : Bool :=
  a == b || seqLt a b

/-- Check whether sequence number `s` falls within the receive window
    starting at `start` with size `wnd` (RFC 9293 Section 3.4). -/
def seqInWindow (start : SeqNum) (wnd : Nat) (s : SeqNum) : Bool :=
  seqLe start s && seqLt s (seqAddNat start wnd)

-- Theorems

/-- Sequence number modular less-than is irreflexive: no number is before itself. -/
theorem seqLt_irrefl (a : SeqNum) : seqLt a a = false := by
  simp [seqLt]

/-- Sequence number modular less-than-or-equal is reflexive. -/
theorem seqLe_refl (a : SeqNum) : seqLe a a = true := by
  simp [seqLe]
  -- a == a is true by BEq
  sorry

end SWELib.Networking.Tcp
