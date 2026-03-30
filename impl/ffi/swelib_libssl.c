/*
 * swelib_libssl.c — C shims for OpenSSL (TLS client + server operations).
 *
 * Provides SSL_CTX and SSL connection wrappers using lean_alloc_external
 * with proper finalizers.
 */

#include <lean/lean.h>
#include <openssl/ssl.h>
#include <openssl/err.h>
#include <string.h>

/* ── External object classes with finalizers ──────────────────────── */

static void ssl_ctx_finalizer(void *p) {
    if (p) SSL_CTX_free((SSL_CTX *)p);
}

static void ssl_conn_finalizer(void *p) {
    if (p) SSL_free((SSL *)p);
}

static lean_external_class *g_ssl_ctx_class  = NULL;
static lean_external_class *g_ssl_conn_class = NULL;

static lean_external_class *get_ssl_ctx_class(void) {
    if (!g_ssl_ctx_class) {
        g_ssl_ctx_class = lean_register_external_class(
            ssl_ctx_finalizer, /* finalizer */
            NULL               /* foreach (no Lean refs inside) */
        );
    }
    return g_ssl_ctx_class;
}

static lean_external_class *get_ssl_conn_class(void) {
    if (!g_ssl_conn_class) {
        g_ssl_conn_class = lean_register_external_class(
            ssl_conn_finalizer,
            NULL
        );
    }
    return g_ssl_conn_class;
}

/* ── Helper: format last OpenSSL error as Lean IO error ──────────── */

static lean_obj_res mk_ssl_error(const char *prefix) {
    unsigned long e = ERR_get_error();
    char buf[256];
    ERR_error_string_n(e, buf, sizeof(buf));
    char msg[512];
    snprintf(msg, sizeof(msg), "%s: %s", prefix, buf);
    lean_object *err = lean_mk_io_user_error(lean_mk_string(msg));
    return lean_io_result_mk_error(err);
}

/* ── FFI functions ───────────────────────────────────────────────── */

/*
 * swelib_ssl_ctx_new : IO SslCtx
 * Creates a new TLS client context (TLS_client_method).
 */
LEAN_EXPORT lean_obj_res swelib_ssl_ctx_new(lean_obj_arg world) {
    SSL_CTX *ctx = SSL_CTX_new(TLS_client_method());
    if (!ctx) return mk_ssl_error("SSL_CTX_new");

    /* Load default CA certificates */
    SSL_CTX_set_default_verify_paths(ctx);
    SSL_CTX_set_verify(ctx, SSL_VERIFY_PEER, NULL);

    lean_object *obj = lean_alloc_external(get_ssl_ctx_class(), ctx);
    return lean_io_result_mk_ok(obj);
}

/*
 * swelib_ssl_new : ctx : @& SslCtx → fd : UInt32 → IO SslConn
 * Creates a new SSL connection object and attaches it to the given fd.
 */
LEAN_EXPORT lean_obj_res swelib_ssl_new(
    b_lean_obj_arg ctx_obj, uint32_t fd,
    lean_obj_arg world
) {
    SSL_CTX *ctx = (SSL_CTX *)lean_get_external_data(ctx_obj);
    SSL *ssl = SSL_new(ctx);
    if (!ssl) return mk_ssl_error("SSL_new");

    if (SSL_set_fd(ssl, (int)fd) != 1) {
        SSL_free(ssl);
        return mk_ssl_error("SSL_set_fd");
    }

    lean_object *obj = lean_alloc_external(get_ssl_conn_class(), ssl);
    return lean_io_result_mk_ok(obj);
}

/*
 * swelib_ssl_set_hostname : conn : @& SslConn → hostname : @& String → IO Unit
 * Sets SNI hostname and hostname verification.
 */
LEAN_EXPORT lean_obj_res swelib_ssl_set_hostname(
    b_lean_obj_arg conn_obj, b_lean_obj_arg hostname,
    lean_obj_arg world
) {
    SSL *ssl = (SSL *)lean_get_external_data(conn_obj);
    const char *host = lean_string_cstr(hostname);

    SSL_set_tlsext_host_name(ssl, host);
    SSL_set1_host(ssl, host);

    return lean_io_result_mk_ok(lean_box(0));
}

/*
 * swelib_ssl_connect : conn : @& SslConn → IO UInt32
 * Performs TLS handshake. Returns 1 on success, 0 on failure.
 */
LEAN_EXPORT lean_obj_res swelib_ssl_connect(
    b_lean_obj_arg conn_obj,
    lean_obj_arg world
) {
    SSL *ssl = (SSL *)lean_get_external_data(conn_obj);
    int r = SSL_connect(ssl);
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)(r == 1 ? 1 : 0)));
}

/*
 * swelib_ssl_read : conn : @& SslConn → maxBytes : USize → IO ByteArray
 * Reads up to maxBytes from the TLS connection.
 */
LEAN_EXPORT lean_obj_res swelib_ssl_read(
    b_lean_obj_arg conn_obj, size_t maxBytes,
    lean_obj_arg world
) {
    SSL *ssl = (SSL *)lean_get_external_data(conn_obj);
    uint8_t *buf = malloc(maxBytes);
    if (!buf) {
        lean_object *err = lean_mk_io_user_error(
            lean_mk_string("SSL_read: allocation failed"));
        return lean_io_result_mk_error(err);
    }

    int n = SSL_read(ssl, buf, (int)maxBytes);
    if (n < 0) {
        free(buf);
        return mk_ssl_error("SSL_read");
    }

    lean_object *arr = lean_alloc_sarray(1, (size_t)n, (size_t)n);
    if (n > 0) memcpy(lean_sarray_cptr(arr), buf, (size_t)n);
    free(buf);

    return lean_io_result_mk_ok(arr);
}

/*
 * swelib_ssl_write : conn : @& SslConn → data : @& ByteArray → IO USize
 * Writes data to the TLS connection. Returns bytes written.
 */
LEAN_EXPORT lean_obj_res swelib_ssl_write(
    b_lean_obj_arg conn_obj, b_lean_obj_arg data,
    lean_obj_arg world
) {
    SSL *ssl = (SSL *)lean_get_external_data(conn_obj);
    size_t len = lean_sarray_size(data);
    const uint8_t *ptr = lean_sarray_cptr(data);

    int n = SSL_write(ssl, ptr, (int)len);
    if (n < 0) return mk_ssl_error("SSL_write");

    return lean_io_result_mk_ok(lean_box_usize((size_t)n));
}

/*
 * swelib_ssl_shutdown : conn : @& SslConn → IO Unit
 * Sends TLS close_notify.
 */
LEAN_EXPORT lean_obj_res swelib_ssl_shutdown(
    b_lean_obj_arg conn_obj,
    lean_obj_arg world
) {
    SSL *ssl = (SSL *)lean_get_external_data(conn_obj);
    SSL_shutdown(ssl);
    return lean_io_result_mk_ok(lean_box(0));
}

/* ── Server-side FFI functions ─────────────────────────────────────── */

/*
 * swelib_ssl_server_ctx_new : certFile : @& String → keyFile : @& String → IO SslCtx
 * Creates a new TLS server context with certificate and private key.
 */
LEAN_EXPORT lean_obj_res swelib_ssl_server_ctx_new(
    b_lean_obj_arg cert_file, b_lean_obj_arg key_file,
    lean_obj_arg world
) {
    SSL_CTX *ctx = SSL_CTX_new(TLS_server_method());
    if (!ctx) return mk_ssl_error("SSL_CTX_new(TLS_server_method)");

    const char *cert = lean_string_cstr(cert_file);
    const char *key  = lean_string_cstr(key_file);

    if (SSL_CTX_use_certificate_file(ctx, cert, SSL_FILETYPE_PEM) != 1) {
        SSL_CTX_free(ctx);
        return mk_ssl_error("SSL_CTX_use_certificate_file");
    }

    if (SSL_CTX_use_PrivateKey_file(ctx, key, SSL_FILETYPE_PEM) != 1) {
        SSL_CTX_free(ctx);
        return mk_ssl_error("SSL_CTX_use_PrivateKey_file");
    }

    if (SSL_CTX_check_private_key(ctx) != 1) {
        SSL_CTX_free(ctx);
        return mk_ssl_error("SSL_CTX_check_private_key");
    }

    /* Prefer server cipher order and disable old protocols */
    SSL_CTX_set_options(ctx, SSL_OP_CIPHER_SERVER_PREFERENCE);
    SSL_CTX_set_min_proto_version(ctx, TLS1_2_VERSION);

    lean_object *obj = lean_alloc_external(get_ssl_ctx_class(), ctx);
    return lean_io_result_mk_ok(obj);
}

/*
 * swelib_ssl_accept : conn : @& SslConn → IO UInt32
 * Performs server-side TLS handshake. Returns 1 on success, 0 on failure.
 */
LEAN_EXPORT lean_obj_res swelib_ssl_accept(
    b_lean_obj_arg conn_obj,
    lean_obj_arg world
) {
    SSL *ssl = (SSL *)lean_get_external_data(conn_obj);
    int r = SSL_accept(ssl);
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)(r == 1 ? 1 : 0)));
}

/*
 * swelib_ssl_get_peer_certificate_subject : conn : @& SslConn → IO String
 * Returns the subject DN of the peer certificate, or empty string if none.
 */
LEAN_EXPORT lean_obj_res swelib_ssl_get_peer_certificate_subject(
    b_lean_obj_arg conn_obj,
    lean_obj_arg world
) {
    SSL *ssl = (SSL *)lean_get_external_data(conn_obj);
    X509 *cert = SSL_get_peer_certificate(ssl);
    if (!cert) {
        return lean_io_result_mk_ok(lean_mk_string(""));
    }
    char buf[256];
    X509_NAME_oneline(X509_get_subject_name(cert), buf, sizeof(buf));
    X509_free(cert);
    return lean_io_result_mk_ok(lean_mk_string(buf));
}

/*
 * swelib_ssl_get_protocol_version : conn : @& SslConn → IO String
 * Returns the negotiated TLS protocol version string (e.g. "TLSv1.3").
 */
LEAN_EXPORT lean_obj_res swelib_ssl_get_protocol_version(
    b_lean_obj_arg conn_obj,
    lean_obj_arg world
) {
    SSL *ssl = (SSL *)lean_get_external_data(conn_obj);
    const char *ver = SSL_get_version(ssl);
    return lean_io_result_mk_ok(lean_mk_string(ver ? ver : "unknown"));
}

/*
 * swelib_ssl_get_cipher_name : conn : @& SslConn → IO String
 * Returns the negotiated cipher suite name.
 */
LEAN_EXPORT lean_obj_res swelib_ssl_get_cipher_name(
    b_lean_obj_arg conn_obj,
    lean_obj_arg world
) {
    SSL *ssl = (SSL *)lean_get_external_data(conn_obj);
    const char *cipher = SSL_get_cipher_name(ssl);
    return lean_io_result_mk_ok(lean_mk_string(cipher ? cipher : "unknown"));
}
