# Sketch: System

## What This Sketch Defines

A System is a **parallel composition of Nodes** communicating over a **Network**. In CCS terms, a System is `(Node₁ | Node₂ | ... | Nodeₙ) \ internal_channels` — Nodes running concurrently with some channels restricted to enforce topology. Failure behavior is not a System-level field — it's baked into each Node's and Channel's LTS as transitions (see "Failure as LTS Transitions" below).

## Theoretical Foundation: CSLib

### System as CCS Parallel Composition

The System is not a new primitive — it's built from CCS operators applied to Nodes:

```
-- Each Node is an LTS (sketch 01)
-- A System composes them with CCS parallel composition
-- and restricts channels to enforce network topology

-- Unrestricted channel between Node A and Node B:
--   A can send on channel `c`, B can receive on `c̄`
--   They synchronize → internal τ action

-- Restricted channel:
--   Channel `c` is restricted → no external communication on it
--   Forces A and B to talk to each other, not to the outside

System = (AppServer | Database | Cache) \ db_query \ cache_query
```

The **Network** is not a separate entity carrying messages — it's the set of *unrestricted channels* between Nodes. Network topology = which channels exist. Network partition = dynamically restricting a channel that was previously open.

### System as LTS

A CCS parallel composition has an induced LTS (via the CCS operational semantics rules in CSLib). So a System is itself an LTS:

```
-- The System's LTS is derived from CCS composition rules:
-- 1. Any Node can take an independent step (PAR-L, PAR-R rules)
-- 2. Two Nodes with complementary actions synchronize (COM rule)
-- 3. Restricted channels block external communication (RES rule)

-- CSLib's CCS semantics give us this LTS automatically
def System.asLTS : LTS SystemState SystemAction := CCS.semantics system_ccs_term
```

This means all LTS-based tools (bisimulation, HML, trace equivalence) apply to Systems for free. A System is just another LTS at a higher level of composition.

### The Zoom Relationship

A System can appear as a single Node at a higher level. This is the NodeRefinement from sketch 01:

```
-- A database cluster (System of 3 replicas) looks like a single Database Node
-- from the application's perspective
def dbClusterRefinement : NodeRefinement where
  node := abstractDatabaseNode          -- single-Node interface
  internal := dbReplicaSystem           -- System of 3 replica Nodes
  equiv := proof_that_cluster_bisimulates_single_db
```

This is NOT mutual recursion — it's a one-directional refinement mapping. You never *need* to look inside; you *can* when you want to verify that the internals implement the interface correctly.

## Key Types to Formalize

### System

```
structure System where
  nodes : NodeSet                    -- the participants
  network : Network α               -- who can talk to who and how (see below + sketch 05)

-- The CCS term is DERIVED, not stored — no consistency proof needed
def System.ccs (sys : System) : CCS.Process :=
  compose sys.nodes sys.network.channels

-- The System's LTS is derived from the CCS term
def System.asLTS (sys : System) : LTS SystemState SystemAction :=
  sys.ccs.asLTS
```

The System definition is just **two fields**: nodes and network. The CCS term and LTS are computed, not stored. There is no `semantics_consistent` proof because the CCS term is derived from the decomposition — they agree by construction.

Failure behavior is not a System-level field. It lives inside each Node's LTS (crash transitions) and each Channel's LTS (partition transitions). See "Failure as LTS Transitions" below.

### NodeSet

Not just a list — captures identity, roles, and multiplicity:

```
structure NodeSet where
  nodes : Finset (NodeId × Node)        -- identified Nodes
  ids_unique : ∀ a b ∈ nodes, a.1 = b.1 → a = b
  roles : NodeId → NodeRole             -- functional role (database, API server, etc.)
```

Open question from original sketch: `Finset`, `List`, or `NodeId → Option Node`? For CCS composition, order doesn't matter (parallel composition is commutative and associative — proved in CSLib). So `Finset` is natural. But for replicas, you might want `NodeId → Node` with a cardinality constraint.

### Network

The Network wraps the channel function and provides a home for derived topology and property queries. See sketch 05 for the full treatment.

```
structure Network (α : Type) where
  channels : (src dst : NodeId) → Option (ChannelProcess α)

-- Derived: topology, symmetry, property queries
def Network.connected (net : Network α) (src dst : NodeId) : Prop :=
  (net.channels src dst).isSome

def Network.symmetric (net : Network α) : Prop :=
  ∀ src dst, net.connected src dst → net.connected dst src

def Network.allReliable (net : Network α) : Prop :=
  ∀ src dst ch, net.channels src dst = some ch → Reliable ch
```

**Key insight: the Network dissolves into CCS.** A Network is not a separate entity — it's a set of ChannelProcess instances (themselves CCS processes / LTS) interleaved with Node processes in the System's CCS term:

```
-- "System = Nodes + Network" is really:
System = (Node₁ | Channel₁₂ | Channel₂₁ | Node₂) \ internal
-- Channel processes mediate communication with specific properties
-- (reliable, lossy, FIFO, reordering, etc.)
```

Network properties (reliability, ordering, latency) emerge from the channel process's LTS — they're theorems about the channel, not declared tags. Different edges can have different channel processes (heterogeneous networks).

### Failure as LTS Transitions

There is no `FailureModel` enum on System. Failure behavior is baked directly into each Node's LTS as transitions — a crash-stop Node has a `crash` action leading to a terminal state, a crash-recovery Node has `crash → stopped → recover → initial`, and so on. This means failure is part of the Node definition, not System-level metadata.

Failure properties are predicates you prove about a Node's LTS:

```
-- A Node is crash-stop if it has a crash transition to a terminal state
def Node.isCrashStop (n : Node S α) : Prop :=
  ∃ s_crashed, (∀ s, n.lts.reachable s → n.lts.Tr s crash s_crashed) ∧
               (∀ a s', ¬ n.lts.Tr s_crashed a s')

-- A Node is crash-recovery if it can crash and then recover to initial
def Node.isCrashRecovery (n : Node S α) : Prop :=
  ∃ s_crashed, (∀ s, n.lts.reachable s → n.lts.Tr s crash s_crashed) ∧
               (n.lts.Tr s_crashed recover n.lts.initial)

-- A Node is Byzantine if after a fault action, any transition is possible
def Node.isByzantine (n : Node S α) : Prop :=
  ∃ s_fault, ∀ a s', n.lts.Tr s_fault a s'
```

This is strictly more expressive than a System-level enum — different Nodes in the same System can have different failure models (the database is crash-recovery, the cache is crash-stop) without encoding that in a single field.

Similarly, network failure (partition, degradation) is baked into the ChannelProcess LTS:

```
-- A channel that can partition has transitions:
-- (delivering, partition, dead)      — link goes down
-- (dead, heal, delivering)           — link comes back
-- No separate NetworkFailure type needed
```

System-level failure constraints (like "at most f out of n nodes crash") become hypotheses on theorems:

```
-- "Paxos is safe if at most f nodes are crash-stop and f < n/2"
theorem paxos_safe (sys : System)
  (h_crash : ∀ n ∈ sys.nodes, n.isCrashStop)
  (h_bound : crashedCount sys < sys.nodes.card / 2) : ...
```

### SystemTrace

A sequence of system states — the observable execution history:

```
-- Finite trace (for safety checking)
def FiniteTrace := List (SystemState × SystemAction × SystemState)

-- Infinite trace (for liveness checking)
-- Uses CSLib's omega execution: LTS.OmegaExecution
def InfiniteTrace := OmegaSequence (SystemState × SystemAction)
```

Safety properties = "no bad prefix exists" (checkable with DFA over finite traces).
Liveness properties = "good things happen infinitely often" (checkable with Büchi automata over infinite traces).

### SystemProperty

```
-- Safety: no trace reaches a bad state
def SafetyProperty := FiniteTrace → Prop

-- Liveness: every infinite fair trace eventually reaches a good state
def LivenessProperty (fair : InfiniteTrace → Prop) := InfiniteTrace → Prop

-- General: any property over traces
def SystemProperty := InfiniteTrace → Prop
```

The Alpern-Schneider decomposition theorem (1985): every SystemProperty can be written as the intersection of a SafetyProperty and a LivenessProperty. This tells us which checks are decidable (safety → DFA) and which need proof (liveness → Büchi/temporal logic).

## Properties via HML, Temporal Logic, and Automata

### HML (CSLib: Logics/HML/)

System-level HML formulas — properties of the System's LTS:

- `[send_request] ⟨recv_response⟩ true` — "after every request sent, a response can be received"
- `[node_crash] [node_crash] ... (f times) ... ⟨still_serving⟩ true` — "after f crashes, the system can still serve" (fault tolerance)

The characterization theorem applies: two Systems satisfy the same HML formulas iff they're bisimilar.

### Temporal Logic (LTL / CTL)

Not yet in CSLib, but expressible via mu-calculus (which HML + fixed points gives):

- `G (request → F response)` — "every request eventually gets a response" (liveness)
- `G (¬ data_loss)` — "data is never lost" (safety)
- `AG EF recover` — "from any state, recovery is always eventually possible" (recoverability, CTL)
- `G (mixed_version → old_invariant ∧ new_invariant)` — "during migration, both invariants hold" (migration safety)

### Büchi Automata (CSLib: Computability/Automata/)

For mechanized checking of liveness properties:

1. State the property as an LTL formula (human-readable)
2. Translate to a Büchi automaton (mechanical — LTL-to-Büchi translation)
3. Take the product with the System's automaton
4. Check for emptiness

CSLib provides the product construction and the automata hierarchy (DFA, NFA, Büchi, Muller). The LTL-to-Büchi translation would need to be built, or properties can be stated directly as Büchi acceptance conditions.

## Extension Points for Future Models

### Timed Systems (future)

When timed automata / timed CCS arrive:

```
-- Today: untimed topology
channels : NodeId → NodeId → Set Channel

-- Future: channels with latency bounds
channels : NodeId → NodeId → Set (Channel × LatencyBound)

-- Today: untimed failure transitions in Node LTS (crash → terminal)
-- Future: timed failure transitions (crash with MTBF, recover with MTTR)
-- The Node's LTS label type gains a time component
```

The System's LTS becomes a timed LTS. Bisimulation becomes timed bisimulation. Node and System definitions stay structurally the same — only the label type and equivalence relation change.

### Probabilistic Systems (future)

When probabilistic LTS arrives:

```
-- Today: nondeterministic failure
-- "Node can crash" = there exists a crash transition

-- Future: probabilistic failure
-- "Node crashes with probability p" = crash transition has weight p
-- Bisimulation becomes probabilistic bisimulation
```

### Dynamic Topology (future, needs Pi-calculus)

CCS has static channel names — topology is fixed at definition time. When Pi-calculus arrives in CSLib:

```
-- Today (CCS): static topology
System = (A | B | C) \ internal

-- Future (Pi-calculus): dynamic topology
-- Channels can be sent over channels
-- Models: service discovery, connection handoff, load balancer redirect
-- A discovers B's address by receiving it from a registry
System = (A | Registry | B)  where  Registry sends B's channel to A
```

### Fairness (future)

Liveness proofs need fairness assumptions. Parameterize now, fill in later:

```
-- Fairness as an explicit parameter
def LivenessProperty (fair : InfiniteTrace → Prop) (good : InfiniteTrace → Prop) :=
  ∀ trace, fair trace → good trace

-- Today: state the assumption abstractly
-- Future: plug in standard fairness definitions
--   strong fairness: GF enabled → GF executed
--   weak fairness: FG enabled → GF executed
```

### Graph Algorithms (future)

Topology analysis (SPOF detection, dependency cycles, blast radius) needs graph algorithms. State theorems existentially now:

```
-- Today: "if a path exists..."
theorem reachability_transitive :
  connected a b → connected b c → connected a c

-- Future: plug in DFS/BFS to constructively find paths
-- CSLib roadmap includes graph foundations
```

## Key Theorems Sketch

### Structural

- A System with a single-point-of-failure Node is not fault-tolerant: if that Node's LTS includes a crash transition and it's the sole provider of a capability, a safety property can be violated
- Removing a Node preserves safety iff no other Node depends on it (or quorum still holds)
- The dependency graph is a subgraph of the topology graph (you can only depend on Nodes you can reach)
- If topology is partitionable, CAP applies (formalize the tradeoff)

### Compositional (inherited from CSLib)

- If Node A is bisimilar to Node B, replacing A with B in any System preserves all System properties (congruence)
- System₁ | System₂ is bisimilar to System₂ | System₁ (commutativity of parallel composition)
- (System₁ | System₂) | System₃ is bisimilar to System₁ | (System₂ | System₃) (associativity)
- System | nil is bisimilar to System (identity)

### Safety/Liveness Decomposition

- Every SystemProperty decomposes into Safety ∩ Liveness (Alpern-Schneider)
- Safety properties are preserved by system refinement (adding Nodes can't break safety)
- Liveness properties require fairness assumptions (without fairness, liveness is trivially satisfiable by a stuck system)

## Relationship to Other Sketches

- Built from **Nodes (sketch 01)** via CCS parallel composition
- **Migration (sketch 03)** defines transitions between System versions; bisimulation quantifies whether the change is observable
- **Policy (sketch 04)** defines HML/temporal logic properties checked against the System's LTS; Büchi automata mechanize liveness checking

## Relationship to Existing SWELib Modules

- `Distributed/Core.lean` — existing `Node` + `NodeTransition` become instances of the LTS-based model; existing `System` type is superseded
- `Distributed/Consensus/Paxos`, `Raft` — become Protocols (CCS process definitions) running in specific System configurations (3 Nodes with crash-stop LTS transitions, async lossy channels)
- `Distributed/TwoPhaseCommit` — coordinator + participant Nodes composed with CCS
- `Distributed/CAP` — theorem about System properties under partitionable topology
- `Networking/Http` — defines the message types; `Systems.Node` of role HttpServer uses them as action labels
- `Db/ConnectionPool` — a dependency within a Node; managed via linear resources
- `Cloud/K8s` — K8s Deployment maps to a NodeSet with replica count; K8s Service maps to a Topology entry; K8s NetworkPolicy maps to channel restrictions

## Source Specs / Prior Art

- **CSLib** (Lean): CCS parallel composition, bisimulation congruence, HML characterization
- **Milner, "Communication and Concurrency"** (1989): CCS composition operators, equational laws
- **Lynch, "Distributed Algorithms"** (1996): I/O automata composition, simulation, the canonical distributed systems formalism
- **Alpern & Schneider, "Defining Liveness"** (1985): safety/liveness decomposition
- **Vardi & Wolper** (1986): automata-theoretic verification (Büchi automata for liveness)
- **Baier & Katoen, "Principles of Model Checking"** (2008): temporal logic, model checking algorithms
- **TLA+** (Lamport): state-machine + trace-property framework; our LTS + SystemProperty is the typed version
- **Kubernetes**: Deployment = NodeSet, Service = Topology, NetworkPolicy = channel restriction
- **AWS Well-Architected Framework**: informal vocabulary (fault tolerance, blast radius) we're formalizing
