import SWELib.Basics.Uuid

/-!
# Distributed System Core Model

Foundational definitions for distributed systems modeling, following Verdi-style LTS semantics.
Based on representation decisions:
1. Distributed System Model Foundation: Verdi-style LTS
2. Node Identity Representation: `Uuid` from Basics module
3. Time Representation for Logical Clocks: `structure LogicalTime where count : Nat`
4. Message Representation: Parameterized `Message α`

References:
- Verdi: A Framework for Implementing and Verifying Distributed Systems (PLDI 2015)
- Lamport, "Time, Clocks, and the Ordering of Events in a Distributed System" (1978)
- Chandy and Lamport, "Distributed Snapshots: Determining Global States of Distributed Systems" (1985)
-/

namespace SWELib.Distributed

/-- Logical time for Lamport clocks. -/
structure LogicalTime where
  /-- Monotonically increasing counter. -/
  count : Nat
  deriving DecidableEq, Repr

/-- A node in a distributed system, identified by a UUID. -/
structure Node where
  /-- Unique identifier for the node. -/
  id : Basics.Uuid
  deriving DecidableEq, Repr

/-- A message with sender, receiver, and payload. -/
structure Message (α : Type) where
  /-- Sender node ID. -/
  sender : Node
  /-- Receiver node ID. -/
  receiver : Node
  /-- Message payload. -/
  payload : α
  /-- Logical timestamp when sent. -/
  timestamp : LogicalTime
  deriving DecidableEq, Repr

/-- Local state of a node, parameterized by state type `σ` and message payload type `α`. -/
structure LocalState (σ : Type) (α : Type) where
  /-- Node identifier. -/
  node : Node
  /-- Current state. -/
  state : σ
  /-- Current logical time. -/
  time : LogicalTime
  /-- Outgoing message buffer. -/
  outbox : List (Message α)
  deriving DecidableEq, Repr

/-- Global configuration of a distributed system. -/
structure GlobalConfig (σ : Type) (α : Type) where
  /-- Map from node IDs to local states. -/
  nodes : List (LocalState σ α)
  /-- Network: messages in transit. -/
  network : List (Message α)
  deriving DecidableEq, Repr

/-- Input event type for the LTS. -/
inductive InputEvent (α : Type) where
  /-- Local computation at a node. -/
  | local (node : Node) (input : α)
  /-- Message delivery from network. -/
  | deliver (msg : Message α)
  deriving DecidableEq, Repr

/-- Output event type for the LTS. -/
inductive OutputEvent (α : Type) where
  /-- Message sent to network. -/
  | send (msg : Message α)
  /-- Local output/effect. -/
  | effect (node : Node) (output : α)
  deriving DecidableEq, Repr

/-- Transition relation for a single node.
    Given current local state and input, produces new local state and outputs. -/
class NodeTransition (σ : Type) (α : Type) where
  step : LocalState σ α → InputEvent α → LocalState σ α × List (OutputEvent α)

/-- LTS step for the entire system.
    Processes one input event, updating global configuration. -/
def systemStep [DecidableEq α] [NodeTransition σ α] (cfg : GlobalConfig σ α) (input : InputEvent α) :
    GlobalConfig σ α × List (OutputEvent α) :=
  match input with
  | .local node inp =>
    -- Find the node's local state
    match cfg.nodes.find? (λ ls => ls.node == node) with
    | none => (cfg, [])  -- Node not found, no effect
    | some ls =>
      let (newLs, outputs) := NodeTransition.step ls (.local node inp)
      let newNodes := cfg.nodes.map (λ ls' => if ls'.node == node then newLs else ls')
      let newNetwork := cfg.network ++
        outputs.filterMap (λ out => match out with | .send msg => some msg | _ => none)
      (⟨newNodes, newNetwork⟩, outputs)
  | .deliver msg =>
    -- Deliver message to recipient
    match cfg.nodes.find? (λ ls => ls.node == msg.receiver) with
    | none => (cfg, [])  -- Recipient not found, message dropped
    | some ls =>
      let (newLs, outputs) := NodeTransition.step ls (.deliver msg)
      let newNodes := cfg.nodes.map (λ ls' => if ls'.node == msg.receiver then newLs else ls')
      let newNetwork := cfg.network.filter (λ m => !decide (m = msg)) ++
        outputs.filterMap (λ out => match out with | .send msg => some msg | _ => none)
      (⟨newNodes, newNetwork⟩, outputs)

/-- The happens-before relation (→) for events in a distributed system.
    Definition from Lamport 1978. -/
inductive HappensBefore {α : Type} : Message α → Message α → Prop where
  /-- If a and b are events in the same process, and a comes before b, then a → b. -/
  | sameProcess (a b : Message α) (h : a.sender = b.sender) (hlt : a.timestamp.count < b.timestamp.count) :
      HappensBefore a b
  /-- If a is the sending of a message and b is the receipt of that message, then a → b. -/
  | sendReceive (sent received : Message α) (h : sent.receiver = received.sender)
      (hmsg : sent.payload = received.payload) (hlt : sent.timestamp.count < received.timestamp.count) :
      HappensBefore sent received
  /-- Transitivity: if a → b and b → c then a → c. -/
  | trans (a b c : Message α) (hab : HappensBefore a b) (hbc : HappensBefore b c) : HappensBefore a c

/-- Two events are concurrent if neither happens before the other. -/
def concurrent {α : Type} (a b : Message α) : Prop :=
  ¬ HappensBefore a b ∧ ¬ HappensBefore b a

/-- Logical time comparison respects happens-before. -/
theorem logicalTime_monotonic {α : Type} (a b : Message α)
    (h : HappensBefore a b) : a.timestamp.count < b.timestamp.count := by
  induction h with
  | sameProcess _ _ _ h_lt => exact h_lt
  | sendReceive _ _ _ _ h_lt => exact h_lt
  | trans _ _ _ _ _ ih1 ih2 => exact Nat.lt_trans ih1 ih2

/-- Theorem: Happens-before is a strict partial order (irreflexive, transitive, asymmetric). -/
theorem happensBefore_irreflexive {α : Type} (a : Message α) : ¬ HappensBefore a a := by
  intro h
  have := logicalTime_monotonic a a h
  exact Nat.lt_irrefl _ this

theorem happensBefore_transitive {α : Type} (a b c : Message α)
    (hab : HappensBefore a b) (hbc : HappensBefore b c) : HappensBefore a c :=
  HappensBefore.trans a b c hab hbc

theorem happensBefore_asymmetric {α : Type} (a b : Message α)
    (hab : HappensBefore a b) : ¬ HappensBefore b a := by
  intro hba
  have : HappensBefore a a := HappensBefore.trans a b a hab hba
  exact happensBefore_irreflexive a this

end SWELib.Distributed
