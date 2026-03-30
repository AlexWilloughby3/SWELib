# Plan: Async Runtime for Lean 4

## Status Quo

Lean 4 (as of v4.25+) provides solid concurrency **primitives** but no async IO runtime:

| What exists | What's missing |
|------------|---------------|
| `Task α` (thread-pool scheduled futures) | Non-blocking IO (no epoll/kqueue integration) |
| `IO.Promise α` (manually-resolved futures) | Event loop / IO multiplexer |
| `Task.bind`, `Task.map` (composition) | Green threads / lightweight fibers |
| `IO.waitAny` (select over tasks) | async/await syntax sugar |
| `Std.Sync.Mutex`, `Channel`, `Broadcast` | Structured concurrency (nursery/scope) |
| `CancellationToken`, `Notify`, `Condvar` | Non-blocking file/network IO |
| `StreamMap` (async stream multiplexing) | |

The runtime uses a **thread pool** of OS threads (sized to CPU count). Every blocking IO call
(socket read, file read, libpq query) blocks an OS thread. This caps practical concurrency
at ~thousands of concurrent operations, not tens of thousands.

## The Problem

If you want to build a Lean application that handles many concurrent connections (an HTTP server,
a database connection pool under load, a proxy), you hit a wall: each in-flight IO operation
consumes an OS thread. The existing `Task` system is good for CPU parallelism but not for
IO-bound concurrency.

## Three Paths Forward

### Path 1: FFI to libuv (Pragmatic, Near-term)

**Idea:** Bind libuv (the event loop behind Node.js) via Lean FFI. Lean tasks wait on
`IO.Promise` values that the libuv loop resolves when IO completes.

**Architecture:**

```
┌─────────────────────────────┐
│  Lean Task Pool              │
│  (compute + application      │
│   logic, waits on Promises)  │
└────────────┬────────────────┘
             │ IO.Promise.resolve
┌────────────▼────────────────┐
│  libuv event loop            │
│  (1-2 dedicated threads)     │
│  epoll/kqueue, non-blocking  │
│  TCP, UDP, DNS, timers, FS   │
└─────────────────────────────┘
```

**How it works:**
1. A Lean wrapper creates an `IO.Promise α` and registers a request with libuv
   (e.g., "read 4096 bytes from this socket").
2. The calling task does `IO.Promise.result >>= ...` — it suspends (via `Task.bind`),
   freeing the pool thread.
3. libuv's event loop (on a dedicated thread) detects completion, copies data into a
   Lean-allocated buffer, and calls `IO.Promise.resolve`.
4. The Lean runtime wakes the suspended task on a pool thread.

**What needs building:**
- C shim layer: ~2k lines wrapping libuv's TCP, UDP, DNS, timer, and FS APIs
- Lean wrapper: ~1.5k lines providing a clean `Async.TCP.connect`, `Async.TCP.recv`, etc.
- Lifecycle management: starting/stopping the event loop, cleanup on cancellation

**Advantages:**
- libuv is battle-tested (Node.js, Julia, Neovim)
- Works today with existing Lean primitives (`IO.Promise`, `Task.bind`, `CancellationToken`)
- Lean's thread pool still handles compute; libuv handles IO waiting
- Cross-platform (Linux, macOS, Windows)

**Disadvantages:**
- Another C dependency
- Data must cross the Lean/C boundary (minor overhead for copies)
- Two scheduling systems (Lean thread pool + libuv loop) that don't know about each other
- libuv's callback model requires careful Lean-side lifetime management

**Estimated scope:** ~4k lines of C + Lean. Moderate difficulty.

### Path 2: Native epoll/kqueue in Lean Runtime (Medium-term)

**Idea:** Integrate IO multiplexing directly into Lean's thread pool scheduler.

**Architecture:**

```
┌─────────────────────────────────────┐
│  Lean Runtime (modified)             │
│                                      │
│  Worker threads    IO poller thread  │
│  ┌─────┐ ┌─────┐  ┌──────────────┐  │
│  │ T1  │ │ T2  │  │ epoll_wait / │  │
│  │     │ │     │  │ kqueue       │  │
│  └──┬──┘ └──┬──┘  └──────┬───────┘  │
│     │       │            │           │
│     └───────┴────────────┘           │
│          task ready queue            │
└─────────────────────────────────────┘
```

**How it works:**
1. When a task calls `Socket.recv`, instead of the OS blocking the thread, the runtime:
   a. Registers the fd with epoll/kqueue
   b. Parks the task (removes it from the ready queue)
   c. Returns the thread to the pool
2. A dedicated IO poller thread runs `epoll_wait`. When an fd becomes ready, it moves
   the parked task back onto the ready queue.
3. A worker thread picks up the task and continues execution.

This is essentially what Go's runtime does (the "netpoller").

**What needs building:**
- Modifications to `lean4/src/runtime/` C++ code (~1k lines)
- Platform-specific backends: `epoll` (Linux), `kqueue` (macOS/BSD), `IOCP` (Windows)
- New Lean API: `Async.Socket`, `Async.File`, etc. that use the integrated poller
- Changes to task scheduling to support parking/unparking

**Advantages:**
- Single scheduler, no coordination overhead
- No extra C dependencies
- Lowest possible overhead (no data copies across boundaries)
- Could eventually support millions of concurrent IO operations (like Go)

**Disadvantages:**
- Requires modifying the Lean runtime (C++ code in leanprover/lean4)
- Platform-specific code needed for each OS
- High bar for upstream acceptance
- Much more complex than Path 1

**Estimated scope:** ~3k lines of C++/C + Lean. High difficulty. Requires deep Lean runtime knowledge.

### Path 3: Async Monad + do-notation (Language-level, Longer-term)

**Idea:** Define an `Async` monad that represents non-blocking computations, backed by
Path 1 or Path 2 underneath. Lean's `do` notation already provides `async/await`-like syntax.

```lean
-- Hypothetical API
def handleClient (sock : Async.Socket) : Async Unit := do
  let request ← sock.recv 4096          -- suspends, doesn't block thread
  let response ← processRequest request  -- runs on thread pool
  sock.send response                      -- suspends for send
  sock.close

def main : IO Unit := do
  let server ← Async.listen "0.0.0.0" 8080
  server.acceptLoop fun sock =>
    Async.spawn (handleClient sock)
```

**Key design decisions:**
- `Async` is a separate monad from `IO` (forces awareness of blocking vs non-blocking)
- OR: `Async` is a transformer on `IO` (more ergonomic, less safe)
- Integration with `CancellationToken` for structured cancellation
- Integration with `Std.Sync.Channel`/`Broadcast` for async message passing
- `Async.race`, `Async.all`, `Async.select` combinators

**What needs building:**
- The `Async` monad definition and runner
- Non-blocking IO primitives (from Path 1 or 2)
- Combinators: `race`, `all`, `select`, `timeout`, `retry`
- Integration with existing `Std.Sync` primitives
- Structured concurrency: `Async.scope` / `Async.nursery`

**Advantages:**
- Clean, composable API
- Type-level distinction between blocking and non-blocking code
- `do` notation makes it read like imperative async code without new syntax
- Could become a community standard library

**Disadvantages:**
- Needs Path 1 or 2 as a foundation first
- Monad transformer overhead (though Lean is good at optimizing this away)
- Community consensus needed on API design

**Estimated scope:** ~2k lines of Lean (on top of Path 1 or 2). Moderate difficulty.

## Recommended Approach

**Path 1 first, then Path 3 on top.**

Rationale:
- Path 1 is achievable with current Lean, no runtime modifications needed
- `IO.Promise` + `Task.bind` + `CancellationToken` already provide the wiring
- Path 3 gives a clean user-facing API on top
- Path 2 is the "right" long-term answer but requires Lean core team involvement

**Phased plan:**

| Phase | Work | Output |
|-------|------|--------|
| 1 | libuv C shims for TCP, UDP, timers, DNS | `code/ffi/swelib_libuv.c` |
| 2 | Lean wrappers using `IO.Promise` | `code/SWELibCode/Async/TCP.lean`, etc. |
| 3 | `Async` monad + combinators | `code/SWELibCode/Async/Monad.lean` |
| 4 | Structured concurrency (`scope`, `nursery`) | `code/SWELibCode/Async/Scope.lean` |
| 5 | Port HttpServer to async | Proof of concept |

## Relevance to SWELib

The **spec layer** is unaffected — formal specifications don't execute IO.

The **code layer** would benefit significantly:
- `SWELibCode.Networking.HttpServer` currently can't handle concurrent connections efficiently
- `SWELibCode.Db.ConnectionPool` blocks a thread per in-flight query
- `SWELibCode.Networking.TcpServer` is limited by thread count

The **bridge layer** would need new axioms asserting that the async wrappers conform to
the same spec properties as the synchronous versions (e.g., `Async.TCP.recv` still satisfies
the TCP stream semantics formalized in `SWELib.Networking.Tcp`).

## FFI Memory Model: How C Libraries Interact with Lean

This section explains what happens at the memory level when Lean calls a C function like
libpq's `PQexecParams`.

### The Short Answer

**Lean does NOT touch or manage memory allocated by C libraries.** The two memory worlds
are completely separate. Lean's reference counting, natural number representations, and
proof erasure have zero impact on the data flowing through libpq.

### The Detailed Picture

When you call `execParamsRows` from Lean:

```
Lean world                          C world
─────────────────────────────────── ───────────────────────────────
1. Lean has a String query and
   Array String params.
   These are Lean heap objects
   (ref-counted, boxed).

2. @[extern] call crosses FFI
   boundary. Lean passes:
   - connPtr as raw USize (just
     a number, not a Lean object)
   - query as b_lean_obj_arg
     (borrowed pointer — Lean
     retains ownership)
   - params as b_lean_obj_arg
     (borrowed pointer)

                                    3. C shim calls lean_string_cstr()
                                       to get a const char* into Lean's
                                       string buffer. NO COPY. Just a
                                       pointer into Lean-managed memory.

                                    4. C shim calls borrow_params() to
                                       build a const char** array.
                                       This malloc's a small pointer
                                       array (C-managed) pointing into
                                       Lean string buffers.

                                    5. PQexecParams() runs. libpq:
                                       - Copies the query + params into
                                         its own send buffer
                                       - Sends over the TCP socket
                                       - Receives response into its own
                                         recv buffer
                                       - Builds a PGresult (libpq-managed
                                         memory, malloc'd by libpq)

                                       Lean knows NOTHING about this.
                                       libpq manages its own memory.

                                    6. C shim reads from PGresult using
                                       PQgetvalue(), PQntuples(), etc.
                                       These return pointers into
                                       libpq-managed memory.

                                    7. C shim builds Lean return objects:
                                       - lean_mk_string() COPIES each
                                         cell value into a new Lean
                                         string (Lean-managed, ref-counted)
                                       - lean_alloc_array() creates Lean
                                         arrays (Lean-managed)
                                       - lean_alloc_ctor() creates Lean
                                         tuples/Options (Lean-managed)

                                    8. PQclear(res) — frees ALL libpq
                                       memory for this result. The data
                                       now only exists in the Lean copies.

                                    9. free(params) — frees the small
                                       pointer array from step 4.

10. C shim returns
    lean_io_result_mk_ok(result).
    Lean runtime receives the
    result as a normal Lean object.
    From here, ref-counting and
    GC apply normally.
```

### Key Points

**Where Lean overhead lives:**
- **Import/elaboration overhead**: Lean's import of Mathlib, proof checking of Nat theorems,
  etc. happens at *compile time*. At runtime, proofs are *erased* — they produce zero code.
  A theorem about natural numbers compiles to nothing. The binary doesn't contain proof terms.
- **Boxed representations**: Lean wraps values in heap-allocated objects with ref-count headers.
  A `String` in Lean is a pointer to a heap object containing `{refcount, length, data[]}`.
  This adds ~16 bytes overhead per string vs a raw `char*`.
- **Reference counting**: Each time a Lean object is shared or dropped, an atomic
  increment/decrement runs. This is a few nanoseconds per operation.

**Where Lean overhead does NOT live:**
- **The actual query execution**: `PQexecParams` runs entirely in libpq's C code, using
  libpq's own memory allocator, its own TCP buffers, its own result parsing. Lean's runtime
  is not involved at all during the network round-trip.
- **Transaction data**: The bytes flowing between your process and PostgreSQL are managed
  entirely by libpq and the kernel's TCP stack. Lean never touches them.
- **Connection state**: The `PGconn*` is a libpq-allocated object. Lean stores it as a raw
  `USize` (just a number). Lean's ref-counting doesn't apply to it.

**The actual overhead in a query cycle:**

| Step | Who manages memory | Lean overhead |
|------|-------------------|---------------|
| Build query string | Lean | ~0 (string concat, fast) |
| Cross FFI boundary | Lean → C | ~0 (pointer pass, no copy) |
| Extract C strings from Lean objects | C shim | ~0 (pointer dereference) |
| Execute query (network round-trip) | libpq + kernel | **None** |
| Parse result rows into Lean objects | C shim | **One copy per cell** |
| Use results in Lean code | Lean | Ref-counting overhead |

**The one real cost:** Step 6, converting PGresult rows into Lean objects, copies every cell
value once (via `lean_mk_string`). For a 10,000-row result with 10 columns, that's 100k
string allocations + copies. This is comparable to what any language with managed memory does
(Python, Go, Java all copy result data out of the C driver's buffers).

### Does Lean "Poorly Manage" the Query Data?

No. Lean's management of the result data is actually quite good:

1. **No GC pauses**: Lean uses deterministic ref-counting, not tracing GC.
   Objects are freed the instant their last reference is dropped. No stop-the-world.

2. **Destructive updates**: If your code processes rows one at a time and doesn't hold
   references to previous rows, Lean's compiler can reuse the memory in-place.

3. **Borrowed parameters** (`@&`): The `@&` annotation on `query` and `params` means
   Lean passes them by reference without incrementing the refcount. Zero overhead.

4. **Proof erasure**: Any type-level proofs attached to your query types (e.g., proving
   a `SelectQuery` is well-formed) are erased at compile time. They don't exist at runtime.

The memory lifecycle is clean: libpq owns its memory during the query, the C shim copies
results into Lean objects, libpq frees its memory, and Lean manages the copies with
ref-counting. The two systems never interfere with each other.
