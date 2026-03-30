# Bridge Axioms

The trust boundary: axioms asserting that external C libraries satisfy the formal spec properties. Every axiom must have a `-- TRUST: <issue-url>` comment.

See [trust-boundary.md](trust-boundary.md) for the full annotated list.

## Modules

### Syscalls (9 files)

POSIX system call conformance axioms.

| File | Axiom Coverage |
|------|---------------|
| `Socket.lean` | socket, bind, connect, listen, accept |
| `File.lean` | close, dup2, open, read, write, seek |
| `Process.lean` | fork, exit, waitpid, kill, getpid |
| `Signal.lean` | sigaction, sigprocmask, sigpending, kill |
| `Memory.lean` | mmap, munmap, mprotect, brk |
| `Epoll.lean` | epoll_create1, epoll_ctl |
| `Namespace.lean` | clone, unshare, setns |
| `Cgroup.lean` | create, delete, move_process, set_limit, get_limit |
| `Mount.lean` | mount, umount2 |

### Libssl (5 files)

OpenSSL TLS conformance axioms.

| File | Axiom Coverage |
|------|---------------|
| `Hash.lean` | SHA-2 (SHA-256/384/512) and HMAC per FIPS 180-4, RFC 2104 |
| `Handshake.lean` | TLS client handshake (SSL_connect) per RFC 8446 |
| `ServerHandshake.lean` | TLS server handshake (SSL_accept) per RFC 8446 |
| `Record.lean` | Record layer confidentiality, integrity, size bounds |
| `Cert.lean` | CA bundle loading, chain verification, hostname matching |

### Libpq (4 files)

PostgreSQL client library axioms.

| File | Axiom Coverage |
|------|---------------|
| `Libpq.lean` | Barrel file |
| `Connect.lean` | pq_connect conformance |
| `Exec.lean` | pq_exec query execution conformance |
| `Validation.lean` | Connection health checking with timeout |

### Libcurl (4 files)

HTTP client library axioms.

| File | Axiom Coverage |
|------|---------------|
| `Get.lean` | GET request Content-Length consistency, header completeness (RFC 9110) |
| `Post.lean` | POST request valid status codes (100-999), Content-Length consistency |
| `Response.lean` | Raw response structure and header parsing |
| `HttpServer.lean` | HTTP/1.1 parser axioms (parseRequest, serializeResponse) |

### Libssh (1 file)

| File | Axiom Coverage |
|------|---------------|
| `Session.lean` | libssh2 key exchange and encryption per RFC 4253 |

### Encoding (1 file)

| File | Axiom Coverage |
|------|---------------|
| `Base64url.lean` | Base64url encode/decode per RFC 4648 Section 5 |

### Oracles (1 file)

| File | Axiom Coverage |
|------|---------------|
| `Terraform.lean` | Successful terraform apply matches infrastructure state |
