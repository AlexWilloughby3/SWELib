import SWELib
import SWELibBridge

/-!
# Libssl FFI

Raw `@[extern]` declarations for OpenSSL TLS client operations.
Uses opaque types for SSL_CTX and SSL connection handles,
backed by `lean_alloc_external` with finalizers in the C shim.
-/

namespace SWELibCode.Ffi.Libssl

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

end SWELibCode.Ffi.Libssl
