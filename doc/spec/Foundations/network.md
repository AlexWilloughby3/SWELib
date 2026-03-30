# Sketch: Network

## What This Sketch Defines

The Network is the **communication medium between Nodes**. It is the central variable that determines what level of the abstraction hierarchy you're modeling — the Node and System definitions are level-agnostic, but the Network properties are what make reasoning about CPU↔RAM different from reasoning about Server↔Server.

In CCS terms, the Network determines which channels exist between Nodes (topology), how synchronization works (synchrony model), and what can go wrong with messages (reliability). In the System sketch, Network was embedded as `Topology` inside System. This sketch promotes it to a first-class concept because it's the most diverse and consequential part of the framework.

## Why Network Is the Central Variable

The same Node definition works at every level of granularity. What changes is the Network:

| Level | Nodes | Network Medium | Synchrony | Reliability | Latency | Ordering |
|-------|-------|---------------|-----------|-------------|---------|----------|
| CPU pipeline | Pipeline stages | Forwarding network | Synchronous (clocked) | Perfect | Exactly 1 cycle | Strict in-order |
| CPU ↔ RAM | CPU, RAM controller | Memory bus | Synchronous | Perfect | Bounded (~100ns) | Sequential consistency (with caveats) |
| Process ↔ Process (same machine) | OS processes | Shared memory / pipes / Unix sockets | Synchronous | Reliable | Bounded (~μs) | Program order / FIFO |
| Container ↔ Container (same pod) | Containers | Localhost / shared network namespace | Near-synchronous | Reliable | Bounded (~ms) | FIFO per connection |
| Server ↔ Server (same DC) | Servers | LAN (Ethernet/switches) | Partially synchronous | Mostly reliable | Bounded (~1-5ms) | FIFO per TCP, unordered across |
| Server ↔ Server (cross-region) | Servers | WAN (internet backbone) | Asynchronous | Lossy | Unbounded (50-300ms typical) | Reordering possible |
| Server ↔ Phone | Server, mobile client | Internet + cellular | Asynchronous | Lossy, variable | Unbounded, variable | Reordering, duplication |
| Trader ↔ Exchange | Trading systems | Exchange protocol (FIX/ITCH) | Partially synchronous | Reliable (regulated) | Bounded (regulated SLA) | Sequenced (exchange-assigned) |
| Sensor ↔ Gateway (IoT) | Embedded devices | Wireless (LoRa/BLE/Zigbee) | Asynchronous | Very lossy | Unbounded, high variance | Unordered |
| Satellite ↔ Ground | Spacecraft, ground station | RF link | Asynchronous | Lossy (signal fade) | Bounded but large (seconds-minutes) | FIFO per link |
| Blockchain nodes | Validator nodes | P2P gossip | Asynchronous | Lossy, duplicating | Unbounded | Unordered (gossip) |

The theorems you can prove depend entirely on which row you're in:
- **Synchronous + reliable** → trivial coordination, no consensus problem
- **Partially synchronous + reliable** → timeout-based failure detection works, Paxos/Raft applicable
- **Asynchronous + lossy** → FLP impossibility, need randomized or partially synchronous algorithms
- **Asynchronous + Byzantine** → BFT consensus needed, f < n/3

## Theoretical Foundation

### Network as CCS Channels + Properties

In CCS, communication is **synchronous handshake**: when process P does action `a` and process Q does `ā`, they synchronize instantly. There's no message "in flight" — the send and receive are a single atomic event (the τ step in the composed system).

Real networks aren't like this. Messages take time, get lost, get reordered. To model this in CCS, the Network is an explicit **intermediary process** placed between Nodes:

```
-- Synchronous CCS (no channel process needed):
System = (Sender | Receiver)
-- send and recv synchronize directly (SystemAction.sync)

-- Asynchronous reliable network (buffer process):
ReliableChannel = enqueue(msg) . τ . deliver(msg) . ReliableChannel

-- Asynchronous lossy network (can drop messages):
LossyChannel = enqueue(msg) . (τ . deliver(msg) . LossyChannel
                              + τ . drop(msg) . LossyChannel)  -- nondeterministic: deliver or drop

-- Asynchronous duplicating network (can replay):
DuplicatingChannel = enqueue(msg) . DuplicatingDeliver(msg)
DuplicatingDeliver(msg) = τ . deliver(msg) . (DuplicatingDeliver(msg) + DuplicatingChannel)
                           -- deliver, then either deliver again or accept next message

-- Reordering network (set-based buffer, not queue):
-- Uses the `reorder` action before delivering out of order
-- Each message gets its own delivery nondeterminism
```

The Network IS a set of these channel processes. Different network properties = different channel process definitions. In the formalization, a `DistSystem` composes `IdentifiedNode`s with a `Network` of `Channel` instances:

```
DistSystem = (Node₁ | Channel₁₂ | Channel₂₁ | Node₂) \ internal
```

This is elegant: the Network isn't a special concept — it's just more LTS processes. All the LTS/bisimulation machinery from `Foundations/LTS.lean` applies to channels exactly as it does to Nodes.

### Network Properties as LTS Constraints

Rather than defining network properties as separate enums, they emerge from the channel process's LTS:

```
-- A channel is reliable iff it never drops:
def Channel.isReliable (ch : Channel α S) : Prop :=
  ∀ s msg s', ¬ ch.lts.Tr s (.drop msg) s'

-- A channel is FIFO iff messages are delivered in enqueue order:
-- (see formalized definition for the precise consecutive-enqueue version)
def Channel.isFIFO (ch : Channel α S) : Prop :=
  ∀ s m₁ m₂ s₁ s₂,
    ch.lts.Tr s (.enqueue m₁) s₁ → ch.lts.Tr s₁ (.enqueue m₂) s₂ →
    ∀ s₃, ch.lts.Tr s₂ (.deliver m₂) s₃ →
      ∃ s_mid, LTS.FiniteTrace ch.lts s₂ s_mid ∧
        ∃ s₄, ch.lts.Tr s_mid (.deliver m₁) s₄

-- A channel is lossy iff there exist traces where an enqueued message is dropped:
-- (not yet formalized — planned as:)
def Channel.isLossy (ch : Channel α S) : Prop :=
  ∃ s msg s', ch.lts.Tr s (.drop msg) s'
```

This approach means network properties are **theorems about the channel's LTS**, not separate type-level tags. You can prove that a specific `Channel` instance satisfies `isReliable`, `isFIFO`, etc. — and then use those proofs as hypotheses in `DistSystem`-level theorems.

### Synchrony Models as Timing Constraints

Without timed models (our current situation), synchrony is modeled structurally:

- **Synchronous**: no channel process at all — CCS direct synchronization. Send and receive are atomic.
- **Asynchronous**: channel process with unbounded buffer. No guarantee on when (or if) delivery happens.
- **Partially synchronous**: channel process with a bounded buffer or eventually-bounded delivery. This is hard to express without time — it's the main thing we lose by not having timed CCS yet.

When timed CCS arrives, synchrony becomes a timing property of the channel process:
```
-- Future: synchronous = delivery within bound Δ
-- Future: partially synchronous = ∃ GST, after GST delivery within Δ
-- These need timed LTS labels
```

In the formalization, synchrony is not a separate enum — it's handled structurally (see "Synchrony Model" under Formalized Types below). Synchronous communication uses `SystemAction.sync`; asynchronous uses channel processes. Partially synchronous results carry assumptions as hypotheses on theorems until timed CCS arrives.

## Formalized Types (in `Foundations/System.lean`)

The following types are already formalized. The pseudocode in this sketch has been updated to match.

### ChannelAction and Channel

A channel is an LTS that mediates between two Nodes. Its action alphabet covers the full lifecycle of a message — acceptance, delivery, loss, reordering — plus link-level events (partition/heal):

```lean
inductive ChannelAction (α : Type) where
  | enqueue (msg : α)      -- accept a message for delivery
  | deliver (msg : α)      -- deliver a message to the receiver
  | drop (msg : α)         -- drop a message (lossy channel)
  | reorder                -- deliver out of enqueue order (non-FIFO)
  | partition              -- link goes down
  | heal                   -- link comes back up

structure Channel (α : Type) (S : Type) where
  lts : LTS S (ChannelAction α)
  src : NodeId
  dst : NodeId
```

Design note: `Channel` is parameterized over a state type `S`, not existentially quantified. The existential is pushed to `Network.channels` (see below). This lets individual channel definitions keep their concrete state type for proofs while the Network erases it.

### Channel Properties (Prop-valued defs, not typeclasses)

Network properties are `Prop`-valued definitions on `Channel`, not typeclasses. This is a deliberate choice: properties are proved per-channel-instance rather than resolved by typeclass inference, which avoids coherence issues when the same channel type could be reliable on some edges and lossy on others.

```lean
-- A channel is reliable if it never drops messages.
def Channel.isReliable (ch : Channel α S) : Prop :=
  ∀ s msg s', ¬ ch.lts.Tr s (.drop msg) s'

-- A channel is FIFO if messages are delivered in enqueue order.
-- Current definition: if m₁ is enqueued before m₂ (consecutively), then
-- m₂ cannot be delivered before m₁ has been delivered.
def Channel.isFIFO (ch : Channel α S) : Prop :=
  ∀ s m₁ m₂ s₁ s₂,
    ch.lts.Tr s (.enqueue m₁) s₁ →
    ch.lts.Tr s₁ (.enqueue m₂) s₂ →
    ∀ s₃, ch.lts.Tr s₂ (.deliver m₂) s₃ →
      ∃ s_mid, LTS.FiniteTrace ch.lts s₂ s_mid ∧
        ∃ s₄, ch.lts.Tr s_mid (.deliver m₁) s₄

-- A channel can partition if it has partition transitions.
def Channel.canPartition (ch : Channel α S) : Prop :=
  ∃ s s', ch.lts.Tr s .partition s'
```

**Known limitation**: `isFIFO` only covers consecutive enqueues from the same state. A stronger definition would cover arbitrary interleaving (m₁ enqueued at any point before m₂, with other operations in between). This is sufficient for the current formalization targets but should be strengthened when we build concrete channel instances.

**Not yet formalized**: `Lossy` (existential: some trace drops), `NonDuplicating` (deliver count ≤ enqueue count). These will be added as concrete channel instances need them.

### Network

```lean
structure Network (α : Type) where
  -- Existential over channel state type: each edge can have
  -- a different state space. The Σ erases the state type so
  -- the Network doesn't need to know it.
  channels : NodeId → NodeId → Option (Σ S : Type, Channel α S)

def Network.connected (net : Network α) (src dst : NodeId) : Prop :=
  (net.channels src dst).isSome

def Network.symmetric (net : Network α) : Prop :=
  ∀ src dst, net.connected src dst → net.connected dst src

def Network.allReliable (net : Network α) : Prop :=
  ∀ src dst ch, net.channels src dst = some ch → ch.2.isReliable

def Network.fullyConnected (net : Network α) (nodes : List NodeId) : Prop :=
  ∀ n₁ n₂, n₁ ∈ nodes → n₂ ∈ nodes → n₁ ≠ n₂ → net.connected n₁ n₂
```

Heterogeneous networks are handled naturally: each edge has its own `Channel` with its own state type and LTS. So `(Server₁ ↔ Server₂)` can use a reliable FIFO channel while `(Server₁ ↔ MobileClient)` uses a lossy unordered channel in the same `DistSystem`.

### Composition Mechanics (SystemAction)

The sketch originally didn't explain how channel actions synchronize with Node actions. The formalization defines a three-constructor `SystemAction` that makes the two-phase communication model explicit:

```lean
inductive SystemAction (α : Type) where
  | nodeStep (nid : NodeId) (action : NodeAction α)
    -- A single Node takes an independent step.
  | sync (src dst : NodeId) (action : α)
    -- Two Nodes synchronize: src outputs, dst inputs, via a channel.
    -- This is the CCS τ-step from parallel composition.
  | channelStep (src dst : NodeId) (action : ChannelAction α)
    -- A channel takes an internal step (enqueue, deliver, drop, reorder,
    -- partition, heal). These are autonomous channel behaviors.
```

The communication lifecycle is:
1. **Node outputs** → `nodeStep src (output msg)` — the source Node produces a message
2. **Channel enqueues** → `channelStep src dst (enqueue msg)` — the channel accepts it
3. **Channel delivers** → `channelStep src dst (deliver msg)` — the channel makes it available
4. **Node inputs** → `nodeStep dst (input msg)` — the destination Node receives it

Steps 2–3 are where network properties matter: a reliable channel always reaches step 3, a lossy channel may `drop` instead, a non-FIFO channel may `reorder` before delivering.

The `sync` constructor handles direct CCS-style synchronization (no intermediary channel). This models the synchronous case where no channel process is needed.

### Network Failure

Network failures are baked into `ChannelAction` as `partition` and `heal` transitions — there is no separate failure enum. A channel that can partition has these transitions in its LTS state machine:

```
(delivering) --partition--> (dead)       — link goes down, subsequent messages dropped
(dead)       --heal------> (delivering)  — link comes back
```

`Channel.canPartition` (already formalized) checks whether a channel's LTS has any partition transitions. Failure properties like "after partition, no deliveries are possible" would be proved about the specific channel instance's LTS.

Note: dynamic restriction (partition/heal at runtime) is hard in standard CCS where restriction is static. This is another reason pi-calculus would help — see Extension Points.

### Synchrony Model

Synchrony is **not formalized as a separate enum**. The original sketch proposed a `SynchronyModel` type, but this contradicts the core design principle that network properties are theorems about the channel's LTS, not tags. Instead:

- **Synchronous**: modeled via `SystemAction.sync` — direct CCS synchronization, no channel process.
- **Asynchronous**: modeled via a channel process with unbounded buffer. No guarantee on when (or if) delivery happens.
- **Partially synchronous**: requires timed CCS to define properly (bounded delivery after GST). Currently handled by carrying assumptions as hypotheses on theorems (e.g., "assuming eventually-bounded delivery, Raft terminates").

### Standard Channel Instances (Not Yet Formalized)

The following are planned but not yet built. Each would be a concrete `Channel` definition with a specific state type (e.g., `List α` for a queue-based channel) and proved properties:

| Instance | State type | Key properties | Models |
|----------|-----------|----------------|--------|
| `reliableFIFO` | `List α` (queue) | `isReliable ∧ isFIFO` | TCP |
| `lossyUnordered` | `List α` (set-like) | `¬isReliable ∧ ¬isFIFO` | UDP |
| `lossyDuplicating` | `List α` + replay flag | `¬isReliable ∧ ¬isFIFO` | Unreliable broadcast |
| `fairLossy` | `List α` + fairness | lossy but fair (needs liveness/Büchi) | Paxos network model |

Building even one of these (e.g., `reliableFIFO` as a queue state machine with `enqueue` appending and `deliver` popping the head) would validate the framework end-to-end. This is a good next formalization target.

## Relationship to CCS Composition

The key insight: **the Network dissolves into CCS**. A `DistSystem` isn't "Nodes + Network" as two separate things — it's a single composition where `Channel` instances (each an LTS) are interleaved with `Node` instances (each an LTS):

```
-- "DistSystem = Nodes + Network" is really:
DistSystem = (Node₁ | Channel₁₂ | Channel₂₁ | Node₂ | Channel₁₃ | Channel₃₁ | Node₃) \ internal

-- Communication via SystemAction:
-- 1. Node₁ outputs msg:       SystemAction.nodeStep node₁ (output msg)
-- 2. Channel₁₂ enqueues:      SystemAction.channelStep node₁ node₂ (enqueue msg)
-- 3. Channel₁₂ delivers:      SystemAction.channelStep node₁ node₂ (deliver msg)
-- 4. Node₂ inputs msg:        SystemAction.nodeStep node₂ (input msg)
--
-- Or for synchronous (no channel): SystemAction.sync node₁ node₂ msg
```

This means:
- Network properties are emergent from the channel LTS — not declared separately
- All LTS/bisimulation reasoning from `Foundations/LTS.lean` applies uniformly to Nodes and Channels
- You can prove things like "replacing a reliable channel with a lossy one breaks liveness property X" via bisimulation failure
- Network partitions = a channel's `partition` transition leading to a state where only `drop` is possible

## Extension Points

### Timed Networks (future, needs timed CCS)

The biggest current gap. Without time, we can't express:
- "Message delivery takes at most 5ms" (bounded latency)
- "After GST, message delivery takes at most Δ" (partial synchrony — the Dwork-Lynch-Stockmeyer model)
- "Timeout fires after T with no response" (timeout-based failure detection)

When timed CCS arrives:
```
-- Channel action carries a time component
inductive TimedChannelAction (α : Type) where
  | recv_from_sender : α → Time → TimedChannelAction α
  | deliver_to_receiver : α → Time → TimedChannelAction α

-- Bounded latency = delivery time - receive time ≤ Δ
class BoundedLatency (ch : TimedChannelProcess α) (Δ : Time) : Prop where
  bounded : ∀ msg t_recv t_deliver,
    received_at ch msg t_recv → delivered_at ch msg t_deliver →
    t_deliver - t_recv ≤ Δ
```

### Probabilistic Networks (future, needs probabilistic LTS)

```
-- Today: "channel can drop messages" (nondeterministic)
-- Future: "channel drops messages with probability p"
-- Useful for: SLA modeling, reliability engineering, failure rate analysis
```

### Dynamic Topology (future, needs pi-calculus)

CCS channel names are static — the topology is fixed at definition time. Pi-calculus adds channel mobility:

```
-- Today: Node₁ can talk to Node₂ because channel `c` exists statically
-- Future: Node₁ discovers Node₂ by receiving its channel from a Registry
-- Models: service discovery, DNS resolution, load balancer redirect,
--         connection migration, handoff during rolling deploy
```

This is particularly important for Migration (sketch 03): during a rolling deploy, traffic is redirected from old Nodes to new Nodes. With CCS, you'd need to model this as a completely new System. With pi-calculus, the load balancer sends the new Node's channel to clients — the topology changes dynamically within a single System evolution.

### Multicast and Broadcast (future)

CCS channels are point-to-point (one sender, one receiver synchronize). Real networks have:
- **Multicast**: one sender, multiple receivers (pub/sub, event streaming)
- **Broadcast**: one sender, all receivers (ARP, service discovery)
- **Gossip**: probabilistic broadcast (epidemic protocols, blockchain)

These can be modeled in CCS with fan-out processes:

```
Broadcast = recv_from_sender . (deliver_to_1 | deliver_to_2 | deliver_to_3) . Broadcast
```

But this is verbose for large systems. A broadcast primitive would be cleaner.

## Key Theorems Sketch

### Channel Properties (to prove when standard instances are built)

- `reliableFIFO.isReliable` and `reliableFIFO.isFIFO` (TCP-like guarantees)
- `lossyUnordered.isLossy ∧ ¬lossyUnordered.isFIFO` (UDP-like)
- A `isReliable ∧ isFIFO` channel composed with another `isReliable ∧ isFIFO` channel preserves both properties (transitivity of reliable FIFO delivery)

### System-Level Consequences

- Under `Network.allReliable`, crash-stop consensus is solvable with `f < n/2` (standard result, but now proved from `Channel.isReliable` rather than assumed)
- Under a network where some channels satisfy `isLossy`, those Nodes cannot participate in synchronous protocols (need retry/ack)
- If a channel is replaced with a bisimilar one (`LTS.Bisimilar`), all `DistSystem` properties are preserved (congruence)
- Network partition (`Channel.canPartition`) can violate `LivenessProperty` but not `SafetyProperty` of well-designed protocols

### Relationship Theorems

- `DistSystem.dependenciesReachable` (already formalized): if Node A depends on Node B, there must be a channel (`Network.connected`) from A to B
- Network reliability constrains achievable consistency: `isLossy` channels → can't guarantee linearizability without retries
- Heterogeneous network = different proof obligations per edge (each `Σ S, Channel α S` has its own properties)

## Relationship to Other Sketches

- **Node (sketch 01)**: `Node α S` and `Channel α S` share the same action type `α` — they synchronize on the same alphabet. Both are formalized in `Foundations/`.
- **System (sketch 02)**: `DistSystem α` composes `IdentifiedNode`s with a `Network α` of `Channel` instances. The Network dissolves into the composed LTS via `SystemAction`.
- **Migration (sketch 03)**: During migration, Network topology may change (traffic rerouted to new Nodes). With current CCS, this requires a new `DistSystem` definition. With pi-calculus (future), topology changes dynamically.
- **Policy (sketch 04)**: Network properties constrain which policies are satisfiable. A `LivenessProperty` under `isLossy` channels requires retry logic. Policy feasibility depends on network assumptions.

## Relationship to Existing SWELib Modules

- `Networking/Tcp` — TCP is a `reliableFIFO` channel with connection state machine. The existing TCP formalization could provide the SOS rules for a concrete `Channel` instance with `isReliable ∧ isFIFO`.
- `Networking/Udp` — UDP is a `lossyUnordered` channel (or closer to `fairLossy` with checksum validation). Maps to a `Channel` instance with `isLossy ∧ ¬isFIFO`.
- `Networking/Tls` — TLS wraps a `Channel` with encryption/authentication. The resulting channel has the same reliability/ordering as the underlying one, plus confidentiality and integrity properties.
- `Networking/Http` — HTTP request/response is a protocol running over a reliable FIFO channel (TCP). The message type `α = HttpMessage`.
- `Networking/Websocket` — Persistent bidirectional channel over TCP. Two reliable FIFO `Channel` instances (one per direction).
- `Networking/Dns` — DNS resolution could be modeled as a service discovery channel (relevant for dynamic topology with future pi-calculus).
- `Distributed/Consensus` — Consensus algorithms have explicit network model requirements. Paxos requires fair lossy channels. Raft requires partially synchronous channels. These become hypotheses (`Channel.isReliable`, `Channel.isFIFO`, etc.) on the consensus theorems.

## Source Specs / Prior Art

- **CSLib** (Lean): CCS synchronization semantics — the base model. Channel processes are CCS processes.
- **Milner, "Communication and Concurrency"** (1989): CCS channel semantics, synchronous communication model
- **Lynch, "Distributed Algorithms"** (1996): I/O automata channel model, explicit send/receive queues, the standard distributed systems treatment
- **Dwork, Lynch, Stockmeyer, "Consensus in the Presence of Partial Synchrony"** (1988): the DLS model — defines partial synchrony with GST (Global Stabilization Time). Our partially synchronous model is an abstraction of this, pending timed CCS.
- **Fischer, Lynch, Paterson, "Impossibility of Distributed Consensus with One Faulty Process"** (1985): FLP impossibility — the reason asynchronous networks need special algorithms. Our framework should be able to state and prove this.
- **Vardi & Wolper** (1986): Büchi automata for checking liveness over network traces
- **Kubernetes NetworkPolicy**: Topology restriction at the container level — an instance of our channel restriction model
- **AWS/GCP network tiers**: Heterogeneous networks within a single system — premium (reliable, low-latency) vs standard (best-effort) tiers map to different ChannelProcess instances on different edges
