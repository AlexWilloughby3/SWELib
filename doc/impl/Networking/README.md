# Networking Implementations

High-level networking implementations composing FFI and Bridge modules into usable clients and servers.

## Modules

| File | Description | Uses |
|------|-------------|------|
| `HttpClient.lean` | HTTP client via libcurl; `get`, `post`, `request` returning spec-level `Http.Response` | Ffi/Libcurl |
| `HttpServer.lean` | TCP accept loop with pure-Lean HTTP/1.1 request parser and response serializer | Ffi/Syscalls |
| `HttpsServer.lean` | HTTPS server: TCP accept + per-connection TLS handshake + HTTP/1.1 parsing | Ffi/Libssl + Ffi/Syscalls |
| `TcpServer.lean` | TCP listener: bind, listen, accept with SO_REUSEADDR | Ffi/Syscalls |
| `TcpClient.lean` | TCP stream: connect, send, recv, close with hostname resolution | Ffi/Syscalls |
| `TlsClient.lean` | TLS stream over TCP: OpenSSL client-side handshake with SNI hostname verification | Ffi/Libssl |
| `SshClient.lean` | SSH client over libssh2: authenticated sessions with channel operations | Ffi/Libssh |
| `DnsResolver.lean` | Hostname resolution via getaddrinfo(3) returning `ResolvedAddress` array | Ffi/Syscalls |
