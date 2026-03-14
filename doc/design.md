# SWELib Design

## Overview

SWELib is a comprehensive formal library for software engineering concepts in Lean 4. It is organized into three layers, each with distinct responsibilities and guarantees.

## Three-Layer Architecture

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

### Layer 2: bridge/ — Trust Boundary

**Purpose:** Explicitly document and axiomatize all assumptions about external code.

**Characteristics:**
- Axioms asserting that external functions satisfy spec properties
- Single, auditable surface of all unproven real-world assumptions
- Separates "what Lean can verify" from "what we must trust"
- Makes the cost of trust explicit

**Examples:**
- `SWELibBridge.Syscalls.Socket.bind_conforms` — asserts Linux socket bind conforms to `SWELib.OS.Sockets.SocketLifecycle`
- `SWELibBridge.Libssl.Handshake.conforms` — asserts OpenSSL TLS handshake conforms to `SWELib.Security.Tls`
- `SWELibBridge.Oracles.Terraform.correctness` — asserts Terraform plan application is correct

**Guidelines:**
- Every axiom must have a `-- TRUST: <issue-url>` comment
- Link to tracking issues documenting the justification
- Keep axioms focused and explicit
- Review bridge axioms regularly

### Layer 3: code/ — Executable Implementations

**Purpose:** Provide executable Lean code that can actually run.

**Characteristics:**
- Imports spec/ for types and bridge/ for extern bindings
- Contains `@[extern]` declarations and FFI bindings
- Links against C libraries (OpenSSL, libpq, libcurl, etc.)
- Implements algorithms and operators defined in spec/

**Examples:**
- `SWELibCode.Networking.HttpClient.get` — executable HTTP GET
- `SWELibCode.Db.PgClient.query` — executable Postgres query
- `SWELibCode.Validators.JsonValidator.validate` — executable JSON validation

**Guidelines:**
- Bridge the gap between spec definitions and real implementations
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
│bridge/ │  ← spec/
└───┬────┘
    │
    │ imports
    ▼
┌────────┐
│ code/  │  ← spec/ + bridge/, links C libraries
└────────┘
```

- spec/ is self-contained (no dependencies except Mathlib)
- bridge/ imports spec/ only
- code/ imports spec/ and bridge/, plus C shims

## Key Design Principles

### 1. Separation of Concerns

- spec/ is about definition and proof
- bridge/ is about trust and boundaries
- code/ is about execution

### 2. Auditability

- Bridge axioms are clustered in `bridge/`, not scattered
- Every axiom has a tracking issue
- Scripts (`scripts/audit-bridge.sh`, `scripts/sorry-report.sh`) enforce discipline

### 3. Layered Trust

- Mathlib is trusted (used in spec/)
- Bridge axioms are explicitly listed and audited
- Code implementations can be tested and verified

### 4. Reusability

- Spec can be used without bridge/ or code/
- Bridge can be used as a reference for assumptions
- Code can be used as a reference implementation

## File Organization

### Spec Layer (`spec/`)

```
spec/
├── SWELib.lean                 # Root import
├── SWELib/
│   ├── Basics/                 # Basic data formats (JSON, URI, etc.)
│   ├── Networking/             # Network protocols (TCP, HTTP, TLS, etc.)
│   ├── Distributed/            # Distributed systems (consensus, clocks, etc.)
│   ├── Db/                     # Database concepts (relations, SQL, ACID, etc.)
│   ├── Cloud/                  # Cloud infrastructure (K8s, Terraform, etc.)
│   ├── OS/                     # Operating system concepts (files, processes, etc.)
│   ├── Security/               # Security (hashing, encryption, OAuth, etc.)
│   ├── Observability/          # Observability (logging, metrics, tracing, etc.)
│   ├── Cicd/                   # CI/CD concepts (pipelines, deployments, etc.)
│   └── Integration/            # Integration theorems (end-to-end proofs)
└── Specs/                      # Pinned RFC/spec documents
```

### Bridge Layer (`bridge/`)

```
bridge/
├── SWELibBridge.lean           # Root import
├── SWELibBridge/
│   ├── Syscalls/               # Linux syscall axioms
│   ├── Libssl/                 # OpenSSL axioms
│   ├── Libpq/                  # libpq axioms
│   ├── Libcurl/                # libcurl axioms
│   └── Oracles/                # Oracle axioms (Terraform, etc.)
```

### Code Layer (`code/`)

```
code/
├── SWELibCode.lean             # Root import
├── SWELibCode/
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
- Bridge: `SWELibBridge.Domain.concept_conforms` (e.g., `SWELibBridge.Syscalls.Socket.bind_conforms`)
- Code: `SWELibCode.Domain.ConceptImpl` (e.g., `SWELibCode.Networking.HttpClientImpl`)

### Function Names

- Use domain-standard names where possible
- Be explicit about what axiom/implementation does
- Include effects in name (e.g., `IO` suffix for monadic operations)

## Testing Strategy

### Spec Tests

- Proof-level tests using `#check` and `#eval`
- Verify theorems and lemmas
- Test properties of definitions

### Code Tests

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

2. **Bridge second:** If using external libraries
   - Add axioms in `bridge/`
   - Link to tracking issues
   - Document assumptions

3. **Code third:** Implement executably
   - Add FFI bindings in `code/Ffi/`
   - Implement in `code/`
   - Test thoroughly

### Adding a Bridge Axiom

1. Create a GitHub issue documenting the justification
2. Add the axiom to the appropriate `bridge/` module
3. Include `-- TRUST: <issue-url>` comment
4. Run `scripts/audit-bridge.sh` to verify

### Tracking Sorry

1. Create a GitHub issue tagged `sorry-debt`
2. Add `sorry` in `spec/` with issue reference
3. Run `scripts/sorry-report.sh` to verify tracking
4. Resolve when implementation is complete

## Supporting Documents

- [trust-boundary.md](trust-boundary.md) — Annotated list of all bridge axioms
- [representation-decisions.md](representation-decisions.md) — Log of representation choices and rationale
- [tutorials/](tutorials/) — Step-by-step guides for common tasks

## Future Extensions

- Formalize additional protocols (gRPC, GraphQL, WebSocket)
- Add more cloud platforms (AWS, Azure)
- Develop higher-order theorems about system properties
- Create extractors for automatic code generation
