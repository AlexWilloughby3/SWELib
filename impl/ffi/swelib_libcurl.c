/*
 * swelib_libcurl.c — Minimal C shim for libcurl.
 *
 * Single function: takes method/url/headers/body, performs the request,
 * returns status/headers/body as a Lean object.
 */

#include <lean/lean.h>
#include <curl/curl.h>
#include <string.h>
#include <stdlib.h>

/* ── Write callback: appends received data to a ByteArray ────────── */

typedef struct {
    uint8_t *data;
    size_t   len;
    size_t   cap;
} Buffer;

static void buf_init(Buffer *b) {
    b->data = NULL;
    b->len  = 0;
    b->cap  = 0;
}

static void buf_free(Buffer *b) {
    free(b->data);
    b->data = NULL;
    b->len = b->cap = 0;
}

static int buf_append(Buffer *b, const void *src, size_t n) {
    if (b->len + n > b->cap) {
        size_t newcap = (b->cap == 0) ? 4096 : b->cap * 2;
        while (newcap < b->len + n) newcap *= 2;
        uint8_t *p = realloc(b->data, newcap);
        if (!p) return -1;
        b->data = p;
        b->cap  = newcap;
    }
    memcpy(b->data + b->len, src, n);
    b->len += n;
    return 0;
}

static size_t write_cb(char *ptr, size_t size, size_t nmemb, void *userdata) {
    Buffer *b = (Buffer *)userdata;
    size_t total = size * nmemb;
    if (buf_append(b, ptr, total) < 0) return 0;
    return total;
}

static size_t header_cb(char *ptr, size_t size, size_t nmemb, void *userdata) {
    Buffer *b = (Buffer *)userdata;
    size_t total = size * nmemb;
    if (buf_append(b, ptr, total) < 0) return 0;
    return total;
}

/* ── Helper: Lean ByteArray from buffer ──────────────────────────── */

static lean_obj_res mk_byte_array(const uint8_t *data, size_t len) {
    lean_object *arr = lean_alloc_sarray(1, len, len);
    if (data && len > 0) {
        memcpy(lean_sarray_cptr(arr), data, len);
    }
    return arr;
}

/* ── Helper: Lean String from C string ───────────────────────────── */

static lean_obj_res mk_lean_string(const char *s) {
    return lean_mk_string(s);
}

/* ── Main FFI function ───────────────────────────────────────────── */

/*
 * swelib_curl_perform :
 *   method  : @& String    — "GET", "POST", etc.
 *   url     : @& String    — full URL
 *   headers : @& Array String  — ["Header: Value", ...]
 *   body    : @& ByteArray — request body (may be empty)
 *   IO (UInt32 × ByteArray × ByteArray)
 *       = (statusCode, responseHeaders, responseBody)
 */
LEAN_EXPORT lean_obj_res swelib_curl_perform(
    b_lean_obj_arg method,
    b_lean_obj_arg url,
    b_lean_obj_arg headers_arr,
    b_lean_obj_arg body,
    lean_obj_arg world
) {
    const char *c_method  = lean_string_cstr(method);
    const char *c_url     = lean_string_cstr(url);
    size_t body_len       = lean_sarray_size(body);
    const uint8_t *body_p = lean_sarray_cptr(body);

    CURL *curl = curl_easy_init();
    if (!curl) {
        lean_object *err = lean_mk_io_user_error(
            mk_lean_string("curl_easy_init failed"));
        return lean_io_result_mk_error(err);
    }

    curl_easy_setopt(curl, CURLOPT_URL, c_url);
    curl_easy_setopt(curl, CURLOPT_CUSTOMREQUEST, c_method);

    /* Set request body if non-empty */
    if (body_len > 0) {
        curl_easy_setopt(curl, CURLOPT_POSTFIELDS, body_p);
        curl_easy_setopt(curl, CURLOPT_POSTFIELDSIZE, (long)body_len);
    }

    /* Set headers */
    struct curl_slist *slist = NULL;
    size_t n_headers = lean_array_size(headers_arr);
    for (size_t i = 0; i < n_headers; i++) {
        lean_object *h = lean_array_get_core(headers_arr, i);
        slist = curl_slist_append(slist, lean_string_cstr(h));
    }
    if (slist) {
        curl_easy_setopt(curl, CURLOPT_HTTPHEADER, slist);
    }

    /* Follow redirects */
    curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 0L);

    /* Buffers for response */
    Buffer resp_body, resp_hdrs;
    buf_init(&resp_body);
    buf_init(&resp_hdrs);

    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, write_cb);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &resp_body);
    curl_easy_setopt(curl, CURLOPT_HEADERFUNCTION, header_cb);
    curl_easy_setopt(curl, CURLOPT_HEADERDATA, &resp_hdrs);

    CURLcode res = curl_easy_perform(curl);

    if (res != CURLE_OK) {
        const char *errmsg = curl_easy_strerror(res);
        buf_free(&resp_body);
        buf_free(&resp_hdrs);
        curl_slist_free_all(slist);
        curl_easy_cleanup(curl);
        lean_object *err = lean_mk_io_user_error(mk_lean_string(errmsg));
        return lean_io_result_mk_error(err);
    }

    long status_code = 0;
    curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &status_code);

    curl_slist_free_all(slist);
    curl_easy_cleanup(curl);

    /* Build result tuple: (UInt32 × ByteArray × ByteArray) */
    lean_object *status_obj = lean_box_uint32((uint32_t)status_code);
    lean_object *hdrs_obj   = mk_byte_array(resp_hdrs.data, resp_hdrs.len);
    lean_object *body_obj   = mk_byte_array(resp_body.data, resp_body.len);

    buf_free(&resp_body);
    buf_free(&resp_hdrs);

    /* Build (ByteArray × ByteArray) */
    lean_object *inner = lean_alloc_ctor(0, 2, 0);
    lean_ctor_set(inner, 0, hdrs_obj);
    lean_ctor_set(inner, 1, body_obj);

    /* Build (UInt32 × ByteArray × ByteArray) */
    lean_object *outer = lean_alloc_ctor(0, 2, 0);
    lean_ctor_set(outer, 0, status_obj);
    lean_ctor_set(outer, 1, inner);

    return lean_io_result_mk_ok(outer);
}
