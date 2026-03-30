# Impl Layer Documentation

The `impl/` layer contains executable Lean code, FFI bindings, bridge axioms, and validators. It imports `spec/` for types and definitions, and links against C libraries (OpenSSL, libpq, libcurl, libssh2).

## Module Overview

| Module | Files | Description |
|--------|-------|-------------|
| [Bridge](Bridge/) | 26 | Trust boundary — axioms about external code |
| [Ffi](Ffi/) | 6 Lean + 5 C | `@[extern]` declarations and C shims |
| [Networking](Networking/) | 8 | HTTP/TCP/TLS/SSH clients and servers |
| [Db](Db/) | 9 | PostgreSQL client and connection pool |
| [Cloud](Cloud/) | 4 | GCP, K8s, Terraform, OCI runtime clients |
| [OS](OS/) | 5 | Socket, file, process, signal, memory wrappers |
| [Security](Security/) | 2 | JWT validation, hash functions |
| [Basics](Basics/) | 1 | URI parser |
| [Validators](Validators/) | 3 | Terraform, K8s, HTTP contract validators |

**Total: ~65 Lean files + 5 C files**

## Other Documents

- [ci-and-navigator-plan.md](ci-and-navigator-plan.md) — CI pipeline and dependency navigator plan
- [autoformalized-blueprint-plan.md](autoformalized-blueprint-plan.md) — Auto-blueprint generation plan
