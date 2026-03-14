# Representation Decisions

This document logs the key choices about how to represent software engineering concepts in Lean, and the rationale behind them.

## Format

Each decision includes:
- **Title:** What concept or representation choice
- **Status:** Decided / Under Review / Deprecated
- **Date:** When decided
- **Context:** Why the decision was needed
- **Decision:** What we chose and why
- **Alternatives:** What we considered but rejected
- **Implications:** What this means for future work

## Decisions

### D-001: HTTP Request/Response as Records

**Status:** Decided
**Date:** 2026-03-14
**Context:** HTTP is a fundamental protocol. We need to represent HTTP requests and responses formally.

**Decision:**
- `SWELib.Networking.Http.Request` is a record with fields: method, uri, headers, body
- `SWELib.Networking.Http.Response` is a record with fields: status, headers, body
- Headers are modeled as a list of name-value pairs (not a map)

**Rationale:**
- Record syntax is familiar and compositional
- List-of-pairs allows duplicate headers (valid in HTTP/1.1)
- Name case-insensitivity is handled at the protocol layer, not the type layer

**Alternatives Considered:**
- Map-based headers: loses information about duplicate headers
- Named tuples with named accessors: same as records, less syntax

**Implications:**
- Code working with headers must handle case-insensitivity explicitly
- Serialization must preserve header order
- Streaming implementations must build records incrementally

---

### D-002: JSON as Inductive Type

**Status:** Decided
**Date:** 2026-03-14
**Context:** JSON appears in many systems (APIs, configs, logs). Need a clean formal model.

**Decision:**
- `SWELib.Basics.Json.Value` is an inductive type with constructors:
  - `null : Value`
  - `bool (b : Bool) : Value`
  - `number (n : JsonNumber) : Value`
  - `string (s : String) : Value`
  - `array (a : Array Value) : Value`
  - `object (o : Array (String × Value)) : Value`

**Rationale:**
- Inductive types align with RFC 8259 definition
- Recursive structure naturally models JSON nesting
- Enables structural induction proofs

**Alternatives Considered:**
- String representation: loses structure, hard to prove properties
- Sum types with separate constructors: same as inductive

**Implications:**
- Parsing produces an inductive tree
- Serialization is tree-to-string
- Schema validation operates on the inductive structure

---

### D-003: TCP as State Machine

**Status:** Decided
**Date:** 2026-03-14
**Context:** TCP has complex lifecycle (LISTEN, ESTABLISHED, CLOSE_WAIT, etc.). Need to model legality.

**Decision:**
- `SWELib.Networking.Tcp.State` is an inductive enum: CLOSED, LISTEN, SYN_SENT, ESTABLISHED, FIN_WAIT_1, FIN_WAIT_2, CLOSE_WAIT, CLOSING, TIME_WAIT, LAST_ACK
- Operations like `send`, `receive`, `close` are only defined on valid states
- Validity is tracked via dependent types

**Rationale:**
- State machine captures TCP's temporal constraints
- Dependent types prevent invalid operations
- Aligns with RFC 9293

**Alternatives Considered:**
- Pre/post-condition pairs: doesn't prevent mistakes at type-check time
- Boolean flags: hard to reason about combinations

**Implications:**
- Proofs about TCP require state reasoning
- FFI wrappers must track state on the Lean side
- Code can type-safely enforce protocol order

---

### D-004: Raft as Refinement

**Status:** Under Review
**Date:** 2026-03-14
**Context:** Raft consensus is complex but important. Should it be a separate spec or a refinement of general consensus?

**Decision (Draft):**
- `SWELib.Distributed.Consensus.Raft` is a concrete refinement of `SWELib.Distributed.Consensus.Consensus`
- Raft adds specific invariants: leader election, log replication, safety properties
- Proofs about Raft refine proofs about general consensus

**Rationale:**
- Reuses general consensus properties
- Allows comparing consensus algorithms
- Supports reasoning about hybrid systems

**Alternatives Considered:**
- Standalone Raft spec: less reuse, harder to compare algorithms
- Raft as a tactic/computation: mixes proof and algorithm

**Implications:**
- General consensus must be abstract enough to admit many refinements
- Raft proofs may be lengthy but composable

---

## RFC Template

For proposing changes, see [rfcs/0001-template.md](rfcs/0001-template.md).

## Feedback

Representation decisions are discussed in GitHub issues. If you have feedback or want to propose a change, open an issue tagged `representation-rfc`.
