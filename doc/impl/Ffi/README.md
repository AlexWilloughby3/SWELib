# FFI Layer

Raw `@[extern]` declarations binding Lean to C shim functions, plus the C source files implementing those shims.

## Lean FFI Modules (`impl/SWELibImpl/Ffi/`)

| File | Library | Key Bindings |
|------|---------|-------------|
| `Syscalls.lean` | POSIX | close, dup2, open, read, write, seek, socket, bind, connect, listen, accept, send, recv, fork, exit, waitpid, kill, getpid, getppid, sigaction, sigprocmask, sigpending |
| `Memory.lean` | Linux | mmap, munmap, mprotect, brk, sbrk |
| `Libssl.lean` | OpenSSL | `SslCtx`, `SslConn` opaque types; sslCtxNew, sslNew, sslSetHostname, sslConnect, sslRead, sslWrite, sslShutdown |
| `Libpq.lean` | libpq | execParams (parameterized queries), execParams_rows, transaction control |
| `Libcurl.lean` | libcurl | curlPerform (single HTTP request) |
| `Libssh.lean` | libssh2 | `SshSession`, `SshChannel`, `SshKnownHosts` opaque types; SSH operations |

## C Shim Files (`impl/ffi/`)

| File | Library | Key Functions |
|------|---------|--------------|
| `swelib_syscalls.c` | POSIX | Socket, file, process, signal, memory syscall wrappers; errno mapping (0-11) |
| `swelib_libssl.c` | OpenSSL | SSL_CTX and SSL connection management with proper Lean finalizers |
| `swelib_libcurl.c` | libcurl | HTTP request wrapper with buffer management for response data |
| `swelib_libssh.c` | libssh2 | LIBSSH2_SESSION, LIBSSH2_CHANNEL, LIBSSH2_KNOWNHOSTS with finalizers |
| `swelib_libpq.c` | libpq | Parameterized queries, result row building, transaction control |

## Build Requirements

The impl layer links against these C libraries (configured in `lakefile.lean`):
- `-lssl -lcrypto` (OpenSSL)
- `-lpq` (PostgreSQL)
- `-lcurl` (libcurl)
- `-lssh2` (libssh2)
