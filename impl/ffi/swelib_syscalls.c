/*
 * swelib_syscalls.c — C shims for POSIX socket syscalls.
 *
 * Wraps socket, connect, bind, listen, accept, send, recv, close,
 * setsockopt, and getaddrinfo for Lean FFI.
 */

#include <lean/lean.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <netdb.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <arpa/inet.h>
#include <fcntl.h>
#include <signal.h>
#include <sys/mman.h>
#include <stdint.h>

/* ── Errno mapping ───────────────────────────────────────────────── */

/* Map C errno to our Lean Errno constructors:
   EBADF=0, EINTR=1, EIO=2, EACCES=3, ENOENT=4, EEXIST=5,
   EISDIR=6, ENOTDIR=7, EINVAL=8, EMFILE=9, EROFS=10, ENOSPC=11 */
static uint8_t map_errno(int e) {
    switch (e) {
        case EBADF:   return 0;
        case EINTR:   return 1;
        case EIO:     return 2;
        case EACCES:  return 3;
        case ENOENT:  return 4;
        case EEXIST:  return 5;
        case EISDIR:  return 6;
        case ENOTDIR: return 7;
        case EINVAL:  return 8;
        case EMFILE:  return 9;
        case EROFS:   return 10;
        case ENOSPC:  return 11;
        default:      return 2; /* fallback to EIO */
    }
}

/* Build Except.error Errno */
static lean_obj_res mk_errno_error(int e) {
    lean_object *errno_val = lean_box(map_errno(e));
    lean_object *except = lean_alloc_ctor(1, 1, 0); /* Except.error */
    lean_ctor_set(except, 0, errno_val);
    return except;
}

/* Build Except.ok val */
static lean_obj_res mk_except_ok(lean_obj_arg val) {
    lean_object *except = lean_alloc_ctor(0, 1, 0); /* Except.ok */
    lean_ctor_set(except, 0, val);
    return except;
}

/* ── Socket operations ───────────────────────────────────────────── */

/*
 * swelib_socket : domain : UInt32 → type_ : UInt32 → protocol : UInt32
 *                 → IO (Except Errno UInt32)
 */
LEAN_EXPORT lean_obj_res swelib_socket(
    uint32_t domain, uint32_t type_, uint32_t protocol,
    lean_obj_arg world
) {
    int fd = socket((int)domain, (int)type_, (int)protocol);
    if (fd < 0) {
        return lean_io_result_mk_ok(mk_errno_error(errno));
    }
    return lean_io_result_mk_ok(mk_except_ok(lean_box_uint32((uint32_t)fd)));
}

/*
 * swelib_connect : fd : UInt32 → host : @& String → port : UInt16
 *                  → IO (Except Errno Unit)
 */
LEAN_EXPORT lean_obj_res swelib_connect(
    uint32_t fd, b_lean_obj_arg host, uint16_t port,
    lean_obj_arg world
) {
    const char *c_host = lean_string_cstr(host);

    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port = htons(port);

    if (inet_pton(AF_INET, c_host, &addr.sin_addr) != 1) {
        /* Try IPv6 */
        struct sockaddr_in6 addr6;
        memset(&addr6, 0, sizeof(addr6));
        addr6.sin6_family = AF_INET6;
        addr6.sin6_port = htons(port);
        if (inet_pton(AF_INET6, c_host, &addr6.sin6_addr) == 1) {
            int r = connect((int)fd, (struct sockaddr *)&addr6, sizeof(addr6));
            if (r < 0) return lean_io_result_mk_ok(mk_errno_error(errno));
            return lean_io_result_mk_ok(mk_except_ok(lean_box(0)));
        }
        /* Invalid address */
        return lean_io_result_mk_ok(mk_errno_error(EINVAL));
    }

    int r = connect((int)fd, (struct sockaddr *)&addr, sizeof(addr));
    if (r < 0) return lean_io_result_mk_ok(mk_errno_error(errno));
    return lean_io_result_mk_ok(mk_except_ok(lean_box(0)));
}

/*
 * swelib_bind : fd : UInt32 → host : @& String → port : UInt16
 *               → IO (Except Errno Unit)
 */
LEAN_EXPORT lean_obj_res swelib_bind(
    uint32_t fd, b_lean_obj_arg host, uint16_t port,
    lean_obj_arg world
) {
    const char *c_host = lean_string_cstr(host);

    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port = htons(port);

    if (strcmp(c_host, "0.0.0.0") == 0 || strcmp(c_host, "") == 0) {
        addr.sin_addr.s_addr = INADDR_ANY;
    } else {
        if (inet_pton(AF_INET, c_host, &addr.sin_addr) != 1) {
            return lean_io_result_mk_ok(mk_errno_error(EINVAL));
        }
    }

    int r = bind((int)fd, (struct sockaddr *)&addr, sizeof(addr));
    if (r < 0) return lean_io_result_mk_ok(mk_errno_error(errno));
    return lean_io_result_mk_ok(mk_except_ok(lean_box(0)));
}

/*
 * swelib_listen : fd : UInt32 → backlog : UInt32 → IO (Except Errno Unit)
 */
LEAN_EXPORT lean_obj_res swelib_listen(
    uint32_t fd, uint32_t backlog,
    lean_obj_arg world
) {
    int r = listen((int)fd, (int)backlog);
    if (r < 0) return lean_io_result_mk_ok(mk_errno_error(errno));
    return lean_io_result_mk_ok(mk_except_ok(lean_box(0)));
}

/*
 * swelib_accept : fd : UInt32 → IO (Except Errno (UInt32 × String × UInt16))
 *   Returns (client_fd, client_ip, client_port)
 */
LEAN_EXPORT lean_obj_res swelib_accept(
    uint32_t fd,
    lean_obj_arg world
) {
    struct sockaddr_in addr;
    socklen_t addrlen = sizeof(addr);
    int client = accept((int)fd, (struct sockaddr *)&addr, &addrlen);
    if (client < 0) return lean_io_result_mk_ok(mk_errno_error(errno));

    char ip[INET_ADDRSTRLEN];
    inet_ntop(AF_INET, &addr.sin_addr, ip, sizeof(ip));
    uint16_t port = ntohs(addr.sin_port);

    lean_object *fd_obj   = lean_box_uint32((uint32_t)client);
    lean_object *ip_obj   = lean_mk_string(ip);
    lean_object *port_obj = lean_box_uint32((uint32_t)port);

    /* (String × UInt16) */
    lean_object *inner = lean_alloc_ctor(0, 2, 0);
    lean_ctor_set(inner, 0, ip_obj);
    lean_ctor_set(inner, 1, port_obj);

    /* (UInt32 × String × UInt16) */
    lean_object *outer = lean_alloc_ctor(0, 2, 0);
    lean_ctor_set(outer, 0, fd_obj);
    lean_ctor_set(outer, 1, inner);

    return lean_io_result_mk_ok(mk_except_ok(outer));
}

/*
 * swelib_send : fd : UInt32 → data : @& ByteArray → IO (Except Errno USize)
 */
LEAN_EXPORT lean_obj_res swelib_send(
    uint32_t fd, b_lean_obj_arg data,
    lean_obj_arg world
) {
    size_t len = lean_sarray_size(data);
    const uint8_t *ptr = lean_sarray_cptr(data);
    ssize_t sent = send((int)fd, ptr, len, 0);
    if (sent < 0) return lean_io_result_mk_ok(mk_errno_error(errno));
    return lean_io_result_mk_ok(mk_except_ok(lean_box_usize((size_t)sent)));
}

/*
 * swelib_recv : fd : UInt32 → maxBytes : USize → IO (Except Errno ByteArray)
 */
LEAN_EXPORT lean_obj_res swelib_recv(
    uint32_t fd, size_t maxBytes,
    lean_obj_arg world
) {
    uint8_t *buf = malloc(maxBytes);
    if (!buf) return lean_io_result_mk_ok(mk_errno_error(ENOSPC));

    ssize_t n = recv((int)fd, buf, maxBytes, 0);
    if (n < 0) {
        free(buf);
        return lean_io_result_mk_ok(mk_errno_error(errno));
    }

    lean_object *arr = lean_alloc_sarray(1, (size_t)n, (size_t)n);
    if (n > 0) memcpy(lean_sarray_cptr(arr), buf, (size_t)n);
    free(buf);

    return lean_io_result_mk_ok(mk_except_ok(arr));
}

/*
 * swelib_setsockopt_int : fd : UInt32 → level : UInt32 → optname : UInt32
 *                         → value : UInt32 → IO (Except Errno Unit)
 */
LEAN_EXPORT lean_obj_res swelib_setsockopt_int(
    uint32_t fd, uint32_t level, uint32_t optname, uint32_t value,
    lean_obj_arg world
) {
    int val = (int)value;
    int r = setsockopt((int)fd, (int)level, (int)optname, &val, sizeof(val));
    if (r < 0) return lean_io_result_mk_ok(mk_errno_error(errno));
    return lean_io_result_mk_ok(mk_except_ok(lean_box(0)));
}

/*
 * swelib_getaddrinfo : host : @& String → service : @& String
 *                      → IO (Except Errno (Array (UInt32 × String)))
 *   Returns array of (address_family, ip_string)
 */
LEAN_EXPORT lean_obj_res swelib_getaddrinfo(
    b_lean_obj_arg host, b_lean_obj_arg service,
    lean_obj_arg world
) {
    const char *c_host = lean_string_cstr(host);
    const char *c_svc  = lean_string_cstr(service);

    struct addrinfo hints, *result, *rp;
    memset(&hints, 0, sizeof(hints));
    hints.ai_family   = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;

    int s = getaddrinfo(c_host, c_svc[0] ? c_svc : NULL, &hints, &result);
    if (s != 0) {
        return lean_io_result_mk_ok(mk_errno_error(ENOENT));
    }

    /* Count results */
    size_t count = 0;
    for (rp = result; rp != NULL; rp = rp->ai_next) count++;

    lean_object *arr = lean_alloc_array(count, count);
    size_t idx = 0;
    for (rp = result; rp != NULL; rp = rp->ai_next) {
        char ipstr[INET6_ADDRSTRLEN];
        void *addr_ptr;
        if (rp->ai_family == AF_INET) {
            addr_ptr = &((struct sockaddr_in *)rp->ai_addr)->sin_addr;
        } else {
            addr_ptr = &((struct sockaddr_in6 *)rp->ai_addr)->sin6_addr;
        }
        inet_ntop(rp->ai_family, addr_ptr, ipstr, sizeof(ipstr));

        lean_object *fam_obj = lean_box_uint32((uint32_t)rp->ai_family);
        lean_object *ip_obj  = lean_mk_string(ipstr);
        lean_object *pair    = lean_alloc_ctor(0, 2, 0);
        lean_ctor_set(pair, 0, fam_obj);
        lean_ctor_set(pair, 1, ip_obj);
        lean_array_set_core(arr, idx++, pair);
    }

    freeaddrinfo(result);
    return lean_io_result_mk_ok(mk_except_ok(arr));
}

/*
 * swelib_close_socket : fd : UInt32 → IO (Except Errno Unit)
 * (Separate from swelib_close to avoid collisions if file ops are loaded too)
 */
LEAN_EXPORT lean_obj_res swelib_close_socket(
    uint32_t fd,
    lean_obj_arg world
) {
    int r = close((int)fd);
    if (r < 0) return lean_io_result_mk_ok(mk_errno_error(errno));
    return lean_io_result_mk_ok(mk_except_ok(lean_box(0)));
}

/* ── Signal operations ───────────────────────────────────────────── */

/* Signal disposition kinds: 0=SIG_DFL, 1=SIG_IGN, 2=stub handler */
#define SWELIB_DISP_DEFAULT 0
#define SWELIB_DISP_IGNORE  1
#define SWELIB_DISP_HANDLER 2

/* Stub handler installed for dispKind=2 (handler) registrations.
   Real Lean handlers cannot be called from a signal context. */
static void swelib_signal_handler_stub(int sig) { (void)sig; }

/* Encode a sigset_t as a UInt64 bitmask: signal N maps to bit N-1. */
static uint64_t sigset_to_mask(const sigset_t *ss) {
    uint64_t m = 0;
    for (int i = 1; i <= 64; i++) {
        if (sigismember(ss, i) == 1)
            m |= ((uint64_t)1 << (i - 1));
    }
    return m;
}

/* Decode a UInt64 bitmask into a sigset_t. */
static void mask_to_sigset(uint64_t mask, sigset_t *ss) {
    sigemptyset(ss);
    for (int i = 1; i <= 64; i++) {
        if (mask & ((uint64_t)1 << (i - 1)))
            sigaddset(ss, i);
    }
}

/*
 * swelib_sigaction : signum    : UInt32 → queryOnly : UInt32
 *                    dispKind  : UInt32 → mask      : UInt64
 *                    flags     : UInt32
 *                    → IO (Except Errno (UInt32 × UInt64 × UInt32))
 *
 *   queryOnly=1: read-only query; dispKind/mask/flags are ignored.
 *   dispKind: 0=SIG_DFL, 1=SIG_IGN, 2=stub handler.
 *   mask: sa_mask bitmask (signal N → bit N-1).
 *   flags: sa_flags bits (SA_RESTART, SA_NODEFER, etc.).
 *   Returns (old_dispKind, old_mask, old_flags).
 */
LEAN_EXPORT lean_obj_res swelib_sigaction(
    uint32_t signum, uint32_t query_only,
    uint32_t disp_kind, uint64_t mask, uint32_t flags,
    lean_obj_arg world
) {
    struct sigaction old_sa, new_sa;
    memset(&old_sa, 0, sizeof(old_sa));
    memset(&new_sa, 0, sizeof(new_sa));

    if (!query_only) {
        switch (disp_kind) {
            case SWELIB_DISP_IGNORE:  new_sa.sa_handler = SIG_IGN; break;
            case SWELIB_DISP_HANDLER: new_sa.sa_handler = swelib_signal_handler_stub; break;
            default:                  new_sa.sa_handler = SIG_DFL; break;
        }
        mask_to_sigset(mask, &new_sa.sa_mask);
        new_sa.sa_flags = (int)flags;
    }

    int r = sigaction((int)signum, query_only ? NULL : &new_sa, &old_sa);
    if (r < 0) return lean_io_result_mk_ok(mk_errno_error(errno));

    uint32_t old_kind;
    if (old_sa.sa_handler == SIG_DFL)      old_kind = SWELIB_DISP_DEFAULT;
    else if (old_sa.sa_handler == SIG_IGN) old_kind = SWELIB_DISP_IGNORE;
    else                                    old_kind = SWELIB_DISP_HANDLER;

    uint64_t old_mask  = sigset_to_mask(&old_sa.sa_mask);
    uint32_t old_flags = (uint32_t)old_sa.sa_flags;

    /* Build (UInt64 × UInt32) inner pair */
    lean_object *inner = lean_alloc_ctor(0, 2, 0);
    lean_ctor_set(inner, 0, lean_box_uint64(old_mask));
    lean_ctor_set(inner, 1, lean_box_uint32(old_flags));

    /* Build UInt32 × (UInt64 × UInt32) */
    lean_object *outer = lean_alloc_ctor(0, 2, 0);
    lean_ctor_set(outer, 0, lean_box_uint32(old_kind));
    lean_ctor_set(outer, 1, inner);

    return lean_io_result_mk_ok(mk_except_ok(outer));
}

/*
 * swelib_sigprocmask : how : UInt32 → queryOnly : UInt32 → newMask : UInt64
 *                      → IO (Except Errno UInt64)
 *
 *   how: SIG_BLOCK=0, SIG_UNBLOCK=1, SIG_SETMASK=2.
 *   queryOnly=1: pass NULL for set, just returns current mask.
 *   Returns old blocked mask as bitmask.
 */
LEAN_EXPORT lean_obj_res swelib_sigprocmask(
    uint32_t how, uint32_t query_only, uint64_t new_mask,
    lean_obj_arg world
) {
    sigset_t new_set, old_set;
    sigemptyset(&old_set);
    if (!query_only) mask_to_sigset(new_mask, &new_set);

    int r = sigprocmask((int)how, query_only ? NULL : &new_set, &old_set);
    if (r < 0) return lean_io_result_mk_ok(mk_errno_error(errno));

    return lean_io_result_mk_ok(mk_except_ok(lean_box_uint64(sigset_to_mask(&old_set))));
}

/*
 * swelib_sigpending : IO (Except Errno UInt64)
 *   Returns the set of signals pending for the calling thread as a bitmask.
 */
LEAN_EXPORT lean_obj_res swelib_sigpending(lean_obj_arg world) {
    sigset_t pending;
    sigemptyset(&pending);
    int r = sigpending(&pending);
    if (r < 0) return lean_io_result_mk_ok(mk_errno_error(errno));
    return lean_io_result_mk_ok(mk_except_ok(lean_box_uint64(sigset_to_mask(&pending))));
}

/* ── Memory (virtual memory) operations ─────────────────────────── */

/*
 * swelib_mmap : addr : UInt64 → length : USize → prot : UInt32
 *               → flags : UInt32 → fd : Int32 → offset : UInt64
 *               → IO (Except Errno UInt64)
 *
 *   addr=0: let kernel choose; otherwise used as hint (or fixed with MAP_FIXED).
 *   Returns the mapped virtual address.
 */
LEAN_EXPORT lean_obj_res swelib_mmap(
    uint64_t addr, size_t length, uint32_t prot, uint32_t flags,
    int32_t fd, uint64_t offset,
    lean_obj_arg world
) {
    void *hint = addr ? (void *)(uintptr_t)addr : NULL;
    void *result = mmap(hint, length, (int)prot, (int)flags, (int)fd, (off_t)offset);
    if (result == MAP_FAILED)
        return lean_io_result_mk_ok(mk_errno_error(errno));
    return lean_io_result_mk_ok(mk_except_ok(lean_box_uint64((uint64_t)(uintptr_t)result)));
}

/*
 * swelib_munmap : addr : UInt64 → length : USize → IO (Except Errno Unit)
 */
LEAN_EXPORT lean_obj_res swelib_munmap(
    uint64_t addr, size_t length,
    lean_obj_arg world
) {
    int r = munmap((void *)(uintptr_t)addr, length);
    if (r < 0) return lean_io_result_mk_ok(mk_errno_error(errno));
    return lean_io_result_mk_ok(mk_except_ok(lean_box(0)));
}

/*
 * swelib_mprotect : addr : UInt64 → length : USize → prot : UInt32
 *                   → IO (Except Errno Unit)
 */
LEAN_EXPORT lean_obj_res swelib_mprotect(
    uint64_t addr, size_t length, uint32_t prot,
    lean_obj_arg world
) {
    int r = mprotect((void *)(uintptr_t)addr, length, (int)prot);
    if (r < 0) return lean_io_result_mk_ok(mk_errno_error(errno));
    return lean_io_result_mk_ok(mk_except_ok(lean_box(0)));
}

/*
 * swelib_brk : addr : UInt64 → IO (Except Errno UInt64)
 *   Sets the program break to `addr`.
 *   Returns the new program break on success.
 */
LEAN_EXPORT lean_obj_res swelib_brk(
    uint64_t addr,
    lean_obj_arg world
) {
    int r = brk((void *)(uintptr_t)addr);
    if (r < 0) return lean_io_result_mk_ok(mk_errno_error(errno));
    /* Read back the actual new break (brk may have rounded up) */
    void *new_brk = sbrk(0);
    if (new_brk == (void *)-1)
        return lean_io_result_mk_ok(mk_errno_error(errno));
    return lean_io_result_mk_ok(mk_except_ok(lean_box_uint64((uint64_t)(uintptr_t)new_brk)));
}

/*
 * swelib_sbrk : increment : Int64 → IO (Except Errno UInt64)
 *   Increments the program break by `increment` bytes.
 *   Returns the NEW program break (old break + increment).
 */
LEAN_EXPORT lean_obj_res swelib_sbrk(
    int64_t increment,
    lean_obj_arg world
) {
    void *old_brk = sbrk((intptr_t)increment);
    if (old_brk == (void *)-1)
        return lean_io_result_mk_ok(mk_errno_error(errno));
    /* Return the new break: old + increment */
    uint64_t new_addr = (uint64_t)(uintptr_t)old_brk + (uint64_t)increment;
    return lean_io_result_mk_ok(mk_except_ok(lean_box_uint64(new_addr)));
}
