# SWELib Project Structure

## Overview

SWELib is a formal library for software engineering concepts in Lean 4, organized into two layers: **spec/** (pure specifications) and **impl/** (executable implementations with FFI).

## Directory Tree

```
SWELib/
├── README.md                 # Project overview and getting started
├── CHANGELOG.md              # Version history
├── CONTRIBUTING.md           # Contribution guidelines
├── LICENSE                   # MIT License
├── PROJECT_STRUCTURE.md      # This file
├── lean-toolchain            # Lean version specification
├── lakefile.lean             # Lake build configuration
├── lake-manifest.json        # Dependencies manifest
│
├── spec/                     # Layer 1: Formal Specifications (pure Lean)
│   ├── SWELib.lean           # Root import file
│   └── SWELib/
│       ├── Basics/           # Data formats (JSON, URI, Base64, CSV, YAML, etc.)
│       ├── Foundations/       # Abstract framework (LTS, Node, Network, System)
│       ├── Networking/       # Protocols (TCP, UDP, HTTP, TLS, DNS, SSH, WebSocket, etc.)
│       ├── Distributed/      # Distributed systems (consensus, CRDTs, clocks, sagas, etc.)
│       ├── Db/               # Database (SQL, connection pool, transactions, migrations, etc.)
│       ├── Cloud/            # Cloud infrastructure (K8s, OCI, OCI Image, Terraform, GCP)
│       ├── OS/               # OS concepts (files, processes, sockets, memory, cgroups, etc.)
│       ├── Security/         # Security (JWT, PKI, crypto, IAM, CORS, RBAC, etc.)
│       ├── Observability/    # Observability (logging, metrics, tracing, alerting)
│       ├── Cicd/             # CI/CD (pipelines, deployments, rollback, migrations)
│       └── Integration/      # Cross-cutting integration theorems
│
├── impl/                     # Layer 2: Executable Implementations
│   ├── SWELibImpl.lean       # Root import file
│   ├── SWELibImpl/
│   │   ├── Bridge/           # Trust boundary — axioms about external code
│   │   │   ├── Syscalls/     # Linux syscall axioms
│   │   │   ├── Libssl/       # OpenSSL axioms
│   │   │   ├── Libpq/        # libpq axioms
│   │   │   ├── Libcurl/      # libcurl axioms
│   │   │   ├── Libssh/       # libssh axioms
│   │   │   ├── Encoding/     # Encoding axioms
│   │   │   └── Oracles/      # Oracle axioms (Terraform, etc.)
│   │   ├── Ffi/              # @[extern] declarations
│   │   ├── Basics/           # Executable parsers and serializers
│   │   ├── Networking/       # Executable network clients/servers
│   │   ├── Db/               # Executable database clients
│   │   ├── Cloud/            # Executable cloud API clients
│   │   ├── OS/               # Executable OS wrappers
│   │   ├── Security/         # Executable security operations
│   │   └── Validators/       # Standalone validators
│   └── ffi/                  # C source files for shims
│
├── test/                     # Tests
│
├── doc/                      # Documentation
│   ├── design.md             # Architecture and design principles (project-wide)
│   ├── spec/                 # Spec layer docs, systems framework sketches, plans
│   ├── impl/                 # Impl layer docs, trust boundary, tooling plans
│   └── test/                 # Testing documentation
│
└── .github/                  # CI/CD & Issue Templates
    ├── workflows/
    └── ISSUE_TEMPLATE/
```

## Key Metrics

- **Spec files:** ~315 `.lean` files
- **Impl files:** ~65 `.lean` files
- **Spec modules:** 11 top-level domains (Basics, Foundations, Networking, Distributed, Db, Cloud, OS, Security, Observability, Cicd, Integration)

## Getting Started

### Build

```bash
lake build
```

### Run Tests

```bash
lake test
```

## Development Guidelines

### For Spec Layer (`spec/`)

- Define types, functions, and theorems
- No `@[extern]`, IO, or FFI
- Every `sorry` must link to a `sorry-debt` issue

### For Impl Layer (`impl/`)

- Implement executable versions
- Bridge axioms go in `impl/SWELibImpl/Bridge/`
- Every bridge axiom must have `-- TRUST: <issue-url>`
- Use FFI conservatively
- Test against the spec

## Resources

- **Lean Documentation:** https://lean-lang.org/
- **Mathlib:** https://github.com/leanprover-community/mathlib4
- **SWELib Design:** See `doc/design.md`

## Contributing

See `CONTRIBUTING.md` for detailed guidelines.
