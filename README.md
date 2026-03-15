# SWELib
## Note: This project is still in development and shouldn't be used for any software verification as of now
A comprehensive formal library for software engineering concepts in Lean 4.

SWELib is organized into three layers:

- **spec/** — Pure Lean definitions, theorems, and proofs (Mathlib-like artifact)
- **bridge/** — Axioms asserting external functions satisfy spec properties (trust boundary)
- **code/** — Executable Lean implementations with FFI bindings

## Getting Started

### Prerequisites

- Lean 4 (v4.0.0 or later)
- Lake (Lean's package manager)
- C libraries: OpenSSL, libpq, libcurl (for FFI)

### Build

```bash
lake build
```

### Run Tests

```bash
lake test
```

## Project Structure

See [doc/design.md](doc/design.md) for a detailed explanation of the architecture.

## Key Directories

- `spec/` — Formal specifications
- `bridge/` — Trust boundary and axioms
- `code/` — Executable implementations
- `test/` — Tests (spec-level and integration)
- `doc/` — Documentation and design decisions
- `scripts/` — Utility scripts for auditing and analysis

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

See [LICENSE](LICENSE) for license information.

## Trust Boundary

All external assumptions are documented in [doc/trust-boundary.md](doc/trust-boundary.md).
Every axiom in `bridge/` has a `-- TRUST: <issue-url>` comment linking to the tracking issue.
