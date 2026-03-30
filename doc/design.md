# SWELib Design

## Overview

SWELib is a comprehensive formal library for software engineering concepts in Lean 4. It is organized into two layers, each with distinct responsibilities and guarantees.

## Two-Layer Architecture

### Layer 1: spec/ — Formal Specifications

**Purpose:** Define the mathematical and logical semantics of software engineering concepts.

**Characteristics:**
- Pure Lean definitions, theorems, and proofs
- No `@[extern]`, no IO, no FFI
- Mathlib-like artifact — reusable, auditable, and self-contained
- Types and theorems that model real-world concepts

**Examples:**
- `SWELib.Networking.Http.Request` — HTTP request structure
- `SWELib.Distributed.Consensus.Raft` — Raft consensus algorithm
- `SWELib.Db.Transactions.ACID` — ACID properties

**Guidelines:**
- Follow Lean 4 and Mathlib conventions
- Use meaningful names aligned with domain terminology
- Document non-obvious proofs
- Every `sorry` must have a GitHub issue tagged `sorry-debt`

### Layer 2: impl/ — Executable Implementations

**Purpose:** Provide executable Lean code with FFI bindings and bridge axioms.

**Characteristics:**
- Imports spec/ for types and definitions
- Contains `@[extern]` declarations and FFI bindings
- Links against C libraries (OpenSSL, libpq, libcurl, libssh2)
- Bridge axioms (`impl/SWELibImpl/Bridge/`) explicitly document all assumptions about external code

**Substructure:**
- `Bridge/` — Axioms asserting external functions satisfy spec properties (trust boundary)
- `Ffi/` — `@[extern]` declarations for C library bindings
- `Basics/`, `Networking/`, `Db/`, `Cloud/`, `OS/`, `Security/` — Executable implementations
- `Validators/` — Standalone validators
- `ffi/` — C source files for shims

**Guidelines:**
- Bridge the gap between spec definitions and real implementations
- Every bridge axiom must have a `-- TRUST: <issue-url>` comment
- Use FFI conservatively; prefer pure Lean when possible
- Test executables thoroughly
- Document any deviations from the spec

## Dependency Graph

```
┌────────┐
│ spec/  │  ← Mathlib (minimal)
└───┬────┘
    │
    │ imports
    ▼
┌────────┐
│ impl/  │  ← spec/, links C libraries
└────────┘
```

- spec/ is self-contained (no dependencies except Mathlib)
- impl/ imports spec/ and links C shims

## Key Design Principles

### 1. Separation of Concerns

- spec/ is about definition and proof
- impl/ is about execution, FFI, and trust boundaries

### 2. Auditability

- Bridge axioms are clustered in `impl/SWELibImpl/Bridge/`, not scattered
- Every axiom has a tracking issue

### 3. Layered Trust

- Mathlib is trusted (used in spec/)
- Bridge axioms are explicitly listed and audited
- Code implementations can be tested and verified

### 4. Reusability

- Spec can be used without impl/
- Bridge axioms serve as a reference for assumptions
- Impl can be used as a reference implementation

## File Organization

### Spec Layer (`spec/`)

```
spec/
├── SWELib.lean                 # Root import
├── SWELib/
│   ├── Basics/                 # Data formats (JSON, URI, Base64, etc.)
│   ├── Foundations/             # LTS, Node, Network, System (abstract framework)
│   ├── Networking/             # Protocols (TCP, HTTP, TLS, DNS, SSH, etc.)
│   ├── Distributed/            # Distributed systems (consensus, clocks, CRDTs, etc.)
│   ├── Db/                     # Database concepts (relations, SQL, connection pool, etc.)
│   ├── Cloud/                  # Cloud infrastructure (K8s, OCI, Terraform, etc.)
│   ├── OS/                     # OS concepts (files, processes, sockets, memory, etc.)
│   ├── Security/               # Security (JWT, PKI, crypto, IAM, etc.)
│   ├── Observability/          # Observability (logging, metrics, tracing, etc.)
│   ├── Cicd/                   # CI/CD concepts (pipelines, deployments, migrations, etc.)
│   └── Integration/            # Integration theorems (end-to-end proofs)
```

### Impl Layer (`impl/`)

```
impl/
├── SWELibImpl.lean             # Root import
├── SWELibImpl/
│   ├── Bridge/                 # Trust boundary — axioms about external code
│   │   ├── Syscalls/           # Linux syscall axioms
│   │   ├── Libssl/             # OpenSSL axioms
│   │   ├── Libpq/              # libpq axioms
│   │   ├── Libcurl/            # libcurl axioms
│   │   ├── Libssh/             # libssh axioms
│   │   ├── Encoding/           # Encoding axioms
│   │   └── Oracles/            # Oracle axioms (Terraform, etc.)
│   ├── Ffi/                    # @[extern] declarations
│   ├── Basics/                 # Executable parsers and serializers
│   ├── Networking/             # Executable network clients/servers
│   ├── Db/                     # Executable database clients
│   ├── Cloud/                  # Executable cloud API clients
│   ├── OS/                     # Executable OS wrappers
│   ├── Security/               # Executable security operations
│   └── Validators/             # Standalone validators
└── ffi/                        # C source files for shims
```

## Naming Conventions

### Type Names

- Spec: `SWELib.Domain.Concept` (e.g., `SWELib.Networking.Http.Request`)
- Bridge: `SWELibImpl.Bridge.Domain.concept_conforms`
- Impl: `SWELibImpl.Domain.ConceptImpl`

### Function Names

- Use domain-standard names where possible
- Be explicit about what axiom/implementation does
- Include effects in name (e.g., `IO` suffix for monadic operations)

## Testing Strategy

### Spec Tests

- Proof-level tests using `#check` and `#eval`
- Verify theorems and lemmas
- Test properties of definitions

### Impl Tests

- Executable tests using Lean's test framework
- Test FFI bindings
- Test implementations against spec properties

### Integration Tests

- End-to-end tests with real services
- Verify implementations work in practice
- Require running services (databases, networks, etc.)

## Development Workflow

### Adding a New Concept

1. **Spec first:** Define the concept in `spec/`
   - Inductive types, structures, functions
   - Key theorems and proofs
   - Use `sorry` if needed (link to issue)

2. **Impl second:** Implement executably
   - Add bridge axioms in `impl/SWELibImpl/Bridge/` if using external libraries
   - Add FFI bindings in `impl/SWELibImpl/Ffi/`
   - Implement in `impl/SWELibImpl/`
   - Test thoroughly

### Adding a Bridge Axiom

1. Create a GitHub issue documenting the justification
2. Add the axiom to the appropriate `impl/SWELibImpl/Bridge/` module
3. Include `-- TRUST: <issue-url>` comment

### Tracking Sorry

1. Create a GitHub issue tagged `sorry-debt`
2. Add `sorry` in `spec/` with issue reference
3. Resolve when implementation is complete

## Supporting Documents

- [impl/Bridge/trust-boundary.md](impl/Bridge/trust-boundary.md) — Annotated list of all bridge axioms
- [spec/Basics/representation-decisions.md](spec/Basics/representation-decisions.md) — Log of representation choices and rationale
- [spec/Foundations/vision.md](spec/Foundations/vision.md) — Vision for system-level formalizations
- [spec/future-formalization-targets.md](spec/future-formalization-targets.md) — Candidate concepts for formalization
- [spec/](spec/) — Spec module documentation (mirrors spec/SWELib/ structure)
- [impl/](impl/) — Impl module documentation (mirrors impl/SWELibImpl/ structure)
- [test/](test/) — Testing documentation

## Future Extensions

- Formalize additional protocols (gRPC, GraphQL, WebSocket)
- Add more cloud platforms (AWS, Azure)
- Develop higher-order theorems about system properties
- Create extractors for automatic code generation
