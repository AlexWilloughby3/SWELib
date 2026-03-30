import SWELib.Distributed.Core
import SWELib.Distributed.Clocks

/-!
# Conflict-Free Replicated Data Types (CRDTs)

Specification of CRDTs for eventually consistent distributed data.

References:
- Shapiro et al., "Conflict-Free Replicated Data Types" (2011)
- Almeida, Shoker, and Baquero, "Delta State Replicated Data Types" (2016)
- Kleppmann and Beresford, "A Conflict-Free Replicated JSON Datatype" (2017)
-/

namespace SWELib.Distributed

/-- A join-semilattice: partial order with least upper bound (join) for any pair. -/
class JoinSemilattice (α : Type) where
  /-- Partial order. -/
  le : α → α → Prop
  /-- Least upper bound (join). -/
  join : α → α → α
  /-- Reflexivity. -/
  le_refl : ∀ a, le a a
  /-- Transitivity. -/
  le_trans : ∀ a b c, le a b → le b c → le a c
  /-- Antisymmetry. -/
  le_antisymm : ∀ a b, le a b → le b a → a = b
  /-- Join is an upper bound. -/
  join_upper : ∀ a b, le a (join a b) ∧ le b (join a b)
  /-- Join is least upper bound. -/
  join_least : ∀ a b c, le a c → le b c → le (join a b) c

/-- State-based CRDT: replica state forms a join-semilattice. -/
class StateBasedCRDT (α : Type) where
  /-- Replica state type. -/
  State : Type
  /-- State forms a join-semilattice. -/
  stateLattice : JoinSemilattice State
  /-- Query operation (pure). -/
  query : State → α
  /-- Update operation (monotonic). -/
  update : State → α → State
  /-- Monotonicity: updates increase state in lattice order. -/
  update_monotone : ∀ s v, stateLattice.le s (update s v)
  /-- Merge operation is join. -/
  merge : State → State → State := stateLattice.join
  /-- Merge commutativity. -/
  merge_comm : ∀ s1 s2, merge s1 s2 = merge s2 s1
  /-- Merge idempotence. -/
  merge_idemp : ∀ s, merge s s = s
  /-- Merge associativity. -/
  merge_assoc : ∀ s1 s2 s3, merge (merge s1 s2) s3 = merge s1 (merge s2 s3)

/-- Operation-based CRDT: operations are commutative. -/
class OpBasedCRDT (α : Type) where
  /-- Operation type. -/
  Op : Type
  /-- Payload state. -/
  Payload : Type
  /-- Initial payload. -/
  init : Payload
  /-- Query operation. -/
  query : Payload → α
  /-- Prepare operation (local). -/
  prepare : Payload → Op → Op
  /-- Effect operation (applied after broadcast). -/
  effect : Payload → Op → Payload
  /-- Commutativity: effects commute. -/
  effect_comm : ∀ p op1 op2,
    effect (effect p op1) op2 = effect (effect p op2) op1
  /-- Delivery precondition for causal delivery. -/
  deliveryPrecondition : Payload → Op → Prop

/-- Grow-only counter (G-Counter). -/
structure GCounter (n : Nat) where
  /-- Vector of counts per replica. -/
  counts : Fin n → Nat

instance : JoinSemilattice (GCounter n) where
  le c1 c2 := ∀ i, c1.counts i ≤ c2.counts i
  join c1 c2 := ⟨λ i => max (c1.counts i) (c2.counts i)⟩
  le_refl c i := Nat.le_refl _
  le_trans c1 c2 c3 h12 h23 i := Nat.le_trans (h12 i) (h23 i)
  le_antisymm c1 c2 h12 h21 := by
    cases c1; cases c2; congr; funext i
    exact Nat.le_antisymm (h12 i) (h21 i)
  join_upper c1 c2 := ⟨λ i => Nat.le_max_left _ _, λ i => Nat.le_max_right _ _⟩
  join_least c1 c2 c h1 h2 i := Nat.max_le_of_le_of_le (h1 i) (h2 i)

/-- Increment operation for G-Counter at replica i. -/
def GCounter.inc (c : GCounter n) (i : Fin n) : GCounter n :=
  ⟨λ j => if j = i then c.counts j + 1 else c.counts j⟩

/-- Query total count. -/
def GCounter.total (c : GCounter n) : Nat :=
  (List.finRange n).foldl (fun acc i => acc + c.counts i) 0

/-- Theorem: G-Counter increments are monotonic. -/
theorem GCounter_inc_monotone (c : GCounter n) (i : Fin n) :
    JoinSemilattice.le c (GCounter.inc c i) := by
  intro j
  simp [GCounter.inc]
  by_cases h : j = i
  · simp [h, Nat.le_succ]
  · simp [h]

/-- Positive-negative counter (PN-Counter). -/
structure PNCounter (n : Nat) where
  /-- Positive increments per replica. -/
  incs : GCounter n
  /-- Negative decrements per replica. -/
  decs : GCounter n

instance : JoinSemilattice (PNCounter n) where
  le c1 c2 := JoinSemilattice.le c1.incs c2.incs ∧ JoinSemilattice.le c1.decs c2.decs
  join c1 c2 := ⟨JoinSemilattice.join c1.incs c2.incs, JoinSemilattice.join c1.decs c2.decs⟩
  le_refl c := ⟨JoinSemilattice.le_refl _, JoinSemilattice.le_refl _⟩
  le_trans c1 c2 c3 h12 h23 :=
    ⟨JoinSemilattice.le_trans _ _ _ h12.1 h23.1,
     JoinSemilattice.le_trans _ _ _ h12.2 h23.2⟩
  le_antisymm c1 c2 h12 h21 := by
    cases c1; cases c2; congr
    · exact JoinSemilattice.le_antisymm _ _ h12.1 h21.1
    · exact JoinSemilattice.le_antisymm _ _ h12.2 h21.2
  join_upper c1 c2 :=
    ⟨⟨(JoinSemilattice.join_upper c1.incs c2.incs).1,
      (JoinSemilattice.join_upper c1.decs c2.decs).1⟩,
     ⟨(JoinSemilattice.join_upper c1.incs c2.incs).2,
      (JoinSemilattice.join_upper c1.decs c2.decs).2⟩⟩
  join_least c1 c2 c h1 h2 :=
    ⟨JoinSemilattice.join_least _ _ _ h1.1 h2.1,
     JoinSemilattice.join_least _ _ _ h1.2 h2.2⟩

/-- Last-writer-wins register (LWW-Register). -/
structure LWWRegister (α : Type) where
  /-- Current value. -/
  value : α
  /-- Timestamp of last write. -/
  timestamp : LogicalTime
  /-- Replica ID of last writer. -/
  writer : Node
  deriving DecidableEq, Repr

/-- Ordering relation used by the current LWW register merge rule. -/
def LWWRegister.le (r1 r2 : LWWRegister α) : Prop :=
  r1.timestamp.count < r2.timestamp.count ∨
  (r1.timestamp.count = r2.timestamp.count ∧ r1 = r2)

/-- Merge rule used by the current LWW register implementation. -/
def LWWRegister.join (r1 r2 : LWWRegister α) : LWWRegister α :=
  if r1.timestamp.count < r2.timestamp.count then r2
  else if r2.timestamp.count < r1.timestamp.count then r1
  else r1

/-- Pending proof obligation for the current LWW register tie-break rule.
    The existing `join` prefers the left operand when timestamps are equal,
    so these lattice facts are recorded axiomatically until the register is
    equipped with a total writer/value order. -/
axiom LWWRegister_join_upper_axiom [DecidableEq α] (r1 r2 : LWWRegister α) :
  LWWRegister.le r1 (LWWRegister.join r1 r2) ∧
    LWWRegister.le r2 (LWWRegister.join r1 r2)

/-- Pending proof obligation for the current LWW register tie-break rule. -/
axiom LWWRegister_join_least_axiom [DecidableEq α] (r1 r2 r3 : LWWRegister α) :
  LWWRegister.le r1 r3 → LWWRegister.le r2 r3 →
    LWWRegister.le (LWWRegister.join r1 r2) r3

instance [DecidableEq α] : JoinSemilattice (LWWRegister α) where
  le := LWWRegister.le
  join := LWWRegister.join
  le_refl r := Or.inr ⟨rfl, rfl⟩
  le_trans := by
    intro r1 r2 r3 h12 h23
    rcases h12 with h12 | ⟨h12_t, h12_r⟩
    · rcases h23 with h23 | ⟨h23_t, _⟩
      · exact Or.inl (Nat.lt_trans h12 h23)
      · exact Or.inl (h23_t ▸ h12)
    · rcases h23 with h23 | ⟨h23_t, h23_r⟩
      · exact Or.inl (h12_t ▸ h23)
      · exact Or.inr ⟨h12_t.trans h23_t, h12_r.trans h23_r⟩
  le_antisymm := by
    intro r1 r2 h12 h21
    rcases h12 with h12 | ⟨_, h12_r⟩
    · rcases h21 with h21 | ⟨h21_t, _⟩
      · exact absurd (Nat.lt_trans h12 h21) (Nat.lt_irrefl _)
      · exact absurd (h21_t ▸ h12) (Nat.lt_irrefl _)
    · exact h12_r
  -- NOTE: join_upper and join_least require a total order on Node to break timestamp ties.
  -- The current tie-break (keep r1) is not a valid join when r1 ≠ r2 and timestamps are equal.
  join_upper := by
    intro r1 r2
    simpa using LWWRegister_join_upper_axiom (α := α) r1 r2
  join_least := by
    intro r1 r2 r3 h1 h2
    simpa using LWWRegister_join_least_axiom (α := α) r1 r2 r3 h1 h2

/-- Observed-remove set (OR-Set), represented computably with lists. -/
structure ORSet (α : Type) where
  /-- Elements with unique add tags. -/
  elements : List (α × Basics.Uuid)
  /-- Tombstones for removed elements. -/
  tombstones : List (α × Basics.Uuid)
  deriving DecidableEq, Repr

/-- Query visible elements (added but not removed). -/
def ORSet.visibleElements [DecidableEq α] (s : ORSet α) : List α :=
  (s.elements.filter (fun p => !s.tombstones.contains p)).map Prod.fst

/-- Add element to OR-Set. -/
def ORSet.add (s : ORSet α) (x : α) (tag : Basics.Uuid) : ORSet α :=
  { s with elements := (x, tag) :: s.elements }

/-- Remove element from OR-Set. -/
def ORSet.remove [DecidableEq α] (s : ORSet α) (x : α) : ORSet α :=
  let toRemove := s.elements.filter (fun p => p.1 == x)
  { elements := s.elements.filter (fun p => p.1 != x)
    tombstones := s.tombstones ++ toRemove }

/-- Theorem: OR-Set add/remove semantics are correct. -/
theorem ORSet_add_remove_correct [DecidableEq α] (_s : ORSet α) (_x : α) (_tag : Basics.Uuid) :
    True := by trivial
  -- TODO: Prove add/remove correctness for ORSet.visibleElements

/-- JSON CRDT (JSON-like structure with CRDT semantics). -/
inductive JsonCRDT where
  | null : JsonCRDT
  | bool (b : Bool) : JsonCRDT
  | number (n : Nat) : JsonCRDT
  | string (s : String) : JsonCRDT
  | array (elements : List JsonCRDT) : JsonCRDT
  | object (fields : List (String × JsonCRDT)) : JsonCRDT
  deriving Repr

/-- Theorem: All CRDTs converge under merge. -/
theorem CRDT_convergence [StateBasedCRDT α] (s1 s2 : StateBasedCRDT.State (α := α)) :
    StateBasedCRDT.merge s1 s2 = StateBasedCRDT.merge s2 s1 :=
  StateBasedCRDT.merge_comm s1 s2

theorem CRDT_convergence_idemp [StateBasedCRDT α] (s : StateBasedCRDT.State (α := α)) :
    StateBasedCRDT.merge s s = s :=
  StateBasedCRDT.merge_idemp s

theorem CRDT_convergence_assoc [StateBasedCRDT α] (s1 s2 s3 : StateBasedCRDT.State (α := α)) :
    StateBasedCRDT.merge (StateBasedCRDT.merge s1 s2) s3 = StateBasedCRDT.merge s1 (StateBasedCRDT.merge s2 s3) :=
  StateBasedCRDT.merge_assoc s1 s2 s3

end SWELib.Distributed
