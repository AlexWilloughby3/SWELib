# Trust Boundary

This document lists all axioms in `bridge/` that represent unproven real-world assumptions.

## Purpose

The trust boundary makes explicit where Lean's type system ends and the real world begins.
Every entry here represents an assumption about external code that we must verify through other means (documentation, testing, auditing).

## Axioms by Category

### Syscalls (Linux)

| Module | Axiom | Assumption | Tracking Issue |
|--------|-------|-----------|-----------------|
| Socket.lean | `bind_conforms` | Linux `bind()` matches socket lifecycle spec | [#ISSUE_ID](link) |
| Socket.lean | `listen_conforms` | Linux `listen()` matches socket lifecycle spec | [#ISSUE_ID](link) |
| Socket.lean | `accept_conforms` | Linux `accept()` matches socket lifecycle spec | [#ISSUE_ID](link) |
| File.lean | `open_conforms` | Linux `open()` matches file descriptor spec | [#ISSUE_ID](link) |
| Process.lean | `fork_conforms` | Linux `fork()` matches process lifecycle spec | [#ISSUE_ID](link) |

### TLS (OpenSSL)

| Module | Axiom | Assumption | Tracking Issue |
|--------|-------|-----------|-----------------|
| Handshake.lean | `tls_handshake_conforms` | OpenSSL TLS handshake matches RFC 8446 | [#ISSUE_ID](link) |
| Record.lean | `record_encrypt_conforms` | OpenSSL record encryption matches spec | [#ISSUE_ID](link) |
| Cert.lean | `validate_cert_conforms` | OpenSSL cert validation is correct | [#ISSUE_ID](link) |

### Database (libpq)

| Module | Axiom | Assumption | Tracking Issue |
|--------|-------|-----------|-----------------|
| Connect.lean | `connect_conforms` | libpq connection matches PostgreSQL protocol | [#ISSUE_ID](link) |
| Exec.lean | `exec_conforms` | libpq query execution matches SQL semantics | [#ISSUE_ID](link) |

### HTTP (libcurl or pure Lean)

| Module | Axiom | Assumption | Tracking Issue |
|--------|-------|-----------|-----------------|
| Get.lean | `http_get_conforms` | HTTP GET matches RFC 9110 semantics | [#ISSUE_ID](link) |

### Oracles

| Module | Axiom | Assumption | Tracking Issue |
|--------|-------|-----------|-----------------|
| Terraform.lean | `apply_correctness` | Terraform apply produces desired state | [#ISSUE_ID](link) |

## Auditing

Run `scripts/audit-bridge.sh` to verify all axioms have tracking issues:

```bash
cd /path/to/SWELib
scripts/audit-bridge.sh
```

This checks that:
1. Every axiom in `bridge/` has a `-- TRUST: <issue-url>` comment
2. All referenced issues exist and are open
3. The list stays up-to-date

## Future Work

- Formal verification of OpenSSL TLS handshake
- Formal verification of PostgreSQL protocol implementation
- Property-based testing of syscall wrappers
- Formal semantics of Terraform plans
