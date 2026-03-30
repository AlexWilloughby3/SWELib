# SWELib
## Note: This project is still in development and shouldn't be used for any software verification as of now
A comprehensive formal library for software engineering concepts in Lean 4.

SWELib is organized into two layers:

- **spec/** — Pure Lean definitions, theorems, and proofs (Mathlib-like artifact)
- **impl/** — Executable implementations with FFI bindings, bridge axioms, and validators

## Getting Started

### Prerequisites

- Lean 4 (v4.0.0 or later)
- Lake (Lean's package manager)
- C libraries: OpenSSL, libpq, libcurl, libssh2 (for FFI)

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

- `spec/` — Formal specifications (pure Lean, no IO/FFI)
- `impl/` — Executable implementations, FFI bindings, and bridge axioms
- `test/` — Tests (spec-level and integration)
- `doc/` — Documentation and design decisions

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

See [LICENSE](LICENSE) for license information.

## Trust Boundary

Bridge axioms documenting assumptions about external code live in `impl/SWELibImpl/Bridge/`.
See [doc/impl/Bridge/trust-boundary.md](doc/impl/Bridge/trust-boundary.md) for the annotated list.
