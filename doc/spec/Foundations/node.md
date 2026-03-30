# Sketch: Node (formerly "Component", originally "Process")

## Naming Decision

**Node** was chosen after evaluating several alternatives:

- **Process** — rejected because it collides with OS processes, which are a *sub-concept* of what we're modeling (processes live inside Nodes)
- **Server** — rejected because it implies serving requests; a phone running LinkedIn isn't a "server" but it participates in the system identically
- **Computer/Machine** — rejected because it implies hardware; containers aren't machines
- **OS Instance** — rejected because it describes the mechanism, not the concept, and is ambiguous about whether containers qualify
- **Host** — rejected because "Docker host" means the machine running containers, not the container itself
- **Component** — rejected as too generic; could mean anything
- **Actor** — considered seriously (Hewitt, Erlang pedigree) but traditionally refers to a much more granular unit (individual lightweight processes), creating a granularity mismatch

**Node** is the standard distributed systems term (Lynch, Lamport, Agha). It doesn't prejudge role — clients, servers, phones, containers, VMs are all nodes. The one conflict is with Kubernetes, where "Node" means a worker machine (VM/physical) that runs Pods. This is handled by namespacing (`Systems.Node` vs `Cloud.K8s.Node`) and the mapping between them is itself useful to formalize (a K8s Container maps to a Systems.Node; a K8s Pod maps to a co-located group of Systems.Nodes with shared network).

## Hierarchy

- **System** = collection of Nodes + Network + FailureModel
- **Node** = isolated execution environment. Owns a process tree. Can be a container, VM, bare metal machine, phone, etc. Defined by its isolation boundary, not its hardware.
- **Process** = sequential unit of computation within a Node. Has state, does I/O. Can spawn child processes (still scoped to the same Node).
- **Thread** = concurrent execution within a Process. Shares the process's memory.

A Node is defined by *what's shared inside it* (process namespace, filesystem, cheap IPC) and *what's isolated between Nodes* (failure independence, separate network identity typically).

**Two levels of role** (previously conflated as `ComponentKind`):
1. **Structural role**: what it *is* (has listeners → can accept connections, has no listeners → pure client or worker)
2. **Functional role**: what it *does in the system* (database, API server, load balancer, mobile client)

## Theoretical Foundation: CSLib

A Node is formalized as a **Labeled Transition System** (LTS) from CSLib, with its interface described using concepts from **CCS** (Calculus of Communicating Systems) and **I/O Automata** (Lynch).

### Node as LTS

At its core, a Node is an LTS — a state machine with labeled transitions:

```
-- CSLib provides this:
structure LTS (State : Type) (Label : Type) where
  Tr : State → Label → State → Prop

-- A Node is an LTS with a specific label alphabet
-- Actions are typed: input (can't refuse), output (Node controls), internal (invisible)
def Node (S : Type) := LTS S NodeAction
```

The label alphabet `NodeAction` captures everything a Node can do:
- **Input actions**: receiving a network message, receiving a signal
- **Output actions**: sending a network message, writing to a log
- **Internal actions (τ)**: internal state transitions, intra-process communication

The input/output distinction comes from I/O Automata (Lynch). Input actions cannot be refused — the environment controls them. This models reality: a server can't refuse to receive a TCP SYN.

### Node as CCS Process

For composition, a Node is also a **CCS process** with internal channels restricted:

```
-- A Node with two internal processes communicating on channel `query`:
Node = (RequestHandler | DatabaseClient) \ query
```

The restriction operator `\` hides the internal `query` channel. From outside, you only see the Node's external interface (e.g., `recv_http_request`, `send_http_response`). The internal communication between RequestHandler and DatabaseClient is invisible.

This maps to the hierarchy:
- **Processes within a Node** = CCS sub-processes composed with `|` (parallel)
- **Internal communication** = channels restricted with `\`
- **External interface** = unrestricted channels (visible to other Nodes)

### Node Refinement (Zoom)

A Node is opaque at the System level, but can optionally be "opened up" to reveal its internal structure. This is formalized as a **bisimulation** (from CSLib) or **simulation relation** (from Lynch):

```
structure NodeRefinement where
  node : Node S                     -- the abstract view (single LTS)
  internal : System                  -- what's inside (parallel composition of processes)
  equiv : WeakBisimulation           -- proof that internals match the interface
           node.asLTS
           internal.asLTS
```

**Weak bisimulation** (ignoring τ/internal steps) is the right equivalence here — internal reorganization shouldn't affect the external view. CSLib provides `LTS.Bisimulation` with both strong and weak variants.

The key theorem (from CSLib): **bisimulation is a congruence for CCS operators**. This means if you replace a Node with a bisimilar one in a System, the whole System remains bisimilar. Modular reasoning works.

**This is NOT mutual recursion.** We considered making Node and System mutually recursive (a Node contains a System, a System contains Nodes). We rejected this because:

1. The communication mediums aren't interchangeable — shared memory (intra-Node) gives atomicity and nanosecond latency; network (inter-Node) gives none of that. Collapsing them erases the distinction that makes distributed systems theory meaningful.
2. It defeats compositionality — you'd need to crack open every Node to reason about a System.
3. It's turtles all the way down with no benefit — processes contain threads, threads contain instructions, instructions contain pipeline stages.

Instead, the refinement/zoom relationship is optional and one-directional: you *can* look inside a Node and see a sub-System, but you don't have to. The `NodeRefinement` structure captures this cleanly.

## Level Agnosticism

The Node/System abstraction is level-agnostic. An LTS makes zero assumptions about what states and actions represent, so the same framework works at any granularity:

**Zooming in (hardware):**
- A RAM stick is a Node. States = memory contents. Actions = read/write at address. Network to CPU = memory bus.
- A CPU is a Node. States = registers + pipeline. Actions = fetch/decode/execute. Network to RAM = memory bus.
- A CPU pipeline stage is a Node. Actions = accept instruction / forward result.

**Zooming out (large systems):**
- ClickHouse (materialized view cloud DB) is a Node. Actions = receive query / return result / ingest data.
- A futures exchange is a Node. States = order book. Actions = receive order / emit fill / emit market data.
- An entire cloud region could be a Node if you're modeling multi-region.

Everything can be a Node. The question isn't whether it *can* be modeled this way — it's whether it's *useful* at that level. What actually changes across levels is not the Node or System definition — it's the **Network** (sketch 05). The network properties (synchrony, reliability, latency, ordering) are what make reasoning about CPUs different from reasoning about microservices. See sketch 05 for the full treatment.

## Inbound/Outbound at Node Level vs Process Level

**Abstract inbound/outbound traffic is defined at the Node level.** This is the external interface other Nodes see — which ports are open, what messages are accepted, what responses are produced.

**Connections to specific processes are an internal concern.** In Linux, a TCP connection is bound to a specific socket file descriptor, and fds are per-process. Only the owning process (or children that inherited via `fork()`, or recipients of `sendmsg()` fd-passing) can read from a connection. But this is an implementation detail that belongs in the NodeRefinement, not the abstract interface.

```
-- Node level (abstract): "I accept SQL on port 5432"
-- This is what other Nodes see
AbstractPostgres = recv_sql . send_result . AbstractPostgres

-- Refinement level: which process handles which connection
-- Only matters when proving things about Postgres internals
PostgresInternals = (Postmaster | Worker | Worker | BgWriter) \ dispatch \ shared_buffers
-- Postmaster accepts, dispatches fd to a Worker via internal channel
```

This mirrors how the abstraction is used: someone building a System with Postgres doesn't care which internal process handles their query. They care that "send SQL, get result" works. The fd-per-process story matters only to whoever writes the NodeRefinement proof.

## Stability of Abstract Node Definitions

The abstract Node interface should be **coarse and stable**. Bisimulation protects against internal churn (you can refactor internals freely as long as the refinement proof holds), but it cannot protect against changes to the abstract interface itself.

If you change the abstract Node's LTS (e.g., "PostgreSQL should now return an error on invalid SQL instead of silently dropping"), then:
- All System-level theorems depending on the old behavior need re-examination
- All NodeRefinement proofs targeting the old interface are invalidated
- All bisimulation proofs are about the wrong thing

**Principle: abstract Nodes capture the interface contract, not behavior details.** The coarser the actions, the more stable the spec. Details belong in refinements.

```
-- STABLE (good abstract Node):
-- "receives well-formed SQL, returns result set or error,
--  respects transaction isolation level"

-- FRAGILE (bad abstract Node):
-- "receives SQL, parses with specific precedence, chooses query plan
--  based on statistics, executes with specific buffer pool eviction"
```

The architecture supports multiple refinement layers without propagating changes upward:

```
Abstract Node (stable, coarse)     ← System theorems depend on this
       ≈ (bisimulation)
Refinement layer 1 (detailed)      ← Can change freely
       ≈ (bisimulation)
Refinement layer 2 (more detail)   ← Can change freely
       ≈ (bisimulation)
Actual C code (axiomatized)        ← Bridge layer
```

Each layer can thrash independently. If you find yourself wanting to change the abstract Node frequently, the abstraction is at the wrong level — push detail down into a refinement.

## Key Types to Formalize

- **Node α S**: An LTS parameterized by action type α and state type S. The action type is a parameter (not fixed) so different domains use different alphabets — a database Node has `Query sql | Result rows | Error msg`, a futures exchange has `SubmitOrder order | Fill fill | MarketData snapshot`. Same framework, different alphabets.
- **NodeAction α**: Wrapper classifying raw actions α as Input, Output, or Internal (τ). The I/O distinction comes from Lynch's I/O Automata.
- **Listener**: Abstract inbound interface at the Node level. Modeled as a set of input action channels the Node accepts on. Internal dispatch to processes is a refinement concern.
- **Dependency**: An outbound connection a Node needs. Modeled as a set of output action channels the Node may send on. Typed so you can express "this Node depends on a Node with role Database."
- **HealthState**: Healthy, degraded, draining, stopped. Transition rules form their own sub-LTS.
- **ShutdownPolicy**: How a Node shuts down — modeled as a strategy (sequence of actions: stop accepting → drain in-flight → force kill). With timed models, this adds timeout bounds.
- **ResourceLimits**: Connection limits, memory bounds, file descriptor limits. These constrain the state space of the Node's LTS.
- **NodeRole**: Split into StructuralRole (has listeners? has dependencies? both? neither?) and FunctionalRole (database, API server, load balancer, mobile client, etc.).
- **Failure transitions**: Failure behavior is part of the Node's LTS, not System-level metadata. A crash-stop Node includes `crash → terminal` transitions. A crash-recovery Node includes `crash → stopped → recover → initial`. Byzantine includes transitions to unconstrained states. `Node.isCrashStop`, `Node.isCrashRecovery`, `Node.isByzantine` are predicates proved about the LTS, not declared enums. This allows heterogeneous failure models in the same System — the database is crash-recovery, the cache is crash-stop — without a System-level field.

## Extension Points for Future Models

The design is parameterized so richer models can be plugged in later with minimal code changes:

```
-- Today: untimed, nondeterministic
Node S := LTS S NodeAction

-- Future: timed (actions carry timestamps)
-- Change: NodeAction becomes (NodeAction × Time), LTS definition unchanged
TimedNode S := LTS S (NodeAction × Time)

-- Future: probabilistic (transitions have probabilities)
-- Change: new type replacing LTS.Tr with a distribution
-- Node/System definitions stay the same; bisimulation becomes
-- probabilistic bisimulation
ProbNode S := PLTS S NodeAction  -- probabilistic LTS (not yet in CSLib)

-- Future: channel mobility (dynamic topology)
-- Change: use Pi-calculus instead of CCS for composition
-- Node as individual LTS is unchanged; System composition changes
```

The principle: **parameterize over things you don't have yet rather than omitting them.** NodeAction is a type parameter, not a fixed type. The synchronization mechanism is a typeclass, not hardcoded. When timed/probabilistic/mobile models arrive in CSLib, they plug into existing type parameters.

## Key Theorems Sketch

- A stopped Node produces no output actions (HML: `[stopped] ∀a:output. ¬⟨a⟩ true`)
- Health state transitions are monotonic during shutdown (healthy → draining → stopped, no going back)
- A Node with no listeners and no dependencies is inert (bisimilar to `nil`)
- Dependency declarations are complete (Node doesn't perform output actions on undeclared channels)
- If Node A is weakly bisimilar to Node B, replacing A with B in any System preserves all HML properties (congruence — inherited from CSLib)
- A NodeRefinement is valid iff the internal sub-System's observable behavior matches the Node's interface (forward simulation suffices; backward simulation for edge cases)

## Properties via HML and Temporal Logic

Node properties can be stated in Hennessy-Milner Logic (CSLib: `Logics/HML/`):

- **Responsiveness**: `[recv_request] ⟨send_response⟩ true` — "after every request received, a response is possible"
- **Health check availability**: `[τ*] ⟨health_check⟩ true` — "health check is always possible regardless of internal state"
- **Graceful shutdown**: with mu-calculus, `νX. [drain] (μY. ⟨close_conn⟩ Y ∨ [τ] Y)` — "during drain, connections eventually close"

Liveness properties ("every request eventually gets a response") need temporal logic (LTL: `G(request → F response)`) or Büchi automata (CSLib: `Computability/Automata/`). Safety properties ("connection count never exceeds limit") are regular — checkable with DFA.

## Resource Management via Linear Logic

Resources within a Node (connections, file descriptors, memory regions) can be modeled using linear logic (CSLib: `Logics/LinearLogic/`):

- A connection is a linear resource: `acquire ⊸ Connection` (consumes a pool token, produces a connection)
- `release : Connection ⊸ PoolToken` (consumes the connection, returns the token)
- Linearity prevents double-use (use-after-release) and forgetting to release (leak)

This connects to existing SWELib modules: `Db/ConnectionPool`, `OS/Memory`, `OS/FileSystem`.

## Node Behavior via Free Monads

A Node's behavior can be modeled as a free monad (CSLib: `Foundations/Control/Monad/Free`) over its effect type:

```
inductive NodeEffect where
  | send : Channel → Message → NodeEffect
  | recv : Channel → NodeEffect
  | readState : NodeEffect
  | writeState : State → NodeEffect

def NodeBehavior := FreeM NodeEffect
```

This separates "what the Node does" from "how the environment responds." The environment (network model, failure model) is the interpreter/handler. Same Node description, different interpretations:
- Reliable network handler (for specification)
- Lossy network handler (for distributed reasoning)
- Timed network handler (future)

## Relationship to Other Sketches

- **System (sketch 02)** composes Nodes using CCS parallel composition + restriction
- **Migration (sketch 03)** diffs Nodes between versions; bisimulation tells you if the change is observable
- **Policy (sketch 04)** writes HML formulas and temporal logic properties over Nodes and Systems

## Relationship to Existing SWELib Modules

- `Distributed/Core.lean` has `Node` + `NodeTransition` — superseded by this more principled LTS-based definition, but the existing structure maps directly
- `OS/Systemd` — the systemd unit state machine is an LTS; HealthState and ShutdownPolicy are informed by systemd's model
- `OS/Process` — OS processes are the Process level in our hierarchy (within a Node)
- `OS/Memory` — linear resource management within a Node
- `Db/ConnectionPool` — linear resource (connections) managed within a Node
- `Cloud/K8s` — K8s Container maps to Node; K8s Pod maps to co-located Nodes; K8s Node (machine) is the hosting infrastructure

## Source Specs / Prior Art

- **CSLib** (Lean): LTS, CCS, bisimulation, HML — direct formal foundations
- **Nancy Lynch, "Distributed Algorithms"** (1996): I/O automata model, simulation relations
- **Robin Milner, "Communication and Concurrency"** (1989): CCS, equational reasoning, congruence
- **Aceto et al., "Reactive Systems"** (2007): LTS + CCS + HML + bisimulation textbook
- **Erlang/OTP**: supervision trees (Nodes with lifecycle and restart policies)
- **Kubernetes Pod/Container model**: multiple containers sharing network namespace
- **systemd unit model**: already formalized in SWELib, informs HealthState and ShutdownPolicy
- **Actor model** (Hewitt, Agha): core state-machine semantics, message-passing concurrency
