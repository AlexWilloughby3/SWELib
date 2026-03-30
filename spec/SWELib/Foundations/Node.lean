import SWELib.Foundations.LTS

/-!
# Node

A Node is an isolated execution environment modeled as a Labeled Transition System.
Actions are classified as Input (environment-controlled), Output (Node-controlled),
or Internal (invisible τ steps), following Lynch's I/O Automata.

The same LTS framework works at any granularity — a Node can be a container, VM,
bare-metal machine, phone, or even a CPU. What changes across levels is the Network
(sketch 05), not the Node definition.

References:
- Lynch, "Distributed Algorithms" (1996) — I/O Automata
- Milner, "Communication and Concurrency" (1989) — CCS
- Aceto et al., "Reactive Systems" (2007)
-/

namespace SWELib.Foundations

/-- Classification of actions following I/O Automata (Lynch).
    - `input`: environment-controlled, cannot be refused (e.g., receiving a TCP SYN)
    - `output`: Node-controlled (e.g., sending a response)
    - `internal`: invisible to other Nodes (τ steps) -/
inductive ActionKind where
  | input
  | output
  | internal
  deriving DecidableEq, Repr

/-- A Node action wraps a raw action `α` with its I/O classification. -/
structure NodeAction (α : Type) where
  action : α
  kind : ActionKind
  deriving DecidableEq, Repr

/-- A Node is an LTS whose labels are classified NodeActions.
    Parameterized by:
    - `α`: the raw action alphabet (domain-specific: SQL queries, HTTP requests, etc.)
    - `S`: the state space -/
structure Node (α : Type) (S : Type) where
  /-- The underlying labeled transition system. -/
  lts : LTS S (NodeAction α)
  /-- The set of input actions this Node accepts (as a predicate). -/
  inputs : NodeAction α → Prop
  /-- The set of output actions this Node can produce. -/
  outputs : NodeAction α → Prop
  /-- Input actions cannot be refused: if an input action is in the alphabet,
      it must be enabled in every reachable state. -/
  input_enabled : ∀ s a, LTS.Reachable lts s → inputs a → a.kind = .input →
    LTS.Enabled lts s a

-- ═══════════════════════════════════════════════════════════
-- Health States
-- ═══════════════════════════════════════════════════════════

/-- Health state of a Node. Transitions form their own sub-LTS. -/
inductive HealthState where
  | healthy
  | degraded
  | draining
  | stopped
  deriving DecidableEq, Repr

/-- Health state transitions during shutdown are monotonic. -/
inductive HealthTransition : HealthState → HealthState → Prop where
  | toDegraded : HealthTransition .healthy .degraded
  | toDraining : HealthTransition .healthy .draining
  | degradedToDraining : HealthTransition .degraded .draining
  | toStopped : HealthTransition .draining .stopped

/-- Health transitions are irreversible: you cannot go backwards. -/
def HealthState.le : HealthState → HealthState → Prop
  | .healthy, _ => True
  | .degraded, .degraded | .degraded, .draining | .degraded, .stopped => True
  | .draining, .draining | .draining, .stopped => True
  | .stopped, .stopped => True
  | _, _ => False

-- ═══════════════════════════════════════════════════════════
-- Failure Predicates (proved about the LTS, not declared enums)
-- ═══════════════════════════════════════════════════════════

/-- A distinguished crash action in the Node's alphabet. -/
class HasCrash (α : Type) where
  crash : α

/-- A distinguished recover action. -/
class HasRecover (α : Type) where
  recover : α

/-- A Node is crash-stop if it has a crash transition to a terminal state
    from every reachable state. After crashing, no further transitions are possible. -/
def Node.isCrashStop [HasCrash α] (n : Node α S) : Prop :=
  ∃ s_crashed : S,
    (∀ s, LTS.Reachable n.lts s →
      n.lts.Tr s ⟨HasCrash.crash, .internal⟩ s_crashed) ∧
    (∀ a s', ¬ n.lts.Tr s_crashed a s')

/-- A Node is crash-recovery if it can crash and then recover to the initial state. -/
def Node.isCrashRecovery [HasCrash α] [HasRecover α] (n : Node α S) : Prop :=
  ∃ s_crashed : S,
    (∀ s, LTS.Reachable n.lts s →
      n.lts.Tr s ⟨HasCrash.crash, .internal⟩ s_crashed) ∧
    n.lts.Tr s_crashed ⟨HasRecover.recover, .internal⟩ n.lts.initial

/-- A Node is Byzantine if after a fault, any transition is possible
    (unconstrained behavior). -/
def Node.isByzantine (n : Node α S) : Prop :=
  ∃ s_fault : S, ∀ a s', n.lts.Tr s_fault a s'

-- ═══════════════════════════════════════════════════════════
-- Roles
-- ═══════════════════════════════════════════════════════════

/-- Structural role: what a Node *is*, based on its interface shape. -/
inductive StructuralRole where
  /-- Has listeners, no outbound dependencies (pure server). -/
  | server
  /-- No listeners, has dependencies (pure client). -/
  | client
  /-- Has both listeners and dependencies (typical service). -/
  | service
  /-- Neither listeners nor dependencies (isolated worker). -/
  | worker
  deriving DecidableEq, Repr

/-- Functional role: what a Node *does* in the system.
    This is an open type — users extend it for their domain. -/
inductive FunctionalRole where
  | database
  | apiServer
  | loadBalancer
  | cache
  | messageQueue
  | worker
  | mobileClient
  | custom (name : String)
  deriving DecidableEq, Repr

/-- Combined role of a Node. -/
structure NodeRole where
  structural : StructuralRole
  functional : FunctionalRole
  deriving DecidableEq, Repr

-- ═══════════════════════════════════════════════════════════
-- Shutdown
-- ═══════════════════════════════════════════════════════════

/-- A shutdown action: the sequence of steps a Node takes to stop. -/
inductive ShutdownStep where
  | stopAccepting
  | drainInFlight
  | closeConnections
  | forceKill
  deriving DecidableEq, Repr

/-- Shutdown policy: an ordered sequence of shutdown steps. -/
structure ShutdownPolicy where
  steps : List ShutdownStep
  deriving DecidableEq, Repr

-- ═══════════════════════════════════════════════════════════
-- Resource Limits
-- ═══════════════════════════════════════════════════════════

/-- Resource limits constraining the Node's state space. -/
structure ResourceLimits where
  maxConnections : Option Nat
  maxMemoryBytes : Option Nat
  maxFileDescriptors : Option Nat
  deriving DecidableEq, Repr

-- ═══════════════════════════════════════════════════════════
-- Node Refinement (Zoom)
-- ═══════════════════════════════════════════════════════════

/-- A Node refinement proves that internal structure (a composition of sub-processes)
    is observationally equivalent to the abstract Node interface.
    This is NOT mutual recursion — it's a one-directional, optional mapping. -/
structure NodeRefinement (α : Type) (S_abs S_int : Type) where
  /-- The abstract view: single Node seen by the rest of the System. -/
  node : Node α S_abs
  /-- The internal LTS: what's actually inside (parallel composition of processes). -/
  internal : LTS S_int (NodeAction α)
  /-- Proof that the internals match the interface (weak bisimulation). -/
  equiv : LTS.Bisimilar node.lts internal

-- ═══════════════════════════════════════════════════════════
-- Key Theorems
-- ═══════════════════════════════════════════════════════════

/-- A crash-stop Node in its crashed state produces no output actions. -/
theorem Node.crashStop_no_output [HasCrash α] {n : Node α S}
    (h : n.isCrashStop) : ∃ s_crashed : S, ∀ a s', ¬ n.lts.Tr s_crashed a s' := by
  obtain ⟨s_crashed, _, h_dead⟩ := h
  exact ⟨s_crashed, h_dead⟩

/-- Health state ordering is reflexive. -/
theorem HealthState.le_refl (h : HealthState) : HealthState.le h h := by
  cases h <;> simp [HealthState.le]

/-- Health state ordering is transitive. -/
theorem HealthState.le_trans (a b c : HealthState)
    (hab : HealthState.le a b) (hbc : HealthState.le b c) : HealthState.le a c := by
  cases a <;> cases b <;> cases c <;> simp_all [HealthState.le]

end SWELib.Foundations
