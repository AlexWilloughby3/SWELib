import SWELib.Foundations.Node

/-!
# System

A System is a parallel composition of Nodes communicating over a Network.
In CCS terms: `(Node₁ | Node₂ | ... | Nodeₙ) \ internal_channels`.

The Network is not a separate message-carrying entity — it's a set of
ChannelProcess instances (themselves LTS) interleaved with Node processes.
Network properties (reliability, ordering, latency) emerge from the channel's
LTS, not from declared tags.

Failure behavior lives inside each Node's and Channel's LTS as transitions,
not as a System-level field.

References:
- Milner, "Communication and Concurrency" (1989) — CCS parallel composition
- Lynch, "Distributed Algorithms" (1996) — I/O automata composition
- Alpern & Schneider, "Defining Liveness" (1985) — safety/liveness decomposition
-/

namespace SWELib.Foundations

-- ═══════════════════════════════════════════════════════════
-- Node Identity
-- ═══════════════════════════════════════════════════════════

/-- Unique identifier for a Node within a System. -/
structure NodeId where
  id : Nat
  deriving DecidableEq, Repr, Hashable, Ord, BEq

instance : LawfulBEq NodeId where
  eq_of_beq {a b} h := by
    rcases a with ⟨a⟩; rcases b with ⟨b⟩
    -- The derived BEq compares the id fields
    have : a = b := by
      revert h; unfold BEq.beq instBEqNodeId; simp
      intro h; exact of_decide_eq_true h
    subst this; rfl
  rfl {a} := by
    rcases a with ⟨a⟩
    unfold BEq.beq instBEqNodeId; simp
    exact decide_eq_true rfl

-- ═══════════════════════════════════════════════════════════
-- Channel (Network edge as LTS)
-- ═══════════════════════════════════════════════════════════

/-- A channel action: what a communication link can do. -/
inductive ChannelAction (α : Type) where
  /-- Accept a message for delivery. -/
  | enqueue (msg : α)
  /-- Deliver a message to the receiver. -/
  | deliver (msg : α)
  /-- Drop a message (lossy channel). -/
  | drop (msg : α)
  /-- Reorder: deliver a different message than the oldest (non-FIFO). -/
  | reorder
  /-- Link goes down (partition). -/
  | partition
  /-- Link comes back up (heal). -/
  | heal
  deriving DecidableEq, Repr

/-- A channel process mediating communication between two Nodes.
    Network properties emerge from the channel's LTS — they're theorems,
    not declared tags. -/
structure Channel (α : Type) (S : Type) where
  lts : LTS S (ChannelAction α)
  src : NodeId
  dst : NodeId

/-- A channel is reliable if it never drops messages. -/
def Channel.isReliable {α S : Type} (ch : Channel α S) : Prop :=
  ∀ s msg s', ¬ ch.lts.Tr s (.drop msg) s'

/-- A channel is FIFO if messages are delivered in enqueue order.
    If m₁ is enqueued before m₂, then m₁ must be delivered before m₂. -/
def Channel.isFIFO {α S : Type} (ch : Channel α S) : Prop :=
  ∀ s m₁ m₂ s₁ s₂,
    ch.lts.Tr s (.enqueue m₁) s₁ →
    ch.lts.Tr s₁ (.enqueue m₂) s₂ →
    ∀ s₃, ch.lts.Tr s₂ (.deliver m₂) s₃ →
      ∃ s_mid, LTS.FiniteTrace ch.lts s₂ s_mid ∧
        ∃ s₄, ch.lts.Tr s_mid (.deliver m₁) s₄

/-- A channel is lossy if it has drop transitions. -/
def Channel.isLossy {α S : Type} (ch : Channel α S) : Prop :=
  ∃ s msg s', ch.lts.Tr s (.drop msg) s'

/-- A channel is non-duplicating if it delivers each message at most once
    per enqueue. Stated as: from any reachable state, delivering a message
    requires it to have been enqueued and not yet delivered. -/
def Channel.isNonDuplicating {α S : Type} (ch : Channel α S) : Prop :=
  ∀ s msg s₁ s₂,
    ch.lts.Tr s (.deliver msg) s₁ →
    ch.lts.Tr s₁ (.deliver msg) s₂ →
    ∃ s_mid, LTS.FiniteTrace ch.lts s₁ s_mid ∧
      ∃ s_enq, ch.lts.Tr s_mid (.enqueue msg) s_enq

/-- A channel can partition if it has partition transitions. -/
def Channel.canPartition {α S : Type} (ch : Channel α S) : Prop :=
  ∃ s s', ch.lts.Tr s .partition s'

-- ═══════════════════════════════════════════════════════════
-- Network
-- ═══════════════════════════════════════════════════════════

/-- A Network is the set of channels between Nodes.
    Not a separate message-carrying entity — it dissolves into CCS
    as channel processes interleaved with Node processes. -/
structure Network (α : Type) where
  /-- Channel between two Nodes, if one exists.
      Uses an existential for the channel state type. -/
  channels : NodeId → NodeId → Option (Σ S : Type, Channel α S)

/-- Two Nodes are connected if a channel exists between them. -/
def Network.connected {α : Type} (net : Network α) (src dst : NodeId) : Prop :=
  (net.channels src dst).isSome

/-- The network is symmetric (bidirectional links). -/
def Network.symmetric {α : Type} (net : Network α) : Prop :=
  ∀ src dst, net.connected src dst → net.connected dst src

/-- All channels are reliable (no drops). -/
def Network.allReliable {α : Type} (net : Network α) : Prop :=
  ∀ src dst ch, net.channels src dst = some ch → ch.2.isReliable

/-- All channels are FIFO (ordered delivery). -/
def Network.allFIFO {α : Type} (net : Network α) : Prop :=
  ∀ src dst ch, net.channels src dst = some ch → ch.2.isFIFO

/-- No channel can partition. -/
def Network.partitionFree {α : Type} (net : Network α) : Prop :=
  ∀ src dst ch, net.channels src dst = some ch → ¬ ch.2.canPartition

/-- The network is fully connected: every pair of distinct Nodes has a channel. -/
def Network.fullyConnected {α : Type} (net : Network α) (nodes : List NodeId) : Prop :=
  ∀ n₁ n₂, n₁ ∈ nodes → n₂ ∈ nodes → n₁ ≠ n₂ → net.connected n₁ n₂

-- ═══════════════════════════════════════════════════════════
-- System
-- ═══════════════════════════════════════════════════════════

/-- An identified Node: a Node paired with its identity and role. -/
structure IdentifiedNode (α : Type) where
  nid : NodeId
  /-- Existential over state type — each Node can have a different state space. -/
  node : Σ S : Type, Node α S
  role : NodeRole

/-- A DistSystem: parallel composition of identified Nodes over a Network.
    Named DistSystem to avoid collision with Lean's `System` namespace.
    The CCS term and System-level LTS are derived, not stored. -/
structure DistSystem (α : Type) where
  /-- The participant Nodes. -/
  nodes : List (IdentifiedNode α)
  /-- The communication network. -/
  network : Network α
  /-- Node IDs are unique. -/
  ids_unique : ∀ a b, a ∈ nodes → b ∈ nodes → a.nid = b.nid → a = b

/-- Look up a Node by its ID. -/
def DistSystem.findNode {α : Type} (sys : DistSystem α) (nid : NodeId) :
    Option (IdentifiedNode α) :=
  sys.nodes.find? (fun n => n.nid == nid)

/-- The set of Node IDs in the system. -/
def DistSystem.nodeIds {α : Type} (sys : DistSystem α) : List NodeId :=
  sys.nodes.map (·.nid)

/-- Number of Nodes. -/
def DistSystem.size {α : Type} (sys : DistSystem α) : Nat :=
  sys.nodes.length

-- ═══════════════════════════════════════════════════════════
-- System-level Actions (derived from composition)
-- ═══════════════════════════════════════════════════════════

/-- A system-level action: either a Node takes a step independently,
    or two Nodes synchronize via a channel. -/
inductive SystemAction (α : Type) where
  /-- A single Node takes an independent step. -/
  | nodeStep (nid : NodeId) (action : NodeAction α)
  /-- Two Nodes synchronize: one outputs, the other inputs, via a channel. -/
  | sync (src dst : NodeId) (action : α)
  /-- A channel takes an internal step (e.g., dropping, reordering). -/
  | channelStep (src dst : NodeId) (action : ChannelAction α)
  deriving DecidableEq, Repr

-- ═══════════════════════════════════════════════════════════
-- Traces and Properties
-- ═══════════════════════════════════════════════════════════

/-- A finite system trace: a list of system actions. -/
abbrev SystemFiniteTrace (α : Type) := List (SystemAction α)

/-- An infinite system trace: a stream of system actions. -/
abbrev SystemInfiniteTrace (α : Type) := Nat → SystemAction α

/-- A safety property: no finite prefix violates it.
    "Nothing bad happens." -/
def SafetyProperty (α : Type) := SystemFiniteTrace α → Prop

/-- A liveness property: parameterized by a fairness assumption.
    "Something good eventually happens (under fair scheduling)." -/
def LivenessProperty (α : Type) := SystemInfiniteTrace α → Prop

/-- A general system property over infinite traces. -/
def SystemProperty (α : Type) := SystemInfiniteTrace α → Prop

-- ═══════════════════════════════════════════════════════════
-- Failure Predicates at System Level
-- (These are hypotheses on theorems, not fields on DistSystem)
-- ═══════════════════════════════════════════════════════════

/-- The number of Nodes satisfying a predicate.
    Used for fault-tolerance bounds (e.g., "at most f crash-stop nodes"). -/
noncomputable def DistSystem.countWhere {α : Type}
    (sys : DistSystem α) (p : IdentifiedNode α → Prop) [DecidablePred p] : Nat :=
  sys.nodes.filter (fun n => p n) |>.length

-- ═══════════════════════════════════════════════════════════
-- Topology Predicates
-- ═══════════════════════════════════════════════════════════

/-- A Node is a single point of failure if it's the sole provider of a capability. -/
def DistSystem.isSPOF {α : Type} (sys : DistSystem α)
    (nid : NodeId) (capability : FunctionalRole) : Prop :=
  (sys.nodes.filter (fun n => n.role.functional == capability)).length = 1 ∧
  ∃ n, n ∈ sys.nodes ∧ n.nid = nid ∧ n.role.functional = capability

/-- The dependency graph is a subgraph of the topology:
    a Node can only depend on Nodes it can reach via the network. -/
def DistSystem.dependenciesReachable {α : Type} (sys : DistSystem α)
    (depends : NodeId → NodeId → Prop) : Prop :=
  ∀ src dst, depends src dst → sys.network.connected src dst

-- ═══════════════════════════════════════════════════════════
-- System as Node (Zoom)
-- ═══════════════════════════════════════════════════════════

/-- A System can appear as a single Node at a higher level.
    E.g., a database cluster (DistSystem of 3 replicas) looks like
    a single Database Node from the application's perspective. -/
structure SystemAsNode (α : Type) (S_abs S_sys : Type) where
  /-- The abstract single-Node view. -/
  node : Node α S_abs
  /-- The internal System. -/
  system : DistSystem α
  /-- The System's overall LTS (derived from composition). -/
  systemLTS : LTS S_sys (NodeAction α)
  /-- Proof that the System's behavior matches the abstract Node. -/
  refinement : LTS.Bisimilar node.lts systemLTS

-- ═══════════════════════════════════════════════════════════
-- Compositional Properties
-- ═══════════════════════════════════════════════════════════

/-- Parallel composition is commutative up to permutation. -/
theorem distSystem_nodes_perm_length {α : Type} (sys : DistSystem α)
    (p : List (IdentifiedNode α)) (hp : p.Perm sys.nodes) :
    p.length = sys.nodes.length :=
  List.Perm.length_eq hp

end SWELib.Foundations
