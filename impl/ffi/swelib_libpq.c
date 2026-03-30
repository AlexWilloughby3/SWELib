/*
 * swelib_libpq.c — C shim for libpq (PostgreSQL client library).
 *
 * Implements the @[extern "swelib_pq_*"] functions declared in
 * SWELibCode.Ffi.Libpq. Covers parameterized queries, prepared
 * statements, transaction control, and string escaping.
 *
 * Connection handles are passed as USize (a raw pointer to PGconn).
 * The bridge axioms (pq_connect, pq_exec, …) are implemented
 * separately at the axiom layer; this file covers the extended API.
 */

#include <lean/lean.h>
#include <libpq-fe.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

/* ── Option String helpers ───────────────────────────────────────── */

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

/* ── Row result builder ──────────────────────────────────────────── */

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

/* ── Tuple constructors ──────────────────────────────────────────── */

/*
 * Build  (UInt32 × UInt64 × String)
 * = Prod UInt32 (Prod UInt64 String)
 */
static lean_obj_res mk_u32_u64_str(uint32_t a, uint64_t b, const char *s) {
    lean_object *inner = lean_alloc_ctor(0, 2, 0);
    lean_ctor_set(inner, 0, lean_box_uint64(b));
    lean_ctor_set(inner, 1, lean_mk_string(s ? s : ""));
    lean_object *outer = lean_alloc_ctor(0, 2, 0);
    lean_ctor_set(outer, 0, lean_box_uint32(a));
    lean_ctor_set(outer, 1, inner);
    return outer;
}

/*
 * Build  (UInt32 × Array (Array (Option String)) × String)
 * = Prod UInt32 (Prod (Array …) String)
 */
static lean_obj_res mk_u32_rows_str(uint32_t status, lean_object *rows, const char *s) {
    lean_object *inner = lean_alloc_ctor(0, 2, 0);
    lean_ctor_set(inner, 0, rows);
    lean_ctor_set(inner, 1, lean_mk_string(s ? s : ""));
    lean_object *outer = lean_alloc_ctor(0, 2, 0);
    lean_ctor_set(outer, 0, lean_box_uint32(status));
    lean_ctor_set(outer, 1, inner);
    return outer;
}

/* ── Parameter extraction ────────────────────────────────────────── */

/*
 * Borrow the C-string pointers out of a Lean  Array String.
 * Returns a malloc'd array that the caller must free (may be NULL if n==0).
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

/* ── swelib_pq_exec_params ───────────────────────────────────────── */
/*
 * execParams : (connPtr : USize) → (@& query : String) → (@& params : Array String)
 *            → IO (UInt32 × UInt64 × String)
 *
 * Executes a parameterized query. Returns (statusCode, affectedRows, errorMsg).
 * statusCode mirrors ExecStatusType: PGRES_COMMAND_OK=1, PGRES_TUPLES_OK=2, …
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

/* ── swelib_pq_exec_params_rows ──────────────────────────────────── */
/*
 * execParamsRows : (connPtr : USize) → (@& query : String)
 *               → (@& params : Array String)
 *               → IO (UInt32 × Array (Array (Option String)) × String)
 *
 * Like execParams but returns the full result set.
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

/* ── swelib_pq_prepare ───────────────────────────────────────────── */
/*
 * prepare : (connPtr : USize) → (@& stmtName : String) → (@& query : String)
 *         → IO Bool
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

/* ── swelib_pq_exec_prepared ─────────────────────────────────────── */
/*
 * execPrepared : (connPtr : USize) → (@& stmtName : String)
 *              → (@& params : Array String)
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

/* ── swelib_pq_deallocate ────────────────────────────────────────── */
/*
 * deallocate : (connPtr : USize) → (@& stmtName : String) → IO Bool
 *
 * Runs "DEALLOCATE <name>" to drop a prepared statement server-side.
 * The statement name is validated to contain only identifier chars to
 * prevent injection (PQexec is used, not parameterized).
 */
LEAN_EXPORT lean_obj_res swelib_pq_deallocate(
    size_t            conn_ptr,
    b_lean_obj_arg    stmt_name,
    lean_obj_arg      world
) {
    PGconn     *conn = (PGconn *)(uintptr_t)conn_ptr;
    const char *name = lean_string_cstr(stmt_name);

    /* Validate: only alphanumeric + underscore allowed in statement name */
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

/* ── Transaction control ─────────────────────────────────────────── */

static lean_obj_res exec_simple_bool(PGconn *conn, const char *sql) {
    PGresult *res = PQexec(conn, sql);
    uint8_t ok = (PQresultStatus(res) == PGRES_COMMAND_OK) ? 1 : 0;
    PQclear(res);
    return lean_io_result_mk_ok(lean_box(ok));
}

/* begin_ : (connPtr : USize) → IO Bool */
LEAN_EXPORT lean_obj_res swelib_pq_begin(size_t conn_ptr, lean_obj_arg world) {
    return exec_simple_bool((PGconn *)(uintptr_t)conn_ptr, "BEGIN");
}

/* commit : (connPtr : USize) → IO Bool */
LEAN_EXPORT lean_obj_res swelib_pq_commit(size_t conn_ptr, lean_obj_arg world) {
    return exec_simple_bool((PGconn *)(uintptr_t)conn_ptr, "COMMIT");
}

/* rollback : (connPtr : USize) → IO Bool */
LEAN_EXPORT lean_obj_res swelib_pq_rollback(size_t conn_ptr, lean_obj_arg world) {
    return exec_simple_bool((PGconn *)(uintptr_t)conn_ptr, "ROLLBACK");
}

/* ── Version queries ─────────────────────────────────────────────── */

/* protocolVersion : (connPtr : USize) → IO UInt32 */
LEAN_EXPORT lean_obj_res swelib_pq_protocol_version(size_t conn_ptr, lean_obj_arg world) {
    PGconn *conn = (PGconn *)(uintptr_t)conn_ptr;
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)PQprotocolVersion(conn)));
}

/* serverVersion : (connPtr : USize) → IO UInt32
   Returns e.g. 170000 for PostgreSQL 17.0 */
LEAN_EXPORT lean_obj_res swelib_pq_server_version(size_t conn_ptr, lean_obj_arg world) {
    PGconn *conn = (PGconn *)(uintptr_t)conn_ptr;
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)PQserverVersion(conn)));
}

/* ── String escaping ─────────────────────────────────────────────── */

/* escapeLiteral : (connPtr : USize) → (@& str : String) → IO String */
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

/* escapeIdentifier : (connPtr : USize) → (@& str : String) → IO String */
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
