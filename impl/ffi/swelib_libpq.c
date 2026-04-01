/*
 * swelib_libpq.c — C shim for libpq (PostgreSQL client library).
 *
 * Implements both:
 *   1. Bridge @[extern] functions from SWELibImpl.Bridge.Libpq
 *      (connection management: connect, exec, status, close, etc.)
 *   2. FFI @[extern] functions from SWELibImpl.Ffi.Libpq
 *      (parameterized queries, prepared statements, transactions, escaping)
 *
 * Bridge functions operate on ConnectionHandle (lean_external_object wrapping PGconn*).
 * FFI functions operate on USize (raw PGconn* pointer).
 */

#include <lean/lean.h>
#include <libpq-fe.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

/* ════════════════════════════════════════════════════════════════════
 * External object classes
 * ════════════════════════════════════════════════════════════════════ */

/* ── PGconn external object ─────────────────────────────────────── */

static void pgconn_finalize(void *ptr) {
    if (ptr) PQfinish((PGconn *)ptr);
}

static void pgconn_foreach(void *ptr, b_lean_obj_arg f) {
    (void)ptr; (void)f;
}

static lean_external_class *g_pgconn_class = NULL;

static lean_external_class *get_pgconn_class(void) {
    if (!g_pgconn_class) {
        g_pgconn_class = lean_register_external_class(pgconn_finalize, pgconn_foreach);
    }
    return g_pgconn_class;
}

/* ── PGresult external object (for QueryResult) ─────────────────── */

static void pgresult_finalize(void *ptr) {
    if (ptr) PQclear((PGresult *)ptr);
}

static void pgresult_foreach(void *ptr, b_lean_obj_arg f) {
    (void)ptr; (void)f;
}

static lean_external_class *g_pgresult_class = NULL;

static lean_external_class *get_pgresult_class(void) {
    if (!g_pgresult_class) {
        g_pgresult_class = lean_register_external_class(pgresult_finalize, pgresult_foreach);
    }
    return g_pgresult_class;
}

/* ════════════════════════════════════════════════════════════════════
 * Helpers
 * ════════════════════════════════════════════════════════════════════ */

/* Option.none  (tag 0, no payload) */
static inline lean_obj_res mk_none(void) {
    return lean_box(0);
}

/* Option.some s  (tag 1, one payload field) */
static inline lean_obj_res mk_some_string(const char *s) {
    lean_object *obj = lean_alloc_ctor(1, 1, 0);
    lean_ctor_set(obj, 0, lean_mk_string(s ? s : ""));
    return obj;
}

/* Extract a String from Option String, or NULL for none. */
static const char *option_string_val(b_lean_obj_arg opt) {
    if (lean_obj_tag(opt) == 0) return NULL;
    return lean_string_cstr(lean_ctor_get(opt, 0));
}

/*
 * Build  Array (Array (Option String))  from a PGresult.
 * Each inner array is one row; each cell is Option String.
 */
static lean_obj_res mk_rows(PGresult *res) {
    int nrows = PQntuples(res);
    int ncols = PQnfields(res);
    lean_object *outer = lean_alloc_array((size_t)nrows, (size_t)nrows);
    for (int r = 0; r < nrows; r++) {
        lean_object *inner = lean_alloc_array((size_t)ncols, (size_t)ncols);
        for (int c = 0; c < ncols; c++) {
            lean_object *cell = PQgetisnull(res, r, c)
                ? mk_none()
                : mk_some_string(PQgetvalue(res, r, c));
            lean_array_set_core(inner, (size_t)c, cell);
        }
        lean_array_set_core(outer, (size_t)r, inner);
    }
    return outer;
}

/* Build  (UInt32 × UInt64 × String) */
static lean_obj_res mk_u32_u64_str(uint32_t a, uint64_t b, const char *s) {
    lean_object *inner = lean_alloc_ctor(0, 2, 0);
    lean_ctor_set(inner, 0, lean_box_uint64(b));
    lean_ctor_set(inner, 1, lean_mk_string(s ? s : ""));
    lean_object *outer = lean_alloc_ctor(0, 2, 0);
    lean_ctor_set(outer, 0, lean_box_uint32(a));
    lean_ctor_set(outer, 1, inner);
    return outer;
}

/* Build  (UInt32 × Array (Array (Option String)) × String) */
static lean_obj_res mk_u32_rows_str(uint32_t status, lean_object *rows, const char *s) {
    lean_object *inner = lean_alloc_ctor(0, 2, 0);
    lean_ctor_set(inner, 0, rows);
    lean_ctor_set(inner, 1, lean_mk_string(s ? s : ""));
    lean_object *outer = lean_alloc_ctor(0, 2, 0);
    lean_ctor_set(outer, 0, lean_box_uint32(status));
    lean_ctor_set(outer, 1, inner);
    return outer;
}

/*
 * Borrow C-string pointers from a Lean Array String.
 * Returns a malloc'd array (caller must free). NULL if n==0.
 */
static const char **borrow_params(b_lean_obj_arg arr, size_t *out_n) {
    size_t n = lean_array_size(arr);
    *out_n = n;
    if (n == 0) return NULL;
    const char **ps = (const char **)malloc(n * sizeof(const char *));
    for (size_t i = 0; i < n; i++)
        ps[i] = lean_string_cstr(lean_array_get_core(arr, i));
    return ps;
}

/* ════════════════════════════════════════════════════════════════════
 * Bridge functions (SWELibImpl.Bridge.Libpq)
 *
 * These operate on ConnectionHandle (lean_external_object wrapping PGconn*).
 * ════════════════════════════════════════════════════════════════════ */

/* ── swelib_pq_connect ─────────────────────────────────────────────
 * ConnectionParameters → IO (Option ConnectionHandle)
 *
 * ConnectionParameters fields (in struct order):
 *   host, port, dbname, user, password, connect_timeout,
 *   sslmode, sslrootcert, sslcert, sslkey, target_session_attrs
 */
LEAN_EXPORT lean_obj_res swelib_pq_connect(b_lean_obj_arg params, lean_obj_arg world) {
    b_lean_obj_arg host_opt     = lean_ctor_get(params, 0);
    b_lean_obj_arg port_opt     = lean_ctor_get(params, 1);
    b_lean_obj_arg dbname_opt   = lean_ctor_get(params, 2);
    b_lean_obj_arg user_opt     = lean_ctor_get(params, 3);
    b_lean_obj_arg password_opt = lean_ctor_get(params, 4);

    const char *host     = option_string_val(host_opt);
    const char *dbname   = option_string_val(dbname_opt);
    const char *user     = option_string_val(user_opt);
    const char *password = option_string_val(password_opt);

    char conninfo[1024];
    int off = 0;
    if (host)     off += snprintf(conninfo + off, sizeof(conninfo) - off, "host=%s ", host);
    if (dbname)   off += snprintf(conninfo + off, sizeof(conninfo) - off, "dbname=%s ", dbname);
    if (user)     off += snprintf(conninfo + off, sizeof(conninfo) - off, "user=%s ", user);
    if (password) off += snprintf(conninfo + off, sizeof(conninfo) - off, "password=%s ", password);

    if (lean_obj_tag(port_opt) == 1) {
        lean_object *nat = lean_ctor_get(port_opt, 0);
        size_t port = lean_unbox(nat);
        off += snprintf(conninfo + off, sizeof(conninfo) - off, "port=%zu ", port);
    }

    if (off == 0) conninfo[0] = '\0';

    PGconn *conn = PQconnectdb(conninfo);
    if (!conn) {
        return lean_io_result_mk_ok(lean_box(0));
    }
    if (PQstatus(conn) != CONNECTION_OK) {
        PQfinish(conn);
        return lean_io_result_mk_ok(lean_box(0));
    }

    lean_object *handle = lean_alloc_external(get_pgconn_class(), conn);
    lean_object *some = lean_alloc_ctor(1, 1, 0);
    lean_ctor_set(some, 0, handle);
    return lean_io_result_mk_ok(some);
}

/* ── swelib_pq_status ──────────────────────────────────────────────
 * ConnectionHandle → IO ConnectionStatus
 * ConnectionStatus is an inductive with 12 constructors (tags 0..11).
 */
LEAN_EXPORT lean_obj_res swelib_pq_status(b_lean_obj_arg handle, lean_obj_arg world) {
    PGconn *conn = (PGconn *)lean_get_external_data(handle);
    ConnStatusType s = PQstatus(conn);
    unsigned tag;
    switch (s) {
        case CONNECTION_OK:                 tag = 0; break;
        case CONNECTION_BAD:                tag = 1; break;
        case CONNECTION_STARTED:            tag = 2; break;
        case CONNECTION_MADE:               tag = 3; break;
        case CONNECTION_AWAITING_RESPONSE:  tag = 4; break;
        case CONNECTION_AUTH_OK:            tag = 5; break;
        case CONNECTION_SSL_STARTUP:        tag = 6; break;
#ifdef CONNECTION_GSS_STARTUP
        case CONNECTION_GSS_STARTUP:        tag = 7; break;
#endif
        case CONNECTION_CHECK_WRITABLE:     tag = 8; break;
        case CONNECTION_CHECK_STANDBY:      tag = 9; break;
        case CONNECTION_CONSUME:            tag = 10; break;
        case CONNECTION_SETENV:             tag = 11; break;
        default:                            tag = 1; break;
    }
    return lean_io_result_mk_ok(lean_box(tag));
}

/* ── swelib_pq_close ───────────────────────────────────────────────
 * ConnectionHandle → IO Unit
 */
LEAN_EXPORT lean_obj_res swelib_pq_close(lean_obj_arg handle, lean_obj_arg world) {
    PGconn *conn = (PGconn *)lean_get_external_data(handle);
    if (conn) {
        PQfinish(conn);
        lean_set_external_data(handle, NULL);
    }
    lean_dec_ref(handle);
    return lean_io_result_mk_ok(lean_box(0));
}

/* ── swelib_pq_reset ───────────────────────────────────────────────
 * ConnectionHandle → IO Bool
 */
LEAN_EXPORT lean_obj_res swelib_pq_reset(lean_obj_arg handle, lean_obj_arg world) {
    PGconn *conn = (PGconn *)lean_get_external_data(handle);
    PQreset(conn);
    int ok = (PQstatus(conn) == CONNECTION_OK);
    return lean_io_result_mk_ok(lean_box(ok ? 1 : 0));
}

/* ── swelib_pq_ping ────────────────────────────────────────────────
 * ConnectionHandle → IO Bool
 */
LEAN_EXPORT lean_obj_res swelib_pq_ping(b_lean_obj_arg handle, lean_obj_arg world) {
    PGconn *conn = (PGconn *)lean_get_external_data(handle);
    PGresult *res = PQexec(conn, "SELECT 1");
    if (!res) return lean_io_result_mk_ok(lean_box(0));
    int ok = (PQresultStatus(res) == PGRES_TUPLES_OK);
    PQclear(res);
    return lean_io_result_mk_ok(lean_box(ok ? 1 : 0));
}

/* ── swelib_pq_exec ────────────────────────────────────────────────
 * ConnectionHandle → String → IO (Option QueryResult)
 */
LEAN_EXPORT lean_obj_res swelib_pq_exec(b_lean_obj_arg handle, b_lean_obj_arg sql, lean_obj_arg world) {
    PGconn *conn = (PGconn *)lean_get_external_data(handle);
    const char *query = lean_string_cstr(sql);

    PGresult *result = PQexec(conn, query);
    if (!result) {
        return lean_io_result_mk_ok(lean_box(0));
    }

    ExecStatusType s = PQresultStatus(result);
    if (s == PGRES_COMMAND_OK || s == PGRES_TUPLES_OK) {
        lean_object *ext = lean_alloc_external(get_pgresult_class(), result);
        lean_object *some = lean_alloc_ctor(1, 1, 0);
        lean_ctor_set(some, 0, ext);
        return lean_io_result_mk_ok(some);
    }

    PQclear(result);
    return lean_io_result_mk_ok(lean_box(0));
}

/* ── swelib_pq_validate ────────────────────────────────────────────
 * ConnectionHandle → IO Bool
 */
LEAN_EXPORT lean_obj_res swelib_pq_validate(b_lean_obj_arg handle, lean_obj_arg world) {
    PGconn *conn = (PGconn *)lean_get_external_data(handle);
    PGresult *res = PQexec(conn, "SELECT 1");
    if (!res) return lean_io_result_mk_ok(lean_box(0));
    int ok = (PQresultStatus(res) == PGRES_TUPLES_OK);
    PQclear(res);
    return lean_io_result_mk_ok(lean_box(ok ? 1 : 0));
}

/* ── swelib_pq_error_message ───────────────────────────────────────
 * ConnectionHandle → IO String
 */
LEAN_EXPORT lean_obj_res swelib_pq_error_message(b_lean_obj_arg handle, lean_obj_arg world) {
    PGconn *conn = (PGconn *)lean_get_external_data(handle);
    const char *msg = conn ? PQerrorMessage(conn) : "null connection";
    return lean_io_result_mk_ok(lean_mk_string(msg));
}

/* ── swelib_pq_is_writable ─────────────────────────────────────────
 * ConnectionHandle → IO Bool
 */
LEAN_EXPORT lean_obj_res swelib_pq_is_writable(b_lean_obj_arg handle, lean_obj_arg world) {
    PGconn *conn = (PGconn *)lean_get_external_data(handle);
    return lean_io_result_mk_ok(lean_box(PQstatus(conn) == CONNECTION_OK ? 1 : 0));
}

/* ── swelib_pq_is_readable ─────────────────────────────────────────
 * ConnectionHandle → IO Bool
 */
LEAN_EXPORT lean_obj_res swelib_pq_is_readable(b_lean_obj_arg handle, lean_obj_arg world) {
    PGconn *conn = (PGconn *)lean_get_external_data(handle);
    return lean_io_result_mk_ok(lean_box(PQstatus(conn) == CONNECTION_OK ? 1 : 0));
}

/* ── swelib_conn_handle_to_usize ───────────────────────────────────
 * ConnectionHandle → USize
 * Extract the raw PGconn* for use with the FFI parameterized query layer.
 */
LEAN_EXPORT size_t swelib_conn_handle_to_usize(b_lean_obj_arg handle) {
    return (size_t)lean_get_external_data(handle);
}

/* ── Validation bridge stubs (SWELibImpl.Bridge.Libpq.Validation) ── */

/* swelib_pq_validate_with_timeout : ConnectionHandle → Nat → IO Bool */
LEAN_EXPORT lean_obj_res swelib_pq_validate_with_timeout(b_lean_obj_arg handle, size_t timeout_ms, lean_obj_arg world) {
    /* Simple implementation: ignore timeout, just validate */
    PGconn *conn = (PGconn *)lean_get_external_data(handle);
    PGresult *res = PQexec(conn, "SELECT 1");
    if (!res) return lean_io_result_mk_ok(lean_box(0));
    int ok = (PQresultStatus(res) == PGRES_TUPLES_OK);
    PQclear(res);
    return lean_io_result_mk_ok(lean_box(ok ? 1 : 0));
}

/* swelib_pq_is_idle_too_long : ConnectionHandle → Nat → IO Bool */
LEAN_EXPORT lean_obj_res swelib_pq_is_idle_too_long(b_lean_obj_arg handle, size_t idle_timeout, lean_obj_arg world) {
    (void)handle; (void)idle_timeout;
    return lean_io_result_mk_ok(lean_box(0)); /* stub: always false */
}

/* swelib_pq_is_connection_expired : ConnectionHandle → Nat → IO Bool */
LEAN_EXPORT lean_obj_res swelib_pq_is_connection_expired(b_lean_obj_arg handle, size_t max_lifetime, lean_obj_arg world) {
    (void)handle; (void)max_lifetime;
    return lean_io_result_mk_ok(lean_box(0)); /* stub: always false */
}

/* swelib_pq_quick_health_check : ConnectionHandle → IO Bool */
LEAN_EXPORT lean_obj_res swelib_pq_quick_health_check(b_lean_obj_arg handle, lean_obj_arg world) {
    PGconn *conn = (PGconn *)lean_get_external_data(handle);
    return lean_io_result_mk_ok(lean_box(PQstatus(conn) == CONNECTION_OK ? 1 : 0));
}

/* ════════════════════════════════════════════════════════════════════
 * FFI functions (SWELibImpl.Ffi.Libpq)
 *
 * These operate on USize (raw PGconn* pointer) for parameterized queries.
 * ════════════════════════════════════════════════════════════════════ */

/* ── swelib_pq_exec_params ─────────────────────────────────────────
 * execParams : USize → @& String → @& Array String
 *            → IO (UInt32 × UInt64 × String)
 */
LEAN_EXPORT lean_obj_res swelib_pq_exec_params(
    size_t            conn_ptr,
    b_lean_obj_arg    query,
    b_lean_obj_arg    params_arr,
    lean_obj_arg      world
) {
    PGconn *conn = (PGconn *)(uintptr_t)conn_ptr;
    size_t n;
    const char **params = borrow_params(params_arr, &n);

    PGresult *res = PQexecParams(conn, lean_string_cstr(query),
                                 (int)n, NULL, params, NULL, NULL, 0);
    free(params);

    ExecStatusType st  = PQresultStatus(res);
    const char *cmd    = PQcmdTuples(res);
    uint64_t    count  = (cmd && *cmd) ? (uint64_t)strtoull(cmd, NULL, 10) : 0;
    const char *errmsg = PQresultErrorMessage(res);

    lean_obj_res result = mk_u32_u64_str((uint32_t)st, count, errmsg);
    PQclear(res);
    return lean_io_result_mk_ok(result);
}

/* ── swelib_pq_exec_params_rows ────────────────────────────────────
 * execParamsRows : USize → @& String → @& Array String
 *                → IO (UInt32 × Array (Array (Option String)) × String)
 */
LEAN_EXPORT lean_obj_res swelib_pq_exec_params_rows(
    size_t            conn_ptr,
    b_lean_obj_arg    query,
    b_lean_obj_arg    params_arr,
    lean_obj_arg      world
) {
    PGconn *conn = (PGconn *)(uintptr_t)conn_ptr;
    size_t n;
    const char **params = borrow_params(params_arr, &n);

    PGresult *res = PQexecParams(conn, lean_string_cstr(query),
                                 (int)n, NULL, params, NULL, NULL, 0);
    free(params);

    ExecStatusType st  = PQresultStatus(res);
    const char *errmsg = PQresultErrorMessage(res);
    lean_object *rows  = (st == PGRES_TUPLES_OK)
                         ? mk_rows(res)
                         : lean_alloc_array(0, 0);

    lean_obj_res result = mk_u32_rows_str((uint32_t)st, rows, errmsg);
    PQclear(res);
    return lean_io_result_mk_ok(result);
}

/* ── swelib_pq_prepare ─────────────────────────────────────────────
 * prepare : USize → @& String → @& String → IO Bool
 */
LEAN_EXPORT lean_obj_res swelib_pq_prepare(
    size_t            conn_ptr,
    b_lean_obj_arg    stmt_name,
    b_lean_obj_arg    query,
    lean_obj_arg      world
) {
    PGconn   *conn = (PGconn *)(uintptr_t)conn_ptr;
    PGresult *res  = PQprepare(conn,
                               lean_string_cstr(stmt_name),
                               lean_string_cstr(query),
                               0, NULL);
    uint8_t ok = (PQresultStatus(res) == PGRES_COMMAND_OK) ? 1 : 0;
    PQclear(res);
    return lean_io_result_mk_ok(lean_box(ok));
}

/* ── swelib_pq_exec_prepared ───────────────────────────────────────
 * execPrepared : USize → @& String → @& Array String
 *              → IO (UInt32 × Array (Array (Option String)) × String)
 */
LEAN_EXPORT lean_obj_res swelib_pq_exec_prepared(
    size_t            conn_ptr,
    b_lean_obj_arg    stmt_name,
    b_lean_obj_arg    params_arr,
    lean_obj_arg      world
) {
    PGconn *conn = (PGconn *)(uintptr_t)conn_ptr;
    size_t n;
    const char **params = borrow_params(params_arr, &n);

    PGresult *res = PQexecPrepared(conn,
                                   lean_string_cstr(stmt_name),
                                   (int)n, params, NULL, NULL, 0);
    free(params);

    ExecStatusType st  = PQresultStatus(res);
    const char *errmsg = PQresultErrorMessage(res);
    lean_object *rows  = (st == PGRES_TUPLES_OK)
                         ? mk_rows(res)
                         : lean_alloc_array(0, 0);

    lean_obj_res result = mk_u32_rows_str((uint32_t)st, rows, errmsg);
    PQclear(res);
    return lean_io_result_mk_ok(result);
}

/* ── swelib_pq_deallocate ──────────────────────────────────────────
 * deallocate : USize → @& String → IO Bool
 */
LEAN_EXPORT lean_obj_res swelib_pq_deallocate(
    size_t            conn_ptr,
    b_lean_obj_arg    stmt_name,
    lean_obj_arg      world
) {
    PGconn     *conn = (PGconn *)(uintptr_t)conn_ptr;
    const char *name = lean_string_cstr(stmt_name);

    for (const char *p = name; *p; p++) {
        if (!((*p >= 'a' && *p <= 'z') || (*p >= 'A' && *p <= 'Z') ||
              (*p >= '0' && *p <= '9') || *p == '_')) {
            return lean_io_result_mk_ok(lean_box(0));
        }
    }

    char buf[300];
    snprintf(buf, sizeof(buf), "DEALLOCATE %s", name);
    PGresult *res = PQexec(conn, buf);
    uint8_t ok = (PQresultStatus(res) == PGRES_COMMAND_OK) ? 1 : 0;
    PQclear(res);
    return lean_io_result_mk_ok(lean_box(ok));
}

/* ── Transaction control ───────────────────────────────────────────── */

static lean_obj_res exec_simple_bool(PGconn *conn, const char *sql) {
    PGresult *res = PQexec(conn, sql);
    uint8_t ok = (PQresultStatus(res) == PGRES_COMMAND_OK) ? 1 : 0;
    PQclear(res);
    return lean_io_result_mk_ok(lean_box(ok));
}

LEAN_EXPORT lean_obj_res swelib_pq_begin(size_t conn_ptr, lean_obj_arg world) {
    return exec_simple_bool((PGconn *)(uintptr_t)conn_ptr, "BEGIN");
}

LEAN_EXPORT lean_obj_res swelib_pq_commit(size_t conn_ptr, lean_obj_arg world) {
    return exec_simple_bool((PGconn *)(uintptr_t)conn_ptr, "COMMIT");
}

LEAN_EXPORT lean_obj_res swelib_pq_rollback(size_t conn_ptr, lean_obj_arg world) {
    return exec_simple_bool((PGconn *)(uintptr_t)conn_ptr, "ROLLBACK");
}

/* ── Version queries ───────────────────────────────────────────────── */

LEAN_EXPORT lean_obj_res swelib_pq_protocol_version(size_t conn_ptr, lean_obj_arg world) {
    PGconn *conn = (PGconn *)(uintptr_t)conn_ptr;
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)PQprotocolVersion(conn)));
}

LEAN_EXPORT lean_obj_res swelib_pq_server_version(size_t conn_ptr, lean_obj_arg world) {
    PGconn *conn = (PGconn *)(uintptr_t)conn_ptr;
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)PQserverVersion(conn)));
}

/* ── String escaping ───────────────────────────────────────────────── */

LEAN_EXPORT lean_obj_res swelib_pq_escape_literal(
    size_t            conn_ptr,
    b_lean_obj_arg    str,
    lean_obj_arg      world
) {
    PGconn     *conn = (PGconn *)(uintptr_t)conn_ptr;
    const char *s    = lean_string_cstr(str);
    char       *esc  = PQescapeLiteral(conn, s, strlen(s));
    lean_object *res = lean_mk_string(esc ? esc : s);
    if (esc) PQfreemem(esc);
    return lean_io_result_mk_ok(res);
}

LEAN_EXPORT lean_obj_res swelib_pq_escape_identifier(
    size_t            conn_ptr,
    b_lean_obj_arg    str,
    lean_obj_arg      world
) {
    PGconn     *conn = (PGconn *)(uintptr_t)conn_ptr;
    const char *s    = lean_string_cstr(str);
    char       *esc  = PQescapeIdentifier(conn, s, strlen(s));
    lean_object *res = lean_mk_string(esc ? esc : s);
    if (esc) PQfreemem(esc);
    return lean_io_result_mk_ok(res);
}
