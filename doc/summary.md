# SWELib: A Formal Library for Software Engineering

## What Is SWELib?

SWELib is a comprehensive formal library written in Lean 4 that mechanizes the
concepts of modern software engineering — protocols, data formats, distributed
systems, databases, cloud infrastructure, operating systems, security, and
system evolution — into machine-checkable definitions, theorems, and proofs.

It currently spans over 2,500 Lean files organized across 11 top-level domains,
ranging from JSON pointer arithmetic and URI parsing to Kubernetes workload
specifications, SQL formal semantics, TLS handshake state machines, and
distributed consensus properties. Its ambition is not to verify any single
program, but to build a reusable, auditable foundation of formally stated
knowledge about how software systems work.

The key claim of SWELib is simple: the concepts that working software engineers
deal with every day — HTTP requests, database transactions, rolling deploys,
TLS certificates, container orchestration — are not informal folklore. They are
precise mathematical objects with precise properties, and those properties can
be stated and checked in a proof assistant. SWELib is the library that does this.


## The Problem: Why Formalize Software Engineering?

Formal verification has a long and successful history in hardware design,
cryptographic protocols, compilers, and operating system kernels. These are
areas where a single implementation is verified against a specification,
typically from the bottom up: you write the code, you write the spec, you prove
the code meets the spec.

But the vast majority of software engineering does not look like this. A typical
production system is not one program — it is dozens or hundreds of components,
written in different languages, maintained by different teams, communicating
over networks, deployed incrementally, failing partially, and evolving
continuously. The interesting properties are not about any single component in
isolation. They are about composition, interaction, evolution, and failure:

- Does a rolling deploy preserve safety when half the fleet is on v1 and half
  is on v2?
- If a service adds a new field to its API response, does every downstream
  consumer handle it gracefully?
- Is a schema migration forward-compatible but not rollback-safe?
- Does the circuit breaker actually prevent cascading failure, or does it just
  shift the failure mode?

These questions are not addressed by verifying individual programs. They require
a different kind of formal artifact: not verified implementations, but verified
*specifications* of the concepts and abstractions that software engineers
reason about informally every day.


## The Approach: Top-Down Specification, Not Bottom-Up Verification

SWELib's approach inverts the traditional direction of formal methods.

**Bottom-up verification** starts with concrete code and works upward: you have
an implementation, you write a specification, and you prove the implementation
satisfies the specification. This is the approach of projects like seL4
(verified OS kernel), CompCert (verified C compiler), and CertiKOS (verified
concurrent OS). It produces extremely high assurance for the specific artifact
verified, but the verification is tightly coupled to the implementation. Change
the code, and the proofs must change too.

**Top-down specification** starts with standards and abstractions and works
downward: you formalize RFC 9110 (HTTP), RFC 793 (TCP), FIPS 180-4 (SHA-2),
the SQL standard, the Kubernetes API conventions, the POSIX socket interface —
and you state their properties as theorems in a proof assistant. The
specifications exist independently of any implementation. They are the
*contracts* that implementations must satisfy, not proofs that any particular
implementation does.

This distinction matters because it determines what questions you can ask:

| Question | Bottom-Up | Top-Down |
|----------|-----------|----------|
| Does *this* implementation conform to the spec? | Yes (that's the whole point) | Only with bridge axioms |
| Can two specs be safely composed? | Not directly | Yes (bisimulation, simulation) |
| Is a migration between spec versions safe? | Not directly | Yes (compatibility relations) |
| Does the spec itself have desirable properties? | Sometimes | Yes (meta-theorems) |
| Can the spec be reused across implementations? | No (tied to one impl) | Yes (that's the whole point) |

SWELib is a top-down project. It formalizes the *concepts*, not the *code*. The
payoff is generality: a formal specification of HTTP semantics applies to every
HTTP implementation, not just one. A formal statement of ACID properties applies
to every database that claims to be ACID-compliant. A bisimulation proof between
two versions of a service spec applies regardless of what language the service
is written in.


## Architecture: Two Layers, One Trust Boundary

SWELib is organized into two sharply separated layers:

### Layer 1: `spec/` — Pure Formal Specifications

The spec layer is a Mathlib-like artifact: pure Lean 4 definitions, structures,
inductive types, theorems, and proofs. It has no IO, no FFI, no side effects,
no external dependencies beyond Mathlib. It is self-contained and auditable.

The spec layer is organized into 11 domains:

- **Basics** — Data formats and encodings (JSON, CSV, XML, YAML, TOML, Protobuf,
  Regex, Base64, UUID, Semver, URI, Time)
- **Foundations** — Abstract compositional framework (LTS, Node, Network, System)
- **Networking** — Protocol specifications (TCP, HTTP, HTTPS, TLS, DNS, SSH,
  WebSocket, REST, Proxy)
- **Distributed** — Distributed systems primitives (consensus, clocks, CRDTs,
  consistency models, message queues, sagas, circuit breakers, CAP theorem)
- **Db** — Database formalization (SQL formal semantics with three-valued logic
  and bag semantics, connection pools, transactions, schema migrations)
- **Cloud** — Cloud infrastructure (Kubernetes primitives and invariants, Docker,
  OCI, Terraform, GCP IAM)
- **OS** — Operating system concepts (sockets, memory, cgroups, seccomp,
  namespaces, systemd, signals, process lifecycle)
- **Security** — Security specifications (hashing, HMAC, JWT, PKI, encryption,
  TLS certificates, IAM, CORS, OAuth, RBAC)
- **Observability** — Monitoring concepts (logging, metrics, tracing, alerting)
- **Cicd** — System evolution (migrations with mixed-version state, change
  classification, zero-downtime deploy properties)
- **Integration** — Cross-cutting composition theorems

### Layer 2: `impl/` — Executable Implementations

The impl layer imports the spec layer and provides executable code with FFI
bindings to real C libraries (OpenSSL, libpq, libcurl, libssh2). It is
organized into:

- **Bridge/** — Axioms asserting that external functions satisfy spec properties.
  Every bridge axiom has a `-- TRUST: <issue-url>` comment tracking its audit
  status. This is the *only* place where unproven trust assumptions live.
- **Ffi/** — `@[extern]` declarations mapping Lean functions to C shims.
- Domain directories mirroring the spec layer, containing executable
  implementations that use spec types as their contracts.

### The Trust Boundary

The critical architectural decision is that all trust assumptions are
*clustered* in `impl/SWELibImpl/Bridge/`, not scattered throughout the codebase.
When you audit SWELib, you audit exactly one directory. Everything in `spec/` is
machine-checked. Everything in `Bridge/` is an explicit assumption. Everything
else in `impl/` follows from those two.

This creates a layered trust model:

1. **Mathlib** — trusted (community-maintained, widely reviewed)
2. **spec/** — machine-checked (Lean kernel verifies all proofs)
3. **Bridge/** — explicitly assumed (each axiom tracked and auditable)
4. **impl/** — testable (executable code that can be run against real systems)


## The Foundations Framework: LTS, Nodes, Networks, Systems

The theoretical core of SWELib is the Foundations framework, which provides a
unified formalism for reasoning about composed systems at any scale.

### Labeled Transition Systems (LTS)

The primitive building block is the Labeled Transition System: a set of states,
a set of labeled actions, a transition relation, and an initial state. This is
the universal state machine model from concurrency theory (Milner 1989, Lynch
1996). SWELib defines LTS with:

- **Reachability** — inductive definition of states reachable from initial
- **Finite traces** — sequences of (state, action, state) triples
- **Deadlock** — states with no enabled transitions
- **Determinism** — at most one successor per (state, action) pair
- **Bisimulation** — the gold standard of behavioral equivalence: two LTS are
  bisimilar if related states can match each other's transitions step-for-step
- **Forward simulation** — one-directional: every step in the concrete system
  can be matched by the abstract system

Bisimulation is the key tool. Two systems are bisimilar if no external observer
can distinguish them by any sequence of interactions. This is strictly stronger
than trace equivalence (same observable sequences) because it also preserves
branching structure — the *choices* available at each state, not just the
outcomes.

### Nodes

A **Node** is an isolated execution environment formalized as an LTS
parameterized by action type and state type. Nodes are level-agnostic: a Node
can be a container, a VM, a bare-metal machine, a phone, a CPU pipeline stage,
or an entire cloud region. The definition does not change.

Actions are classified as:
- **Input** — environment-controlled, cannot be refused (from Lynch's I/O
  Automata)
- **Output** — Node-controlled
- **Internal** — invisible tau transitions

Nodes have structural roles (listeners, dependencies), functional roles
(database, API server, load balancer), health states (healthy, degraded,
draining, stopped), and failure behaviors. Crucially, failure behavior is not
declared as an enum — it is *proved as a predicate* about the Node's LTS
transitions. A Node is crash-stop if, once it enters a crashed state, no
further transitions are possible. This is a theorem, not a tag.

### Networks

The **Network** is the communication medium between Nodes. It is the central
variable that determines what level of abstraction you are modeling. Each
directed edge between Nodes is a **ChannelProcess** — itself an LTS that
mediates communication with specific properties:

- **Synchronous** — direct CCS synchronization (CPU pipelines)
- **Reliable FIFO** — buffer process preserving order and guaranteeing delivery
  (TCP-like)
- **Lossy unordered** — nondeterministic drop/deliver (UDP-like)
- **Fair lossy** — lossy but eventually delivers with retries

Network properties (Reliable, FIFO, Lossy, NonDuplicating) are theorems about
the channel process's LTS, not declared tags. Different edges can have
different channel processes. The same framework spans all scales:

| Level | Medium | Synchrony | Reliability |
|-------|--------|-----------|-------------|
| CPU pipeline | Forwarding network | Synchronous | Perfect |
| Process-to-process | Shared memory | Synchronous | Reliable |
| Same-pod containers | Localhost | Near-synchronous | Reliable |
| Same-datacenter | LAN | Partially synchronous | Mostly reliable |
| Cross-region | WAN | Asynchronous | Lossy |
| Server-to-phone | Internet + cellular | Asynchronous | Lossy, variable |

### Systems

A **System** is a parallel composition of Nodes communicating over a Network.
In CCS (Calculus of Communicating Systems) terms:

```
System = (Node₁ | Channel₁₂ | Channel₂₁ | Node₂) \ internal_channels
```

A System has exactly two fields: a NodeSet and a Network topology. The CCS
term and induced LTS are *derived*, not stored. Because a System is itself an
LTS (via CCS operational semantics), all LTS-based tools — bisimulation, HML
(Hennessy-Milner Logic), trace equivalence — apply to Systems for free.

A System can also appear as a single Node at a higher level via refinement.
This is the zoom relationship: you can "open up" a Node and see that it is
internally a System of sub-Nodes, connected by a weak bisimulation to the
abstract Node interface. Bisimulation is a congruence for CCS operators, so
replacing a Node with a bisimilar one in any System preserves all properties.

Key compositional properties inherited from CCS:
- Parallel composition is commutative, associative, with identity
- Bisimilar substitution preserves all System properties (congruence)
- Safety/liveness decomposition (Alpern-Schneider): every property is the
  intersection of a safety property and a liveness property


## Migration and System Evolution

The most novel aspect of SWELib's framework is its treatment of system
evolution. A real system is not a static snapshot — it is a chain of versions
with migrations between them. SWELib formalizes this directly.

A **Migration** replaces some Nodes with new versions. The critical concept is
the **MixedVersionState**: during a rolling deploy, some Nodes are on v1 and
some are on v2, and they must coexist safely. This is formalized as a CCS
parallel composition of old and new Nodes.

Bisimulation quantifies migration impact:
- **Bisimilar** (v1 ~ v2): migration is invisible to observers, zero risk
- **Weakly bisimilar**: internal behavior changed, external interface identical
- **Not bisimilar**: observable behavior changed — the LTS diff characterizes
  exactly what changed

Compatibility is formalized through simulation relations:
- **Backward compatible**: v2 simulates v1 (every old behavior preserved)
- **Forward compatible**: v1 can handle v2's new outputs
- **Wire compatible**: v1 and v2 can synchronize on shared CCS channels

This connects to CI integration: tooling can extract System v2 from code
artifacts (protobuf, SQL schemas, OpenAPI, K8s manifests), diff against v1 to
produce a Migration, and run formal checks. "Our policy satisfies SOC2" becomes
a theorem, not a claim in a slide deck.


## Formalization Patterns

SWELib uses several recurring patterns to capture different kinds of software
engineering knowledge:

### Pattern 1: Algebraic Data Types + Properties

For data formats and structures, SWELib defines inductive types with operations
and proves properties about those operations. JSON Pointer, for example, defines
a pointer as a list of tokens, with parse/resolve operations and a composability
theorem: resolving a concatenated pointer is the same as resolving each part
sequentially.

### Pattern 2: State Machines + Transitions

For protocols, SWELib defines states as inductive types and transitions as
relations. TCP has 11 states (closed, listen, synSent, established, etc.) with
transition rules that capture the RFC 793 state machine. TLS defines handshake
states and record protocol transitions.

### Pattern 3: Axiomatized External Behavior

For cryptographic primitives and system calls, SWELib uses opaque axioms.
SHA-256 is declared as `axiom sha256Hash : ByteArray → HashOutput` — the
function exists and has the right type, but its implementation is external
(via FFI to OpenSSL). Only the interface and wrapper semantics are defined
computably.

### Pattern 4: Formal System Properties

For distributed systems, SWELib defines property structures that capture
correctness criteria. A consensus problem has validity (decided values were
proposed), agreement (non-faulty processes decide the same value), termination
(non-faulty processes eventually decide), and integrity (each process decides at
most once). The FLP impossibility theorem, Lamport clocks, vector clocks, and
various consistency models are all formalized.

### Pattern 5: Standards-First Specifications

Every module documents its authoritative sources. URI parsing references
RFC 3986. HTTP semantics reference RFC 9110. Hashing references FIPS 180-4.
SQL semantics build on a CPP'19 mechanization with three-valued (Kleene) logic
and bag semantics (multisets, like real databases). The specifications capture
the standard, not any particular implementation's interpretation of it.


## Theoretical Significance

### Capturing Composition

The central theoretical contribution of SWELib is demonstrating that the
composition of software systems — the thing that makes them hard — can be
formally captured using established tools from concurrency theory. CCS,
bisimulation, LTS, and simulation relations were developed in the 1980s and
1990s for reasoning about concurrent processes. SWELib applies them to the
artifacts that modern software engineers actually build: microservices,
databases, load balancers, container orchestrators, CI/CD pipelines.

This is not a new theory. It is the application of existing theory to a domain
that has historically been treated as too messy, too large, or too fast-moving
for formal methods. SWELib's bet is that the messiness is surface-level: the
underlying concepts have precise structure, and that structure can be captured.

### The Specification Reuse Argument

In bottom-up verification, proofs are coupled to implementations. If you verify
a C implementation of a TLS library, the proof says nothing about a Rust
implementation of TLS. You must verify again from scratch.

In top-down specification, the specification is the reusable artifact. SWELib's
formalization of TLS handshake semantics applies to every TLS implementation.
The bridge axiom that connects a specific implementation (say, OpenSSL via FFI)
to the spec is the *only* implementation-specific part. Different
implementations require different bridge axioms, but the same spec, the same
theorems, and the same composition results.

This means the formal investment compounds over time. Each new module added to
SWELib is immediately composable with every existing module. A formalization of
a load balancer Node can be composed with the existing HTTP, TCP, and TLS
specs to reason about the full stack. A formalization of a message broker can
be composed with existing distributed systems primitives to reason about
ordering guarantees in a pub/sub architecture.

### Evolution as a First-Class Concept

Most formal methods treat systems as static. You verify a snapshot. SWELib
treats evolution — versioning, migration, mixed-version states, backward and
forward compatibility — as first-class formal concepts. This matters because
the hardest bugs in production systems are often not in any single version but
in the *transition* between versions: the rolling deploy where old and new code
coexist, the schema migration that is safe going forward but not rolling back,
the API change that is backward-compatible in isolation but breaks when combined
with a concurrent change in another service.

By formalizing MixedVersionState and compatibility relations, SWELib makes these
questions answerable with the same rigor as traditional safety properties.

### Isolation as Refinement

SWELib's treatment of isolation boundaries — containers, VMs, bare metal — is
elegant: isolation is a property of the *refinement*, not the abstract
interface. System-level theorems (like "consensus is safe with fewer than n/2
crash-stop failures") hold regardless of whether nodes are containers, VMs, or
physical machines. The isolation mechanism only matters for whether the crash-
stop assumption is *justified* — whether a container crash is truly independent
of other containers on the same host.

This cleanly separates concerns: system architects reason at the abstract Node
level, infrastructure engineers reason about whether the refinement justifies
the assumptions, and the formal framework keeps the two aligned.


## Current State and Roadmap

SWELib is an active project with substantial coverage across its 11 domains.
Many modules are well-developed (TCP state machines, SQL formal semantics,
Kubernetes primitives, distributed consensus), while others are stubs or
partially complete (observability, some cloud services). Proofs use `sorry` in
many places, tracked via GitHub issues tagged `sorry-debt`.

The roadmap targets formalization of major infrastructure components as Nodes
and Systems: load balancers, service meshes, message brokers, caches, service
discovery, autoscalers, CI/CD pipelines, secret management, and distributed
locks. These are the components where the composition and failure story is the
main point — where SWELib's framework provides the most leverage.

The long-term vision is a library where a software engineer can formally specify
a distributed system architecture, state its desired properties, check that
migrations preserve those properties, and connect the specifications to real
implementations through explicit, auditable trust boundaries. Not verified code,
but verified *understanding* — a machine-checked body of knowledge about how
software systems behave when composed, when they fail, and when they change.
