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

### D-002: JSON Representation (Revised)

**Status:** Deprecated → Use Lean.Data.Json
**Date:** 2026-03-14 (original), 2026-03-14 (revised)
**Context:** JSON appears in many systems (APIs, configs, logs). Need a clean formal model. Lean 4's standard library provides `Lean.Data.Json` which already defines a complete JSON inductive type with parser and serializer.

**Decision:**
- Use `Lean.Data.Json` from Lean's standard library instead of defining a custom inductive type
- Higher-level JSON standards (Schema, Pointer, Patch) will be defined in SWELib spec layer on top of `Lean.Data.Json`
- Code layer utilities will use `Lean.Data.Json` for basic JSON operations

**Rationale:**
- `Lean.Data.Json` is maintained as part of Lean, reducing maintenance burden
- Provides proven parser/serializer implementations
- Already used by other parts of SWELib (JWT module)
- Allows focusing SWELib efforts on higher-level JSON standards

**Alternatives Considered:**
- Custom inductive type (original decision): adds maintenance overhead, duplicates existing functionality
- String representation: loses structure, hard to prove properties
- Using external JSON library via FFI: introduces unnecessary trust boundary

**Implications:**
- No need for JSON parsing/serialization bridge axioms
- JSON Schema, Pointer, Patch specs will reference `Lean.Data.Json` type
- Code layer JSON utilities will import `Lean.Data.Json`

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

### D-005: HTTP Method as Inductive with Extension

**Status:** Decided
**Date:** 2026-03-14
**Context:** HTTP methods include 8 standard methods (RFC 9110 Section 9) but the protocol is extensible — registries and applications define custom methods.

**Decision:**
- `SWELib.Networking.Http.Method` is an inductive type with constructors for each standard method (GET, HEAD, POST, PUT, DELETE, CONNECT, OPTIONS, TRACE) plus an `extension (token : String)` constructor.

**Rationale:**
- Named constructors enable direct pattern matching on standard methods without string comparison
- `extension` preserves RFC extensibility — any registered or custom method can be represented
- Properties like `isSafe` and `isIdempotent` are defined by exhaustive match, so the compiler enforces coverage
- Theorem `safe_implies_idempotent` is provable by case analysis on constructors

**Alternatives Considered:**
- String-only representation: loses exhaustiveness checking, properties require string equality guards
- Finite enum without extension: breaks RFC compliance, cannot represent custom methods
- Typeclass-based open method set: over-engineered for a fixed set of 8 + extension

**Implications:**
- Bridge axioms must map between FFI method strings and the inductive
- Extension methods default to non-safe, non-idempotent (conservative)

---

### D-006: HTTP StatusCode as Nat with Range Proof

**Status:** Decided
**Date:** 2026-03-14
**Context:** HTTP status codes are three-digit integers (100–999). There are ~60 registered codes but the space is intentionally open for extension.

**Decision:**
- `SWELib.Networking.Http.StatusCode` is a structure with a `code : Nat` field and a proof `h_range : 100 ≤ code ∧ code ≤ 999`.
- Status class (1xx–5xx) is computed from the code at runtime via `statusClass`.
- Well-known codes are defined as named constants using `by decide` for the range proof.

**Rationale:**
- A finite enum of ~60 codes would be impractical and non-extensible
- The range proof ensures only valid 3-digit codes exist, catching misuse at type-check time
- Computing the class from digits avoids redundant data and keeps the representation minimal
- Named constants (`StatusCode.ok`, `StatusCode.notFound`) provide convenience without limiting the space

**Alternatives Considered:**
- Fin 900 (offset by 100): correct range but awkward arithmetic, less readable
- Inductive with one constructor per code: massive type, not extensible
- Unguarded Nat: permits invalid codes like 0 or 1000

**Implications:**
- Theorems about status code properties (e.g., `interim_no_body`) require Nat reasoning
- Bridge axioms must validate that FFI status codes satisfy the range proof

---

### D-007: YAML as Inductive Representation Graph

**Status:** Decided
**Date:** 2026-03-14
**Context:** YAML 1.2 defines a representation graph with three node kinds (scalar, sequence, mapping). Anchors and aliases are serialization concerns, not part of the abstract data model.

**Decision:**
- `SWELib.Basics.YamlNode` is an inductive type with constructors `scalar`, `sequence`, `mapping`
- Each node carries a `YamlTag` (optional URI) for typing
- Anchors/aliases are omitted — they exist only in the serialization layer

**Rationale:**
- Mirrors the YAML spec's own representation model (§3.2.1)
- Tags as URIs match the YAML tag resolution scheme
- Excluding anchors keeps the spec focused on the data model, not presentation

**Alternatives Considered:**
- Flat key-value model: loses YAML's recursive structure and typed nodes
- Including anchors: mixes serialization with representation, complicates proofs

**Implications:**
- Serialization/deserialization must resolve anchors before producing `YamlNode`
- Tag resolution (core schema → URI) is modeled via constants, not parsing

---

### D-008: XML as Inductive Node Tree

**Status:** Decided
**Date:** 2026-03-14
**Context:** XML documents are trees of typed nodes. The XML Information Set defines the abstract data model.

**Decision:**
- `SWELib.Basics.XmlNode` is an inductive type with constructors: `element`, `text`, `cdata`, `comment`, `processingInstruction`
- Names are namespace-aware via `XmlName` (localName + optional prefix + namespace URI)
- DTD/schema modeling is out of scope

**Rationale:**
- Follows the XML Infoset model directly
- Namespace-aware names prevent ambiguity in multi-namespace documents
- DTDs are rarely used in modern XML processing and would add significant complexity

**Alternatives Considered:**
- String-only representation: loses structure, no well-formedness guarantees
- Including DTD nodes: massive scope increase with little practical value

**Implications:**
- Well-formedness constraints (unique attribute names, element root) are functions, not type-level invariants
- Namespace resolution must happen before constructing `XmlName`

---

### D-009: Regex as Abstract Syntax

**Status:** Decided
**Date:** 2026-03-14
**Context:** Regular expressions need formalization, but a full matching engine is a massive effort. The spec should capture structure, not semantics.

**Decision:**
- `SWELib.Basics.Regex` is an inductive type modeling ERE abstract syntax
- Constructors: `empty`, `char`, `charClass`, `dot`, `seq`, `alt`, `star`, `plus`, `opt`, `group`
- Properties like `isNullable` are defined structurally; no matching semantics

**Rationale:**
- Captures POSIX ERE structure without committing to a matching algorithm
- Structural properties (nullable, has captures) are provable without a matcher
- A matching engine belongs in the code layer, not the spec

**Alternatives Considered:**
- Full matcher formalization: enormous effort, better suited for a dedicated project
- DFA/NFA representation: implementation detail, not specification

**Implications:**
- Code-layer regex engines should parse into this AST
- Matching semantics proofs would extend this spec, not replace it

---

### D-010: UUID as Pair of UInt64

**Status:** Decided
**Date:** 2026-03-14
**Context:** UUIDs are 128-bit identifiers. Lean 4 has `UInt64` but no `UInt128`.

**Decision:**
- `SWELib.Basics.Uuid` is a structure with `hi lo : UInt64`
- Version extracted from bits [51:48] of `hi`, variant from top bits of `lo`
- Nil (all-zero) and Max (all-one) are defined as constants

**Rationale:**
- Two `UInt64` values efficiently represent 128 bits with native arithmetic
- Bit extraction for version/variant uses standard shift-and-mask operations
- Aligns with RFC 9562's bit-layout diagrams

**Alternatives Considered:**
- `ByteArray` of length 16: less efficient for comparisons, no native arithmetic
- `Fin (2^128)`: Lean's `Fin` with huge bounds has poor computational behavior
- Four `UInt32`: more fields, no benefit over two `UInt64`

**Implications:**
- Bridge axioms must convert between FFI byte representations and the `hi`/`lo` pair
- Bit-level proofs require reasoning about `UInt64` arithmetic

---

## RFC Template

For proposing changes, see [rfcs/0001-template.md](rfcs/0001-template.md).

## Feedback

Representation decisions are discussed in GitHub issues. If you have feedback or want to propose a change, open an issue tagged `representation-rfc`.
