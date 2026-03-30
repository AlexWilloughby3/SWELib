# Vision: Abstract System Formalizations

## Motivation

SWELib currently formalizes individual protocols, algorithms, and data formats in isolation — HTTP requests, Paxos consensus, SQL semantics, TLS handshakes. These are valuable but they miss the most important (and hardest) properties in real software: what happens when you compose these things into a running system, and what happens when that system evolves over time.

The hardest bugs don't live in a single protocol. They live in:
- Version skew during rolling deploys
- Missing auth on a new endpoint nobody reviewed
- A schema migration that's forward-compatible but not rollback-safe
- A service that bypasses the data layer and talks directly to the DB

We want to formalize the concepts needed to reason about these problems.

## Formal Foundation: CSLib

The Systems framework is built on **CSLib**, a Lean 4 library providing:
- **Labeled Transition Systems (LTS)** — the universal state machine model
- **CCS (Calculus of Communicating Systems)** — parallel composition, restriction, synchronization
- **Bisimulation** — strong, weak, and congruence proofs
- **HML (Hennessy-Milner Logic)** — behavioral property specification
- **Automata** — DFA, NFA, Buchi automata for mechanized checking
- **Linear Logic** — resource management (connections, file descriptors)
- **Free Monads** — effect-based behavior descriptions

Every concept in the Systems framework is an instance of or derived from CSLib primitives. This gives us a unified toolbox: bisimulation for equivalence, HML for properties, automata for mechanized checking — all applied uniformly to Nodes, Networks, and Systems.

## Core Abstraction Hierarchy

### Node

The fundamental building block. A **Node** is an isolated execution environment formalized as a **Labeled Transition System** parameterized by action type and state type.

Nodes are level-agnostic: a Node can be a container, VM, bare metal machine, phone, CPU pipeline stage, or an entire cloud region. What changes across levels is the Network (see below), not the Node definition.

Actions are classified as Input (environment-controlled, can't be refused), Output (Node-controlled), or Internal (invisible tau transitions). This distinction comes from Lynch's I/O Automata.

Key properties at the Node level:
- **Structural role**: has listeners (can accept connections), has dependencies (needs outbound connections), both, or neither
- **Functional role**: database, API server, load balancer, mobile client, etc.
- **Health state**: healthy, degraded, draining, stopped — a sub-LTS with monotonic shutdown transitions
- **Failure behavior**: crash-stop, crash-recovery, or Byzantine — not declared as an enum, but *proved as predicates* about the Node's LTS transitions
- **Resource limits**: connection limits, memory bounds, fd limits — constrain the reachable state space

For composition, a Node is also a **CCS process** with internal channels restricted. Internal processes communicate on restricted channels; only the external interface is visible to other Nodes.

A Node is opaque at the System level but can be "opened up" via **NodeRefinement** — a weak bisimulation between the abstract Node LTS and an internal sub-System. This is one-directional (not mutual recursion): you *can* look inside, but you don't have to. Bisimulation is a congruence for CCS operators, so replacing a Node with a bisimilar one in any System preserves all properties.

See [node.md](node.md) for full details including CCS representation, HML properties, free monad behavior, and extension points for timed/probabilistic models.

### Network

The communication medium between Nodes. The Network is the **central variable** that determines what level of abstraction you're modeling — Node and System definitions are level-agnostic, but Network properties determine which theorems are provable.

The Network is not a separate entity — it **dissolves into CCS**. Each directed edge between Nodes is an explicit **ChannelProcess** (itself an LTS/CCS process) that mediates communication:

- **Synchronous** (CPU pipeline): no channel process, CCS direct synchronization
- **Reliable FIFO** (TCP-like): buffer process that preserves order and guarantees delivery
- **Lossy unordered** (UDP-like): nondeterministic drop/deliver
- **Fair lossy**: lossy but eventually delivers with retries

Network properties (Reliable, FIFO, Lossy, NonDuplicating) are **theorems about the channel process's LTS**, not declared tags. Different edges can have different channel processes (heterogeneous networks). Network failure (partitions, degradation) is baked into channel LTS transitions.

The same framework spans all levels:

| Level | Network Medium | Synchrony | Reliability |
|-------|---------------|-----------|-------------|
| CPU pipeline | Forwarding network | Synchronous | Perfect |
| Process-to-process | Shared memory / pipes | Synchronous | Reliable |
| Container-to-container (same pod) | Localhost | Near-synchronous | Reliable |
| Server-to-server (same DC) | LAN | Partially synchronous | Mostly reliable |
| Server-to-server (cross-region) | WAN | Asynchronous | Lossy |
| Server-to-phone | Internet + cellular | Asynchronous | Lossy, variable |

See [network.md](network.md) for full details including synchrony models, standard channel library, and multicast/broadcast.

### System

A **parallel composition of Nodes** communicating over a Network. In CCS terms:

```
System = (Node₁ | Channel₁₂ | Channel₂₁ | Node₂) \ internal_channels
```

A System has just two fields: **nodes** (a NodeSet with identity and roles) and **network** (who can talk to whom and how). The CCS term and induced LTS are *derived*, not stored — no consistency proof needed.

Failure behavior is not a System-level field. It lives inside each Node's LTS (crash transitions) and each Channel's LTS (partition transitions). System-level failure constraints (like "at most f out of n nodes crash") become hypotheses on theorems.

A System is itself an LTS (via CCS operational semantics), so all LTS-based tools — bisimulation, HML, trace equivalence — apply to Systems for free. A System can also appear as a single Node at a higher level via the zoom/refinement relationship.

Key compositional properties (inherited from CSLib):
- Parallel composition is commutative, associative, has identity (nil)
- Bisimilar substitution preserves all System properties (congruence)
- Safety/liveness decomposition (Alpern-Schneider): every property = Safety intersection Liveness

See [system.md](system.md) for full details including traces, SystemProperty types, and extension points.

### Migration & System Evolution

A real system is not a static snapshot — it's a chain of versions with migrations between them. A Migration replaces some Nodes with new versions. The critical question: does the **MixedVersionState** (some Nodes on v1, some on v2, composed with CCS parallel) preserve safety?

Bisimulation quantifies migration impact:
- **Bisimilar** (A_v1 ~ A_v2): migration is invisible, zero risk
- **Weakly bisimilar**: internal behavior changed, external interface identical
- **Not bisimilar**: observable behavior changed — the LTS diff characterizes what changed

Compatibility is formalized through simulation relations:
- **Backward compatible**: v2 simulates v1 (every old behavior preserved)
- **Forward compatible**: v1 can handle v2's new outputs
- **Wire compatible**: v1 and v2 can synchronize on shared CCS channels

#### Proof Compaction

Incremental migration proofs accumulate over time — each PR adds one. Without management, CI carries proof baggage from ancient migrations. The solution is a **retention cap with automatic compaction**:

- Retain the most recent K incremental migration proofs (configurable per policy)
- Beyond the cap, fold the oldest step into a **collapsed anchor proof** — a direct, self-contained proof that the current spec satisfies all invariants, with no reference to history
- Compaction is sound because invariants are properties of the endpoint, not the path
- MixedVersionState safety proofs for old deploys are explicitly discarded (those deploys are ancient history)

See [migration.md](migration.md) for full details including VersionedSystem, RollbackPlan, and temporal properties.

### Policy & CI Integration

The enforcement layer that makes the framework useful in practice. Four verification levels, each mapping to a specific formal mechanism:

| Level | What | Formal Tool | Decidability |
|-------|------|-------------|-------------|
| 0: Lint | Syntactic check on snapshot | DFA / predicate | Decidable (CI) |
| 1: Invariant | Semantic property | HML / safety property | Some decidable, some need proof |
| 2: Migration | Transition property | Simulation / bisimulation | Some decidable, some need proof |
| 3: Meta | Property of the rules | Theorem about policy | Needs interactive proof |

Policies compose via layers (org-wide, team, project). Compliance frameworks (SOC2, HIPAA, PCI-DSS) are formalized as sets of SystemInvariants and MigrationConstraints — "our policy satisfies SOC2" becomes a theorem, not a claim in a slide deck.

CI integration:
1. Bridge tooling extracts System v2 from code artifacts (protobuf, SQL schemas, OpenAPI, K8s manifests, etc.)
2. Diff against v1 produces Migration
3. Run Level 0-2 checks
4. Append migration proof to retained history; rotate if over cap

See [policy-ci.md](policy-ci.md) for full details including automata-based verification, decidability boundary, and compaction as CI gate.

### Isolation Boundaries

How the abstract Node connects to concrete isolation mechanisms. Containers, VMs, and bare metal are all the same Node at the System level — what differs is the **refinement**.

Core claim: **isolation is a property of the refinement, not the abstract interface.** System-level theorems (like "Paxos is safe with f < n/2 crash-stop nodes") hold regardless of whether nodes are containers, VMs, or physical machines. The isolation mechanism only matters for whether the crash-stop assumption is *justified*.

Each isolation mechanism maps to CCS concepts:
- **Namespaces** = CCS restriction operator on OS-level channels (PID, network, mount, IPC, UTS, user, cgroup)
- **Cgroup limits** = reachable state space constraints on the Node's LTS
- **Seccomp filters** = action alphabet restriction (simulation relation: filtered Node simulates unfiltered)
- **Capabilities** = further action alphabet restriction
- **VM hypervisor** = separate LTS with virtual channels mapped by the hypervisor

Failure independence depends on the isolation level:
- **Bare metal**: unconditionally independent
- **VM**: independent conditioned on hypervisor liveness
- **Container**: independent conditioned on kernel liveness AND cgroup enforcement

See [isolation.md](isolation.md) for full details including OCI lifecycle as LTS, Pod as CCS composition, and nested isolation.

## Module Structure

```
spec/SWELib/
├── Systems/
│   ├── Node.lean              -- Node as LTS (action types, health, shutdown, roles)
│   ├── Node/
│   │   ├── Refinement.lean    -- NodeRefinement, zoom, bisimulation proofs
│   │   └── Behavior.lean      -- Free monad behavior descriptions
│   ├── Network.lean           -- Network, ChannelProcess, topology
│   ├── Network/
│   │   ├── Channels.lean      -- Standard channel library (syncChannel, reliableFIFO, etc.)
│   │   └── Properties.lean    -- Reliable, FIFO, Lossy typeclasses
│   ├── System.lean            -- System as CCS composition, SystemTrace, SystemProperty
│   ├── Migration.lean         -- Migration, MixedVersionState, Compatibility, RollbackPlan
│   ├── Migration/
│   │   ├── Compaction.lean    -- Proof compaction, RetainedHistory, rotation
│   │   └── Evolution.lean     -- VersionedSystem (inductive)
│   ├── Isolation.lean         -- IsolationBoundary, ContainerIsolation, VMIsolation
│   ├── Isolation/
│   │   ├── Container.lean     -- Namespace restriction, cgroup bounds, seccomp filtering
│   │   └── VM.lean            -- Hypervisor isolation, virtual channels
│   ├── Policy.lean            -- SystemPolicy, LintRule, SystemInvariant, MigrationConstraint
│   ├── Policy/
│   │   ├── Compliance.lean    -- ComplianceFramework, coverage theorems
│   │   └── CI.lean            -- SafetyCheck (DFA), LivenessCheck (Buchi), CI bridge types
│   └── Protocol.lean          -- Abstract protocol definition (roles, messages, properties)
```

## Relationship to Existing SWELib Modules

This framework doesn't replace existing modules — it provides the scaffolding to compose them:

- `Networking.Http` defines HTTP semantics → Node action labels for HTTP servers
- `Networking.Tcp` → `reliableFIFO` channel process with connection state machine
- `Networking.Udp` → `lossyUnordered` channel process
- `Networking.Tls` → channel wrapper adding confidentiality/integrity properties
- `Distributed.Consensus.Raft` → Protocol instance running in a System configuration
- `Distributed.TwoPhaseCommit` → coordinator + participant Nodes composed with CCS
- `Distributed.CAP` → theorem about System properties under partitionable topology
- `Db.ConnectionPool` → linear resource within a Node
- `Db.Sql` → query semantics used by Migration for schema evolution
- `Cloud.K8s` → K8s Container maps to Node, Pod maps to co-located NodeSet, Deployment maps to replicated NodeSet
- `Cloud.Oci` → ContainerStatus IS the container Node's LTS state type; canTransition IS the transition relation
- `OS.Namespaces` → namespace isolation maps to CCS channel restriction
- `OS.Cgroups` → cgroup limits constrain reachable state space
- `OS.Seccomp` → seccomp filters restrict action alphabet
- `OS.Capabilities` → capability sets restrict action alphabet
- `OS.Systemd` → unit state machine is an LTS; informs HealthState and ShutdownPolicy
- `OS.Process` → process table is the internal structure of container refinements
- `OS.Memory` → linear resource management within a Node

## Key Theorems to Target

### Node level
- A stopped Node produces no output actions
- Health state transitions are monotonic during shutdown
- Dependency declarations are complete (no undeclared output channels)
- Bisimilar substitution preserves all HML properties (congruence, from CSLib)

### Network level
- Standard channels have their declared properties (reliableFIFO is Reliable AND FIFO AND NonDuplicating)
- Replacing a channel with a bisimilar one preserves all System properties
- Network reliability constrains achievable consistency

### System level
- System with single-point-of-failure is not fault-tolerant
- Removing a Node preserves safety iff quorum still holds
- Parallel composition is commutative, associative, has identity
- Every SystemProperty decomposes into Safety intersection Liveness (Alpern-Schneider)

### Migration level
- Adding an optional field with a default is always backward compatible (simulation preserved)
- Expand-then-contract schema migration preserves data integrity
- If migration is backward + forward compatible, MixedVersionState is safe for any traffic split
- Compaction soundness: incremental chain can always be collapsed into direct endpoint proof

### Isolation level
- Container and VM exposing the same interface are weakly bisimilar at System level
- Containers on different cgroups with enforced limits have independent failure (conditioned on kernel liveness)
- VMs have independent failure (conditioned only on hypervisor liveness)
- Seccomp-filtered container simulates the unfiltered version

### Policy level
- Policy admits evolution (not a dead end)
- Policy is internally consistent (no contradictions)
- Policy covers compliance framework X (theorem, not claim)

## Extension Points

The framework is parameterized for future capabilities:

- **Timed models**: NodeAction becomes (NodeAction x Time); bounded latency, partial synchrony (DLS model), timeouts
- **Probabilistic models**: LTS becomes probabilistic LTS; failure rates, SLA modeling, quantitative risk
- **Dynamic topology**: Pi-calculus for channel mobility; service discovery, connection handoff, load balancer redirect
- **Graph algorithms**: constructive SPOF detection, blast radius computation, incremental checking
- **Fairness**: explicit fairness parameters on liveness properties; strong/weak fairness definitions

Each extension plugs into existing type parameters — the Node, System, and Network definitions stay structurally the same.

## Open Questions

1. **Granularity of System extraction:** How detailed should the bridge from code to formal System be? Parse every line of code, or just key artifacts (schemas, API specs, configs)?

2. **Decidability boundary in practice:** HML over finite-state LTS is decidable. Over infinite-state (unbounded data), it's not. How aggressively should we abstract data away for CI-time checking?

3. **Incremental checking:** Can blast radius analysis (graph algorithms) make CI checks scale to large systems?

4. **Compositionality across teams:** If two teams independently evolve subsystems, do the migrations compose? CCS congruence says yes for bisimilar changes — what about non-bisimilar ones?

5. **Partial synchrony without time:** The biggest current gap. Without timed CCS, we can't properly express the DLS model (Global Stabilization Time). Parameterize abstractly for now.
