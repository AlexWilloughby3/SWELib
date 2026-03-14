# SWELib Project Structure Summary

## Overview

The SWELib project has been successfully initialized with a three-layer architecture.

## Directory Tree

```
SWELib/
├── README.md                 # Project overview and getting started
├── CHANGELOG.md              # Version history
├── CONTRIBUTING.md           # Contribution guidelines
├── LICENSE                   # MIT License
├── lean-toolchain            # Lean version specification
├── lakefile.lean             # Lake build configuration
├── lake-manifest.json        # Dependencies manifest
├── PROJECT_STRUCTURE.md      # This file
│
├── spec/                     # ✅ Layer 1: Formal Specifications
│   ├── SWELib.lean          # Root import file
│   ├── SWELib/
│   │   ├── Basics/          # Basic data formats (JSON, URI, etc.)
│   │   │   ├── Bytes.lean
│   │   │   ├── Strings.lean
│   │   │   ├── Json.lean (+ Json/ subdir with 6 files)
│   │   │   ├── Yaml.lean
│   │   │   ├── Protobuf.lean
│   │   │   ├── Toml.lean
│   │   │   ├── Csv.lean
│   │   │   ├── Xml.lean
│   │   │   ├── Regex.lean
│   │   │   ├── Time.lean
│   │   │   ├── Uuid.lean
│   │   │   ├── Semver.lean
│   │   │   └── Uri.lean
│   │   ├── Networking.lean  # Network protocols (TCP, HTTP, TLS, etc.)
│   │   ├── Distributed.lean # Distributed systems (consensus, clocks, etc.)
│   │   ├── Db.lean          # Database concepts (relations, SQL, ACID, etc.)
│   │   ├── Cloud.lean       # Cloud infrastructure (K8s, Terraform, etc.)
│   │   ├── OS.lean          # OS concepts (files, processes, sockets, etc.)
│   │   ├── Security.lean    # Security (hashing, encryption, OAuth, JWT, etc.)
│   │   ├── Observability.lean # Observability (logging, metrics, tracing, etc.)
│   │   ├── Cicd.lean        # CI/CD concepts (pipelines, deployments, etc.)
│   │   └── Integration.lean # Integration theorems (end-to-end proofs)
│   └── Specs/               # Pinned RFC and reference documents
│
├── bridge/                   # ✅ Layer 2: Trust Boundary
│   ├── SWELibBridge.lean    # Root import file
│   └── SWELibBridge/
│       ├── Syscalls/        # Linux syscall axioms (8 files)
│       │   ├── Socket.lean
│       │   ├── File.lean
│       │   ├── Process.lean
│       │   ├── Memory.lean
│       │   ├── Epoll.lean
│       │   ├── Namespace.lean
│       │   ├── Cgroup.lean
│       │   └── Mount.lean
│       ├── Libssl/          # OpenSSL axioms (3 files)
│       ├── Libpq/           # libpq axioms (3 files)
│       ├── Libcurl/         # libcurl axioms (3 files)
│       └── Oracles/         # Oracle axioms (1 file)
│
├── code/                     # ✅ Layer 3: Executable Implementations
│   ├── SWELibCode.lean      # Root import file
│   ├── SWELibCode/
│   │   ├── Ffi/             # @[extern] declarations (4 files)
│   │   ├── Basics/          # Parsers & serializers (4 files)
│   │   ├── Networking/      # Network clients/servers (6 files)
│   │   ├── Db/              # Database clients (3 files)
│   │   ├── Cloud/           # Cloud API clients (4 files)
│   │   ├── OS/              # OS wrappers (3 files)
│   │   ├── Security/        # Security operations (2 files)
│   │   └── Validators/      # Standalone validators (4 files)
│   └── ffi/                 # C source files for shims
│
├── test/                     # ✅ Test Infrastructure
│   ├── Spec/                # Proof-level tests
│   ├── Code/                # Executable tests
│   └── Integration/         # End-to-end tests
│
├── doc/                      # ✅ Documentation
│   ├── design.md            # Architecture and design principles
│   ├── trust-boundary.md    # Annotated axioms list
│   ├── representation-decisions.md # Design decisions log
│   ├── rfcs/                # RFC directory template
│   └── tutorials/           # Step-by-step guides
│
├── scripts/                  # ✅ Utility Scripts
│   ├── audit-bridge.sh      # Verify all axioms have TRUST comments
│   ├── sorry-report.sh      # List all sorry's in spec/
│   └── dep-graph.sh         # Generate dependency graph
│
├── .github/                  # ✅ CI/CD & Issue Templates
│   ├── workflows/
│   │   ├── ci.yml           # Build and test pipeline
│   │   ├── audit.yml        # Weekly bridge axiom audit
│   │   └── sorry-count.yml  # Track sorry count over time
│   └── ISSUE_TEMPLATE/
│       ├── representation-rfc.md    # Propose representation changes
│       ├── bridge-axiom.md          # Document trust assumptions
│       └── sorry-tracking.md        # Track incomplete proofs
│
└── .gitignore               # Git ignore patterns
```

## Key Metrics

- **Spec files:** 29 `.lean` files (core specifications)
- **Bridge files:** 19 `.lean` files (trust boundary axioms)
- **Code files:** 31 `.lean` files (executable implementations)
- **Total:** 79 placeholder `.lean` files ready for implementation
- **Scripts:** 3 utility scripts for auditing and analysis
- **Workflows:** 3 GitHub Actions for CI/CD and auditing
- **Issue templates:** 3 templates for common contribution types

## Next Steps

### 1. **Install Dependencies**
```bash
# Lean 4 and Lake (if not already installed)
# C libraries: libssl, libpq, libcurl
sudo apt-get install libssl-dev libpq-dev libcurl4-openssl-dev
```

### 2. **Build the Project**
```bash
cd SWELib
lake build
```

### 3. **Run Tests**
```bash
lake test
```

### 4. **Audit the Project**
```bash
# Check bridge axioms
bash scripts/audit-bridge.sh

# Report sorry's
bash scripts/sorry-report.sh

# Show dependency graph
bash scripts/dep-graph.sh
```

### 5. **Start Implementing**

Choose a module to start with:

- **Easy start:** `spec/SWELib/Basics/Json.lean`
  - Define JSON value type as inductive
  - Write parsing and serialization specs

- **Networking:** `spec/SWELib/Networking/Http.lean`
  - Define HTTP request/response types
  - Specify method semantics (GET, POST, etc.)

- **Distributed systems:** `spec/SWELib/Distributed/Consensus.lean`
  - Formalize Raft or Paxos
  - Prove safety properties

## Development Guidelines

### For Spec Layer (`spec/`)

- Define types, functions, and theorems
- No `@[extern]`, IO, or FFI
- Every `sorry` must link to a `sorry-debt` issue

### For Bridge Layer (`bridge/`)

- Document axioms about external code
- Every axiom must have `-- TRUST: <issue-url>`
- Link to issues documenting the justification

### For Code Layer (`code/`)

- Implement executable versions
- Use FFI conservatively
- Test against the spec

## Resources

- **Lean Documentation:** https://lean-lang.org/
- **Lean 4 API:** https://leanprover.github.io/
- **Mathlib:** https://github.com/leanprover-community/mathlib4
- **SWELib Design:** See `doc/design.md`

## Contributing

See `CONTRIBUTING.md` for detailed guidelines.

## Questions?

- Check `doc/design.md` for architecture explanations
- Check `doc/trust-boundary.md` for axiom documentation
- See issue templates in `.github/ISSUE_TEMPLATE/` for examples
