import SWELib
import SWELibImpl.Bridge

/-!
# Libssl FFI

Raw `@[extern]` declarations for OpenSSL TLS client operations.
Uses opaque types for SSL_CTX and SSL connection handles,
backed by `lean_alloc_external` with finalizers in the C shim.
-/

namespace SWELibImpl.Ffi.Libssl

/-- Opaque handle to an OpenSSL SSL_CTX. Freed by finalizer. -/
opaque SslCtx : Type := Unit

/-- Opaque handle to an OpenSSL SSL connection. Freed by finalizer. -/
opaque SslConn : Type := Unit

/-- Create a new TLS client context (TLS_client_method).
    Loads default CA certificates and enables peer verification. -/
@[extern "swelib_ssl_ctx_new"]
opaque sslCtxNew : IO SslCtx

/-- Create a new SSL connection and attach it to a socket fd. -/
@[extern "swelib_ssl_new"]
opaque sslNew (ctx : @& SslCtx) (fd : UInt32) : IO SslConn

/-- Set SNI hostname and enable hostname verification. -/
@[extern "swelib_ssl_set_hostname"]
opaque sslSetHostname (conn : @& SslConn) (hostname : @& String) : IO Unit

/-- Perform TLS handshake. Returns 1 on success, 0 on failure. -/
@[extern "swelib_ssl_connect"]
opaque sslConnect (conn : @& SslConn) : IO UInt32

/-- Read up to `maxBytes` from the TLS connection. -/
@[extern "swelib_ssl_read"]
opaque sslRead (conn : @& SslConn) (maxBytes : USize) : IO ByteArray

/-- Write data to the TLS connection. Returns bytes written. -/
@[extern "swelib_ssl_write"]
opaque sslWrite (conn : @& SslConn) (data : @& ByteArray) : IO USize

/-- Send TLS close_notify and shut down the connection. -/
@[extern "swelib_ssl_shutdown"]
opaque sslShutdown (conn : @& SslConn) : IO Unit

/-! ## Server-side TLS operations -/

/-- Create a new TLS server context with certificate and private key files.
    Loads the PEM-encoded cert and key, verifies they match, disables
    protocols below TLS 1.2. -/
@[extern "swelib_ssl_server_ctx_new"]
opaque sslServerCtxNew (certFile : @& String) (keyFile : @& String) : IO SslCtx

/-- Perform server-side TLS handshake. Returns 1 on success, 0 on failure. -/
@[extern "swelib_ssl_accept"]
opaque sslAccept (conn : @& SslConn) : IO UInt32

/-- Get the subject DN of the peer certificate (empty string if none). -/
@[extern "swelib_ssl_get_peer_certificate_subject"]
opaque sslGetPeerCertSubject (conn : @& SslConn) : IO String

/-- Get the negotiated TLS protocol version string (e.g. "TLSv1.3"). -/
@[extern "swelib_ssl_get_protocol_version"]
opaque sslGetProtocolVersion (conn : @& SslConn) : IO String

/-- Get the negotiated cipher suite name. -/
@[extern "swelib_ssl_get_cipher_name"]
opaque sslGetCipherName (conn : @& SslConn) : IO String

end SWELibImpl.Ffi.Libssl
