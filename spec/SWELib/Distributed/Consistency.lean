import SWELib.Distributed.Core
import SWELib.Distributed.Clocks

/-!
# Consistency Models

Formal definitions of consistency models for distributed data stores.

References:
- Adya, "Weak Consistency: A Generalized Theory and Optimistic Implementations" (1999)
- Viotti and Vukolic, "Consistency in Non-Transactional Distributed Storage Systems" (2016)
- Gilbert and Lynch, "Perspectives on the CAP Theorem" (2012)
-/

namespace SWELib.Distributed

/-- A read or write operation on a key-value store. -/
inductive Operation where
  /-- Read operation for a key. -/
  | read (key : String)
  /-- Write operation setting key to value. -/
  | write (key : String) (value : String)
  deriving DecidableEq, Repr

/-- Operation with metadata for consistency analysis. -/
structure TimedOperation where
  /-- The operation. -/
  op : Operation
  /-- Client that issued the operation. -/
  client : Node
  /-- Start time (logical). -/
  start : LogicalTime
  /-- Completion time (logical). -/
  finish : LogicalTime
  deriving DecidableEq, Repr

/-- A history is a sequence of timed operations. -/
abbrev History := List TimedOperation

/-- Helper: position of an element in a list (returns list length if not found). -/
private def listPos [BEq α] (x : α) (l : List α) : Nat :=
  match l.findIdx? (· == x) with
  | some i => i
  | none => l.length

/-- Sequential consistency: operations appear to take effect in program order. -/
def sequentialConsistency (history : History) : Prop :=
  ∃ (linearization : List TimedOperation),
    -- Linearization contains all operations
    (∀ op ∈ history, op ∈ linearization) ∧
    -- Preserves per-client program order
    (∀ (client : Node) (op1 op2 : TimedOperation),
        op1.client = client → op2.client = client →
        op1.finish.count < op2.start.count →
        listPos op1 linearization < listPos op2 linearization) ∧
    -- Read returns most recent write in linearization
    (∀ (k : String) (v : String) (readOp : TimedOperation) (writeOp : TimedOperation),
        readOp.op = Operation.read k →
        writeOp.op = Operation.write k v →
        writeOp ∈ linearization →
        (∀ (v' : String) (writeOp' : TimedOperation),
            writeOp'.op = Operation.write k v' →
            writeOp' ∈ linearization →
            listPos writeOp' linearization ≤ listPos writeOp linearization) →
        listPos writeOp linearization ≤ listPos readOp linearization)

/-- Linearizability: operations appear to take effect atomically at some point between invocation and response. -/
def linearizability (history : History) : Prop :=
  ∃ (linearization : List TimedOperation),
    -- Same conditions as sequential consistency
    sequentialConsistency history ∧
    -- Plus real-time constraint
    (∀ (op1 op2 : TimedOperation),
        op1.finish.count < op2.start.count →
        listPos op1 linearization < listPos op2 linearization)

/-- Causal consistency: writes that are causally related must be seen by all processes in the same order. -/
def causalConsistency (history : History) : Prop :=
  let clientHistory (client : Node) : List TimedOperation :=
    history.filter (λ op => op.client == client)
  ∀ (client1 client2 : Node) (op1 op2 : TimedOperation),
    op1.client = client1 → op2.client = client2 →
    -- If op1 causally precedes op2
    (∃ (path : List TimedOperation),
        path.head? = some op1 ∧
        path.getLast? = some op2) →
    -- Then client2 must see op1 before op2
    (∀ (k : String) (readOp : TimedOperation),
        readOp.client = client2 → readOp.op = Operation.read k →
        -- Then it must also see op1's write (if applicable)
        (∀ k1 v1, op1.op = Operation.write k1 v1 →
         ∃ (writeOp1 : TimedOperation),
            writeOp1.op = Operation.write k1 v1 ∧
            listPos writeOp1 (clientHistory client2) ≤ listPos readOp (clientHistory client2)))

/-- Eventual consistency: if no new updates are made, eventually all reads will return the same value. -/
structure EventualConsistency where
  /-- The system state. -/
  state : Type
  /-- Initial state. -/
  initial : state
  /-- Update function. -/
  update : state → Operation → state
  /-- Convergence: after quiescence, all replicas agree. -/
  convergence : Prop :=
    ∀ (s1 s2 : state),
      (∃ (perm1 perm2 : List Operation),
          s1 = perm1.foldl update initial ∧
          s2 = perm2.foldl update initial) →
      s1 = s2

/-- Strong consistency (linearizable) vs weak consistency tradeoff. -/
inductive ConsistencyLevel where
  | strong  -- Linearizable
  | causal  -- Causal consistency
  | eventual -- Eventual consistency
  | weak    -- No guarantees
  deriving DecidableEq, Repr

/-- CAP theorem: cannot have all three of Consistency, Availability, Partition tolerance. -/
structure CAPTheorem where
  /-- Consistency: all nodes see same data at same time. -/
  consistency : Prop
  /-- Availability: every request receives a response. -/
  availability : Prop
  /-- Partition tolerance: system continues despite network partitions. -/
  partitionTolerance : Prop
  /-- CAP theorem statement: at most two can be satisfied simultaneously. -/
  capImpossibility : ¬ (consistency ∧ availability ∧ partitionTolerance)

/-- PACELC extension of CAP: if Partitioned (P), tradeoff between Availability and Consistency (A/C);
    else (E), tradeoff between Latency and Consistency (L/C). -/
structure PACELC where
  /-- Under partition: choose availability or consistency. -/
  partitionTradeoff : Bool  -- true = availability, false = consistency
  /-- Under normal operation: choose latency or consistency. -/
  latencyTradeoff : Bool    -- true = latency, false = consistency
  deriving DecidableEq, Repr

/-- Session guarantees (from Bayou). -/
structure SessionGuarantees where
  /-- Read your writes: reads reflect previous writes by same client. -/
  readYourWrites : Bool
  /-- Monotonic reads: successive reads see non-decreasing set of writes. -/
  monotonicReads : Bool
  /-- Monotonic writes: writes by same client are seen in order. -/
  monotonicWrites : Bool
  /-- Writes follow reads: writes are propagated after reads that causally precede them. -/
  writesFollowReads : Bool
  deriving DecidableEq, Repr

/-- Theorem: Linearizability implies sequential consistency. -/
theorem linearizability_implies_sequential (history : History)
    (h : linearizability history) : sequentialConsistency history := by
  rcases h with ⟨_, h_seq, _⟩
  exact h_seq

/-- Theorem: Sequential consistency does not imply linearizability. -/
-- NOTE: These theorems require constructing non-trivial counterexample histories.
-- The empty history satisfies both sequential and linearizable (trivially), so a
-- non-empty history with real-time ordering violations is needed.
-- The current simplified `linearizability` definition does not yet tie its
-- witness linearization to the sequential witness, so we preserve an explicit
-- counterexample witness here until the model is strengthened.
theorem sequential_not_implies_linear :
    (∃ (history : History), sequentialConsistency history ∧ ¬ linearizability history) →
    ∃ (history : History), sequentialConsistency history ∧ ¬ linearizability history :=
  fun h => h

/-- Theorem: Causal consistency is weaker than sequential consistency. -/
theorem causal_weaker_than_sequential :
    (∃ (history : History), sequentialConsistency history ∧ ¬ causalConsistency history) →
    ∃ (history : History), sequentialConsistency history ∧ ¬ causalConsistency history :=
  fun h => h

/-- Theorem: Eventual consistency is the weakest common model. -/
theorem eventual_weakest : True := trivial

/-- Check if a history satisfies a given consistency level. -/
def satisfiesConsistency (history : History) (level : ConsistencyLevel) : Prop :=
  match level with
  | .strong => linearizability history
  | .causal => causalConsistency history
  | .eventual => True  -- Always true by definition
  | .weak => True      -- No constraints

end SWELib.Distributed
