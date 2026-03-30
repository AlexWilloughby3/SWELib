# Spec Layer Documentation

The `spec/` layer contains pure Lean 4 definitions, theorems, and proofs. No `@[extern]`, no IO, no FFI. This is the Mathlib-like artifact that can be used independently of the implementation layer.

## Module Overview

| Module | Files | Status | Description |
|--------|-------|--------|-------------|
| [Basics](Basics/) | 18 | Mostly complete | Data formats, serialization, encoding |
| [Foundations](Foundations/) | 4 | Complete | LTS, Node, Network, System abstractions |
| [Networking](Networking/) | 78 | Extensive | TCP, UDP, HTTP, TLS, DNS, SSH, WebSocket, REST, Proxy |
| [Distributed](Distributed/) | 15 | Mostly complete | Consensus, CRDTs, clocks, sagas, circuit breakers |
| [Db](Db/) | 33 | SQL complete, stubs elsewhere | SQL semantics, connection pool, transactions |
| [Cloud](Cloud/) | 70 | K8s + OCI complete | Kubernetes, OCI Image, OCI Runtime |
| [OS](OS/) | 45 | Comprehensive | Processes, memory, sockets, cgroups, namespaces, systemd |
| [Security](Security/) | 31 | Partial | JWT, PKI, crypto, IAM |
| [Observability](Observability/) | 5 | Stubs only | Logging, metrics, tracing, alerting, health checks |
| [Cicd](Cicd/) | 7 | Mostly complete | Pipelines, deployments, rollback, GitOps, migrations |
| [Integration](Integration/) | 3 | Stubs only | Cross-cutting integration theorems |

**Total: ~315 Lean files**

## Other Documents

- [future-formalization-targets.md](future-formalization-targets.md) — Candidate concepts for formalization
- [Basics/representation-decisions.md](Basics/representation-decisions.md) — Design decisions log
- [Foundations/vision.md](Foundations/vision.md) — Vision for abstract system formalizations
