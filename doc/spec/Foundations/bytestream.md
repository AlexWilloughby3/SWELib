# Sketch: ByteStream

## What This Sketch Defines

A **ByteStream** is an ordered, reliable sequence of bytes — the fundamental data-plane abstraction that every stream-oriented protocol reads from and writes to. It is what `read(fd)` returns and `write(fd)` consumes on a `SOCK_STREAM` socket.

ByteStream is the **bridge** between the abstract ChannelProcess (sketch 05) and the concrete OS plumbing (fd tables, sockets, TCP). Sketch 05 models a channel as a CCS process that accepts messages of type `α` and delivers them. ByteStream is what that delivery *actually looks like* when `α` is instantiated to bytes and the channel is TCP: an ordered, reliable, potentially infinite sequence of octets, presented to userspace through a file descriptor.

## Why ByteStream Needs Its Own Abstraction

Several existing SWELib modules implicitly depend on byte streams without naming them:

- **TCP** (`Networking/Tcp/Tcb.lean`): The TCB tracks sequence numbers (`snd_nxt`, `rcv_nxt`) that index into a *conceptual* byte stream. `snd_nxt - iss` is the count of bytes written so far. But the TCB doesn't expose the stream itself — it manages the transmission machinery.
- **OS/Sockets** (`OS/Sockets/Types.lean`): `SocketEntry.recvBuf : List ByteArray` is the materialized prefix of the incoming byte stream. `sendBufUsed/sendBufCapacity` tracks the outgoing side. But these are buffer-management details, not a stream abstraction.
- **TLS** (`Networking/Tls`): `tlsSend`/`tlsReceive` encrypt and decrypt *byte sequences*. The TLS record layer frames bytes into records. But TLS doesn't define what "the byte sequence" is — it assumes one exists underneath.
- **HTTP** (`Networking/Http`): Request/response bodies are `Option ByteArray`. HTTP/1.1 chunked transfer encoding is a framing layer *over a byte stream*. HTTP/2 multiplexes multiple logical streams over one byte stream.
- **WebSocket** (`Networking/Websocket`): Frames carry `payload_data : ByteArray`. The WebSocket protocol is a message-framing protocol *over a byte stream*.

Every one of these protocols either produces, consumes, or transforms a byte stream. Without an explicit ByteStream type, each module re-invents the concept (as `List ByteArray`, as TCB sequence counters, as payload fields).

## The Linux Model: ByteStream = fd + kernel buffer

In Linux, a byte stream is not a free-floating object. It is always **anchored to a file descriptor**, and the kernel mediates all access:

```
User process                          Kernel
    |                                   |
    |-- write(fd, buf, n) ------------>|  (appends n bytes to send buffer)
    |                                   |-- [TCP segments out] -->
    |                                   |
    |                                   |<-- [TCP segments in] --
    |<-- read(fd, buf, n) -------------|  (drains up to n bytes from recv buffer)
```

The key facts from POSIX and the Linux networking stack:

1. **An fd is per-process.** The `FdTable` (existing `OS/Io`) maps fd numbers to states. Two processes can hold fds referring to the same underlying socket (via `fork()` or `sendmsg()` SCM_RIGHTS), but each fd is independently closeable.

2. **A connected SOCK_STREAM socket has exactly two byte streams** — one in each direction. The kernel maintains a send buffer and a receive buffer per socket. These are the materialized portions of the two streams.

3. **`read()` is destructive and ordered.** Bytes are consumed from the front of the receive buffer. You cannot re-read bytes (unless you use `MSG_PEEK`). This is the FIFO discipline.

4. **`write()` may block or return short.** If the send buffer is full, `write()` blocks (or returns `EAGAIN` for non-blocking). The number of bytes accepted may be less than requested. This is backpressure.

5. **EOF is part of the stream.** When the remote end calls `shutdown(SHUT_WR)` or `close()`, the local `read()` eventually returns 0 bytes — this is the end-of-stream signal. The stream is *finite* in practice, terminated by FIN.

6. **`SOCK_DGRAM` does not give a byte stream.** Each `recvfrom()` returns a complete datagram. Message boundaries are preserved. This is a *message stream*, not a byte stream.

### Source specs

- `read(2)`: https://man7.org/linux/man-pages/man2/read.2.html
- `write(2)`: https://man7.org/linux/man-pages/man2/write.2.html
- `recv(2)`: https://man7.org/linux/man-pages/man2/recv.2.html (MSG_PEEK, MSG_WAITALL)
- `send(2)`: https://man7.org/linux/man-pages/man2/send.2.html
- `shutdown(2)`: https://man7.org/linux/man-pages/man2/shutdown.2.html
- `tcp(7)`: https://man7.org/linux/man-pages/man7/tcp.7.html (buffer sizes, backpressure)
- `socket(7)`: https://man7.org/linux/man-pages/man7/socket.7.html (SO_RCVBUF, SO_SNDBUF)
- RFC 9293 Section 3.1 ("a continuous stream of octets")
- Stevens, "Unix Network Programming" Vol 1, Chapter 2: The Transport Layer (byte stream vs message boundaries)

## Key Types to Formalize

### ByteStream (pure, no OS dependency)

The abstract mathematical object: a finite or growing sequence of bytes.

```
/-- A byte stream is a finite sequence of octets, potentially still growing.
    This models the *logical content* of a stream — the sequence of bytes
    that have been (or will be) written/read, independent of buffering,
    segmentation, or delivery mechanism.

    `closed` indicates the writer has signaled end-of-stream (TCP FIN,
    shutdown(SHUT_WR), etc). An open stream may grow; a closed stream is final.
-/
structure ByteStream where
  data : List UInt8
  closed : Bool
```

Why `List UInt8` and not `ByteArray`? In the formal model, we need structural induction and `List` lemmas (prefix, append, FIFO properties). `ByteArray` is an opaque FFI-backed type in Lean — fine for computation, useless for proofs. The formalization works on `List UInt8`; a computational bridge to `ByteArray` can be added later.

Why not coinductive (infinite stream)? TCP streams are finite — they are terminated by FIN. An HTTP response body is finite. Even a WebSocket connection, while long-lived, eventually closes. The `closed` flag captures the open/growing vs finished distinction without coinduction. If we later need truly infinite streams (e.g., for modeling an infinite event source), we can extend, but the common case is finite.

### ByteStream operations

```
/-- Append bytes to an open stream (models the writer side). -/
def ByteStream.write (s : ByteStream) (bytes : List UInt8) : ByteStream

/-- Read and consume up to n bytes from the front (models the reader side).
    Returns the bytes read and the stream with those bytes removed.
    If fewer than n bytes are available, returns what's there.
    Returns empty list on a closed, empty stream (EOF). -/
def ByteStream.read (s : ByteStream) (n : Nat) : List UInt8 × ByteStream

/-- Peek at up to n bytes without consuming (models MSG_PEEK). -/
def ByteStream.peek (s : ByteStream) (n : Nat) : List UInt8

/-- Close the stream (no more writes). -/
def ByteStream.close (s : ByteStream) : ByteStream

/-- Number of bytes available to read. -/
def ByteStream.available (s : ByteStream) : Nat := s.data.length

/-- Is the stream at EOF? (closed and fully drained) -/
def ByteStream.eof (s : ByteStream) : Bool := s.closed && s.data.isEmpty

/-- Total bytes ever written (not just currently buffered).
    Useful for connecting to TCP sequence numbers. -/
-- Note: needs a cumulative counter, not derivable from `data` alone
-- since `read` drains bytes. Track separately:
structure ByteStream where
  data : List UInt8          -- bytes available to read (the buffer)
  bytesWritten : Nat         -- total bytes ever appended
  bytesRead : Nat            -- total bytes ever consumed
  closed : Bool
```

The `bytesWritten` counter directly corresponds to TCP's `snd_nxt - iss` (for the sending side) and `rcv_nxt - irs` (for the receiving side). This is the link between the abstract stream and the TCB.

### StreamPair (bidirectional connection)

A connected stream socket gives you two byte streams — one per direction:

```
/-- A bidirectional byte stream connection.
    Models a connected SOCK_STREAM socket.
    Each direction is an independent ByteStream. -/
structure StreamPair where
  /-- Bytes flowing from local to remote (local writes, remote reads). -/
  outgoing : ByteStream
  /-- Bytes flowing from remote to local (remote writes, local reads). -/
  incoming : ByteStream
```

This corresponds to a connected `SocketEntry` in `OS/Sockets/Types.lean`:
- `incoming.data` = `SocketEntry.recvBuf` (flattened from `List ByteArray` to `List UInt8`)
- `outgoing.bytesWritten - outgoing.bytesRead` = `SocketEntry.sendBufUsed`

### BoundStream (ByteStream anchored to an fd)

The OS-level view: a byte stream is accessed through a file descriptor.

```
/-- A byte stream anchored to a file descriptor.
    This is the OS-visible object — the fd is how userspace refers to the stream.
    The fd must be open and of kind .socket in the process's FdTable. -/
structure BoundStream where
  fd : FileDescriptor
  stream : StreamPair
  local : SockAddr
  remote : SockAddr
  /-- The fd is open and is a socket. -/
  fd_valid : FdState           -- must be (open .socket)
```

### MessageStream (datagram variant)

UDP and other datagram protocols don't give byte streams — they give *message* streams where boundaries are preserved:

```
/-- A message stream preserves message boundaries.
    Each read returns exactly one message (or none).
    Models SOCK_DGRAM (UDP), SOCK_SEQPACKET, and application-level framing.  -/
structure MessageStream (α : Type) where
  messages : List α
  closed : Bool
```

When `α = List UInt8`, this is a raw datagram stream (each datagram is a `List UInt8` with boundaries preserved). When `α = HttpRequest`, it's an HTTP request stream. When `α = WebSocketFrame`, it's a WebSocket frame stream.

**The key distinction**: a ByteStream has *no internal boundaries* — `write([1,2])` followed by `write([3])` is indistinguishable from `write([1])` followed by `write([2,3])`. A MessageStream *preserves boundaries* — each message is delivered as a unit.

This maps to the Linux syscall difference:
- `read()` on SOCK_STREAM: returns up to N bytes, no boundary preservation
- `recvfrom()` on SOCK_DGRAM: returns exactly one datagram, excess bytes discarded

## Relationship to File Descriptors

The fd-to-stream relationship follows the existing `OS/Io` model:

```
-- Existing (OS/Io):
-- FdTable : Nat → Option FdState
-- FdState = open FdKind | closed
-- FdKind = file | socket | pipe | epoll

-- Extension: when FdKind = socket, the fd may back a BoundStream
-- The connection between fd and stream is mediated by the socket layer

-- The chain:
-- 1. socket() creates fd (FdKind.socket) — no stream yet
-- 2. bind() + listen() — fd is a listener, not a stream
-- 3. accept() creates NEW fd (FdKind.socket) + allocates a StreamPair
--    → this new fd IS a BoundStream
-- 4. connect() on a client socket — fd becomes a BoundStream
-- 5. read(fd)/write(fd) operates on the BoundStream's streams
-- 6. close(fd) closes the fd AND signals EOF on the outgoing stream
--    (equivalent to shutdown(SHUT_WR) + shutdown(SHUT_RD) + fd cleanup)
```

### fd inheritance and sharing

Multiple fds can refer to the same underlying stream:

```
-- fork(): child inherits all fds, including those backing streams
-- The child's fd 5 and parent's fd 5 refer to the SAME StreamPair
-- read() by either process drains from the SAME incoming buffer
-- This is correct POSIX behavior but tricky — interleaved reads produce
-- nondeterministic byte partitioning

-- dup()/dup2(): creates a new fd number pointing to the same stream
-- Same sharing semantics as fork()

-- sendmsg() SCM_RIGHTS: passes an fd over a Unix socket to another process
-- Receiver gets a new fd in their FdTable pointing to the sender's stream
```

The formalization should track an indirection layer:

```
/-- A stream descriptor is the kernel-internal reference to a stream.
    Multiple fds (possibly in different processes) can point to the same one. -/
structure StreamDescriptor where
  id : Nat                    -- kernel-internal identifier
  stream : StreamPair
  refCount : Nat              -- number of fds pointing here
  -- When refCount drops to 0, the stream is torn down (TCP sends FIN)
```

This mirrors the Linux kernel's `struct socket` / `struct sock` separation. The fd is a per-process handle; the socket is a kernel-global object with a reference count.

## Relationship to TCP

TCP's job is to implement a reliable ByteStream over unreliable IP datagrams. The relationship:

```
-- ByteStream is the WHAT (the abstraction the application sees)
-- TCP is the HOW (the mechanism that delivers it)

-- ByteStream.bytesWritten = TCB.snd_nxt - TCB.iss  (sender side)
-- ByteStream.bytesRead on remote = TCB.snd_una - TCB.iss  (acknowledged)
-- ByteStream.data.length on recv side ≤ TCB.rcv_wnd  (flow control)

-- TCP segment carries a slice of the byte stream:
-- segment.payload = stream.data[seq - iss .. seq - iss + len]
-- TCP reconstructs the stream by placing segments at the right offset
```

The refinement theorem (conceptual):

```
-- A TCP connection (TCB + segment exchange) correctly implements a StreamPair:
-- 1. Bytes written by the sender appear in the same order at the receiver (FIFO)
-- 2. No bytes are lost (reliability) — assuming the connection is not reset
-- 3. No bytes are duplicated (TCP deduplication via sequence numbers)
-- 4. EOF is delivered (FIN is reliably transmitted)
--
-- This is the core correctness property of TCP, expressed as a refinement
-- from the TCP state machine to the ByteStream abstraction.
theorem tcp_implements_bytestream :
  ∀ (tcb : TCB) (conn : StreamPair),
    tcp_refines tcb conn →
    stream_fifo conn.outgoing conn.incoming ∧
    stream_reliable conn.outgoing conn.incoming ∧
    stream_non_duplicating conn.outgoing conn.incoming
```

## Relationship to Abstract ChannelProcess (sketch 05)

Sketch 05 defines `ChannelProcess α` — a CCS process that accepts messages of type `α` and delivers them. A ByteStream is a *specific instantiation* of this:

```
-- Sketch 05's reliable FIFO channel, instantiated to bytes:
-- ChannelProcess (List UInt8)
-- recv_from_sender : List UInt8 → ChannelAction   (write side)
-- deliver_to_receiver : List UInt8 → ChannelAction (read side)

-- But ByteStream is more specific:
-- 1. It's BYTE-granular (not message-granular) — boundaries are lost
-- 2. It has FLOW CONTROL (write may block when buffer full)
-- 3. It has EOF (closed flag)
-- 4. It's BIDIRECTIONAL (StreamPair = two ChannelProcesses)

-- The refinement:
-- A reliable FIFO ChannelProcess (List UInt8) CAN be implemented as a ByteStream
-- but the ByteStream loses message boundaries.
-- A reliable FIFO ChannelProcess with α = specific message type
-- is implemented as a ByteStream + FRAMING PROTOCOL
-- (length-prefixed, delimiter-separated, TLV, etc.)
```

This boundary-erasing property is fundamental. It's why every application protocol (HTTP, TLS, WebSocket, Protobuf RPC) needs a framing layer — TCP gives you bytes, not messages.

### Framing as the bridge from ByteStream to MessageStream

```
/-- A framing protocol segments a ByteStream into messages.
    This is the bridge from byte-level transport to message-level protocol. -/
structure FramingProtocol (α : Type) where
  /-- Parse one message from the front of the byte stream.
      Returns the message and remaining bytes, or none if incomplete. -/
  parse : List UInt8 → Option (α × List UInt8)
  /-- Serialize a message to bytes. -/
  serialize : α → List UInt8
  /-- Round-trip: parse (serialize m) = some (m, []) -/
  roundtrip : ∀ m, parse (serialize m) = some (m, [])
```

Instances:
- **HTTP/1.1**: framing by `Content-Length` header or chunked `Transfer-Encoding`
- **TLS**: records are length-prefixed (5-byte header: content type + version + length)
- **WebSocket**: frames have opcode + length + optional mask
- **Protobuf/gRPC**: length-prefixed messages
- **Line-delimited** (Redis RESP, SMTP, etc.): delimiter = `\r\n`

A `FramingProtocol α` over a `ByteStream` produces a `MessageStream α`. This is the typed connection to sketch 05's `ChannelProcess α`:

```
-- ByteStream + FramingProtocol α ≈ ChannelProcess α (reliable, FIFO)
-- The framing protocol restores the message boundaries that TCP erased.
```

## Secure Streams and HTTPS

### The Problem: TLS Sits Between ByteStream and Application Protocol

The protocol stack for HTTPS looks like:

```
Application        HTTP Request/Response            (MessageStream HttpMessage)
    │                    │
    │ HTTP framing       │   (Content-Length, chunked TE, \r\n\r\n)
    ▼                    ▼
Plaintext          ByteStream                        (unencrypted application bytes)
    │                    │
    │ TLS record layer   │   (framing + AEAD encryption per record)
    ▼                    ▼
Ciphertext         ByteStream                        (encrypted bytes on the wire)
    │                    │
    │ TCP                │   (reliable delivery)
    ▼                    ▼
Network            ChannelProcess (List UInt8)       (sketch 05)
```

TLS is **not just a framing protocol** — it's a *secure stream transformer*. It takes a plaintext ByteStream and produces a ciphertext ByteStream. The plaintext and ciphertext are both `ByteStream` (same type), but the ciphertext ByteStream has security properties (confidentiality, integrity, authentication) that the plaintext one doesn't.

The TLS record layer does framing (5-byte header + payload), but it also encrypts each record with AEAD. So TLS is `FramingProtocol TlsRecord` composed with `encrypt : TlsRecord → List UInt8`. The framing restores message boundaries (records), and the encryption provides security. Both happen in the same layer.

### SecureStream: Axiomatized TLS Wrapper

A `SecureStream` is a `StreamPair` (bidirectional ByteStream) with axiomatized security properties. We define the types but **axiomatize the security guarantees** rather than deriving them from TLS internals.

**Why axiomatize?** The existing TLS formalization has ~30 bridge axioms for its crypto operations (key derivation, record encrypt/decrypt, HMAC, certificate validation, signature verify). The handshake is a multi-round protocol with version negotiation, extension processing, and cipher suite selection. Proving that TLS correctly provides confidentiality/integrity from these primitives is a major protocol verification effort — the kind of thing ProVerif and Tamarin are built for. Attempting to compose HTTP + TLS record layer + TLS handshake + AEAD + certificate validation into a proven-correct HTTPS implementation would be the formalization equivalent of implementing HTTPS from raw C socket calls: a thousand ways to get it wrong, and the interesting properties require deep crypto reasoning beyond what the repo can prove today.

Instead, we treat TLS the same way we treat TCP: TCP axiomatically implements ByteStream (the refinement theorem is stated, not proved from segment logic). TLS axiomatically provides a SecureStream (the security properties are stated, not proved from cryptographic reductions). Both can be refined later.

```
/-- A secure stream wraps a StreamPair with axiomatized security properties.
    This models the result of a completed TLS handshake.
    The security guarantees are axioms, not derived from TLS internals. -/
structure SecureStream where
  /-- The application-facing streams (plaintext). -/
  plaintext : StreamPair
  /-- The wire-facing streams (ciphertext). -/
  ciphertext : StreamPair
  /-- Peer identity established during handshake. -/
  peerCertificate : Option Certificate
  /-- The TLS connection state (opaque for reasoning purposes). -/
  tlsState : FullTlsState
  /-- Handshake completed successfully. -/
  handshakeComplete : tlsState.protocolState = .connected

/-- Security properties — axiomatized, not derived. -/

-- Confidentiality: observing the ciphertext stream reveals nothing
-- about the plaintext stream (to a computationally bounded adversary).
axiom secureStream_confidential : ∀ (ss : SecureStream),
  ss.handshakeComplete → Confidential ss.ciphertext ss.plaintext

-- Integrity: modifying the ciphertext stream is detected
-- (AEAD authentication tag verification fails).
axiom secureStream_integral : ∀ (ss : SecureStream),
  ss.handshakeComplete → Integral ss.ciphertext ss.plaintext

-- Authentication: if peerCertificate validates to a trust anchor,
-- the peer is who the certificate says it is.
axiom secureStream_authenticated : ∀ (ss : SecureStream) (cert : Certificate),
  ss.peerCertificate = some cert →
  CertPathValid cert trustAnchors →
  Authenticated ss cert

-- Stream preservation: TLS doesn't alter the byte sequence.
-- Plaintext written by the sender arrives as the same plaintext at the receiver.
axiom secureStream_preserves_stream : ∀ (ss : SecureStream),
  ss.handshakeComplete →
  stream_fifo ss.plaintext.outgoing (decryptedIncoming ss) ∧
  stream_reliable ss.plaintext.outgoing (decryptedIncoming ss)
```

### HTTPS Connection: HTTP over SecureStream

An HTTPS connection is HTTP framing over the plaintext side of a SecureStream. The definition is straightforward because SecureStream handles all the security complexity:

```
/-- An HTTPS connection: HTTP protocol over a TLS-secured stream.
    The application reads/writes HTTP messages on the plaintext side.
    TLS handles encryption/authentication transparently. -/
structure HttpsConnection where
  /-- The secure stream (TLS-wrapped). -/
  secure : SecureStream
  /-- HTTP connection state (persistence, version negotiation). -/
  httpState : Http.ConnectionState
  /-- The HTTP framing protocol over the plaintext stream. -/
  framing : FramingProtocol Http.Message

/-- Construct an HTTPS connection from a completed TLS handshake. -/
def HttpsConnection.establish (ss : SecureStream)
  (h : ss.handshakeComplete) : HttpsConnection where
  secure := ss
  httpState := Http.ConnectionState.initial
  framing := httpFraming   -- existing HTTP/1.1 framing logic

/-- Send an HTTP request over HTTPS. -/
def HttpsConnection.sendRequest (conn : HttpsConnection) (req : Http.Request)
  : HttpsConnection :=
  -- Serialize request to bytes (HTTP framing)
  -- Write to plaintext stream (SecureStream handles encryption)
  { conn with secure.plaintext.outgoing :=
      conn.secure.plaintext.outgoing.write (conn.framing.serialize req) }

/-- Receive an HTTP response over HTTPS. -/
def HttpsConnection.recvResponse (conn : HttpsConnection)
  : Option Http.Response × HttpsConnection :=
  -- Read from plaintext stream (SecureStream handles decryption)
  -- Parse response from bytes (HTTP framing)
  let (bytes, stream') := conn.secure.plaintext.incoming.read maxSize
  match conn.framing.parse bytes with
  | some (resp, _) => (some resp, { conn with secure.plaintext.incoming := stream' })
  | none => (none, conn)
```

### Why This Layering Works

1. **HTTP doesn't know about TLS.** The existing HTTP module (Request, Response, Framing, Connection) operates on bytes. It doesn't care whether those bytes flow over a raw TCP ByteStream or the plaintext side of a SecureStream. No changes to the HTTP formalization needed.

2. **Security properties compose upward.** An HTTP Request sent over an HttpsConnection inherits SecureStream's confidentiality/integrity/authentication axioms automatically. The request body is confidential because the plaintext ByteStream it's written to is the plaintext side of a SecureStream whose ciphertext is confidential. No additional proof needed at the HTTP level.

3. **The axiom boundary is clean.** We axiomatize exactly one thing: "a completed TLS handshake produces a SecureStream with these properties." Everything above (HTTP framing, request/response semantics) is proved from definitions. Everything below (TCP implements ByteStream) is separately axiomatized. The two axiom layers don't interact — they're at different levels of the stack.

4. **Refinement path is clear.** If someone later wants to prove the SecureStream axioms from TLS internals, the existing TLS formalization (types, state machine, handshake messages, record layer) provides the starting point. The axioms become theorems. Nothing above them changes.

### HTTPS vs HTTP: The Only Difference

```
-- HTTP connection (insecure):
-- HTTP framing over a raw StreamPair (from TCP)
structure HttpConnection where
  stream : StreamPair
  httpState : Http.ConnectionState
  framing : FramingProtocol Http.Message

-- HTTPS connection (secure):
-- HTTP framing over the plaintext side of a SecureStream
structure HttpsConnection where
  secure : SecureStream    -- this is the only structural difference
  httpState : Http.ConnectionState
  framing : FramingProtocol Http.Message

-- The HTTP protocol logic is identical in both cases.
-- The difference is what carries the bytes:
--   HTTP:  StreamPair (raw TCP)
--   HTTPS: SecureStream.plaintext (TLS-wrapped TCP)
```

This mirrors reality: an HTTP library's request/response logic doesn't change between HTTP and HTTPS. The socket setup differs (plain `connect()` vs `connect()` + TLS handshake), but once the connection is established, HTTP framing is the same over both.

## Key Properties to Prove

### ByteStream axioms

```
-- FIFO: read returns bytes in the order they were written
theorem read_fifo : ∀ s bytes₁ bytes₂,
  let s₁ := s.write bytes₁
  let s₂ := s₁.write bytes₂
  -- reading (bytes₁.length + bytes₂.length) from s₂ yields bytes₁ ++ bytes₂
  (s₂.read (bytes₁.length + bytes₂.length)).1 = bytes₁ ++ bytes₂

-- Write-read conservation: bytes written are exactly the bytes read (eventually)
theorem conservation : ∀ s bytes,
  let s' := s.write bytes
  s'.bytesWritten = s.bytesWritten + bytes.length

-- Close is permanent: once closed, no more writes
theorem close_is_final : ∀ s,
  (s.close).closed = true

-- EOF: a closed, empty stream stays empty
theorem eof_stable : ∀ s, s.eof → s.read n = ([], s)

-- Boundary erasure: write is associative over append
-- This IS the defining property of a byte stream vs message stream
theorem boundary_erasure : ∀ s a b,
  s.write (a ++ b) = (s.write a).write b
```

### StreamPair properties

```
-- Independence: writing to outgoing doesn't affect incoming (and vice versa)
theorem direction_independence : ∀ sp bytes,
  (sp.writeOutgoing bytes).incoming = sp.incoming

-- Half-close: closing outgoing doesn't close incoming
-- (models shutdown(SHUT_WR) — you can still read)
theorem half_close : ∀ sp,
  (sp.closeOutgoing).incoming.closed = sp.incoming.closed
```

### BoundStream properties

```
-- Closing the fd signals EOF on outgoing
theorem close_fd_sends_eof : ∀ bs,
  (closefd bs.fd).outgoing.closed = true

-- Reading from a closed fd is EBADF
theorem read_closed_fd_ebadf : ∀ fd,
  fdState fd = .closed → read fd n = Except.error .EBADF
```

### Framing round-trip

```
-- A framing protocol over a ByteStream correctly reconstructs messages
theorem framing_preserves_messages : ∀ (fp : FramingProtocol α) (msgs : List α),
  let bytes := msgs.bind fp.serialize
  parseAll fp bytes = msgs
```

### SecureStream properties (axiomatized — see "Secure Streams and HTTPS" section)

```
-- These are AXIOMS, not theorems — they assert what TLS provides.

-- Stream preservation: TLS doesn't alter the byte sequence
axiom secureStream_preserves_stream : ...

-- Confidentiality, integrity, authentication: see SecureStream section
axiom secureStream_confidential : ...
axiom secureStream_integral : ...
axiom secureStream_authenticated : ...
```

### HTTPS properties (provable from definitions + SecureStream axioms)

```
-- HTTPS preserves HTTP semantics: the response to a request over HTTPS
-- is the same as over plain HTTP (TLS is transparent to the protocol)
theorem https_preserves_http_semantics :
  ∀ (conn : HttpsConnection) (req : Http.Request),
    httpBehavior conn req = httpBehavior (conn.asPlainHttp) req
    -- where asPlainHttp strips the SecureStream wrapper

-- HTTPS inherits security: an HTTP request sent over HTTPS is confidential
-- (follows directly from SecureStream axiom + the fact that HTTP writes
-- to the plaintext side of the SecureStream)
theorem https_request_confidential :
  ∀ (conn : HttpsConnection) (req : Http.Request),
    conn.secure.handshakeComplete →
    Confidential (conn.secure.ciphertext) (httpSerialize req)
```

## Relationship to Existing SWELib Modules

### Direct refinement targets

| Module | ByteStream role |
|--------|----------------|
| `Networking/Tcp` | TCP implements ByteStream. TCB sequence numbers index into the stream. |
| `OS/Sockets` | `SocketEntry.recvBuf` is the materialized incoming ByteStream. `sendBufUsed` tracks outgoing. |
| `OS/Io` | `FileDescriptor` is the handle to a BoundStream. `close()` triggers EOF. |
| `OS/Epoll` | EPOLLIN = `incoming.available > 0`. EPOLLOUT = `outgoing` has buffer space. |

### Framing consumers

| Module | Framing over ByteStream |
|--------|------------------------|
| `Networking/Tls` | TLS record layer: 5-byte header (type + version + length) frames records over ByteStream. TLS is also a *secure stream transformer* — it encrypts each framed record. See "Secure Streams and HTTPS" section above. |
| `Networking/Http` | HTTP/1.1: headers delimited by `\r\n\r\n`, body by `Content-Length` or chunked encoding. HTTP framing is identical whether the underlying stream is raw TCP or the plaintext side of a SecureStream (HTTPS). |
| `Networking/Websocket` | WebSocket frame: 2+ byte header (opcode + length) + optional mask + payload |
| `Basics/Protobuf` | Length-delimited fields within a byte stream |

### Sketch connections

| Sketch | Relationship |
|--------|-------------|
| 01 (Node) | A Node's abstract Listener maps to a listening socket. accept() produces a BoundStream. |
| 02 (System) | Inter-Node communication = StreamPairs (or MessageStreams) between Nodes. |
| 05 (Network) | `reliableFIFO` channel = ByteStream (boundary-erasing). `ChannelProcess α` = ByteStream + `FramingProtocol α`. |
| 07 (Security) | SecureStream = ByteStream + axiomatized TLS security properties. HTTPS = HTTP framing over SecureStream.plaintext. The adversary model (sketch 07) operates on the ciphertext ByteStream; security axioms guarantee the plaintext ByteStream is protected. |

## Module Structure

```
spec/SWELib/
├── Basics/
│   └── ByteStream.lean              -- Pure ByteStream, MessageStream, FramingProtocol
│                                     -- No OS or protocol dependencies
├── OS/
│   ├── Io.lean                       -- FileDescriptor, FdTable (existing)
│   ├── Sockets/                      -- Socket lifecycle (existing)
│   │   └── Stream.lean               -- NEW: BoundStream, StreamDescriptor
│   │                                 --   ties ByteStream to fd + SockAddr
│   └── Epoll.lean                    -- Readiness in terms of ByteStream (existing, extend)
│
├── Networking/
│   ├── Tcp/
│   │   └── ByteStreamRefinement.lean -- NEW: theorem that TCP implements ByteStream
│   ├── Tls/                          -- TLS types + state machine (existing)
│   │   └── SecureStream.lean         -- NEW: SecureStream type + axiomatized security properties
│   │                                 --   imports ByteStream + existing TLS types
│   │                                 --   security guarantees are axioms, not proved from TLS internals
│   ├── Http/                         -- HTTP as framing over ByteStream (existing, unchanged)
│   │   └── Https.lean               -- NEW: HttpsConnection = HTTP framing over SecureStream
│   │                                 --   imports Http + SecureStream
│   │                                 --   HTTP protocol logic is identical to plain HTTP
│   └── Websocket/                    -- WebSocket as framing over ByteStream
```

`Basics/ByteStream.lean` is the leaf — it imports nothing from OS or Networking. Everything else imports it.

**Axiom budget**: The secure stream layer introduces exactly one axiom boundary: "a completed TLS handshake produces a SecureStream with confidentiality, integrity, and authentication." This parallels the TCP axiom boundary ("TCP implements a reliable FIFO ByteStream"). Both are refinement claims that can be proved later from the lower-level formalizations (TLS internals, TCP segment logic) without changing anything above them.

**What's NOT axiomatized**: HTTP framing, HTTP request/response semantics, the composition of HTTP over SecureStream — these are all definitions with provable properties. The axioms are strictly about what the transport provides (TCP: reliability; TLS: security), not about what the application protocol does with it.

## Resolved Questions

7. **How does security (TLS) interact with ByteStream?** Resolved: TLS is a *secure stream transformer* — it takes a plaintext ByteStream and produces a ciphertext ByteStream. Security properties are axiomatized at the SecureStream level, not derived from TLS internals. HTTPS is HTTP framing over the plaintext side of a SecureStream. See "Secure Streams and HTTPS" section above. The existing TLS type definitions and state machine remain as documentation and as the starting point for a future refinement proof (proving the axioms from TLS internals), but we don't attempt that composition now.

## Open Questions

1. **Partial reads and non-blocking I/O.** The model above has `read` return "up to n bytes." In non-blocking mode, `read` on an empty buffer returns `EAGAIN` instead of blocking. Should the ByteStream model include a blocking/non-blocking flag, or is that purely an OS/Sockets concern? (Likely the latter — ByteStream is the logical content; blocking behavior is about the fd access mode.)

2. **Out-of-band data.** TCP urgent data (`MSG_OOB`) is a separate single-byte channel alongside the main stream. Rarely used in practice (only Telnet IAC). Model it or ignore it? (Probably ignore — it's TCP-specific and nearly obsolete.)

3. **Scatter/gather I/O.** `readv()`/`writev()` operate on vectors of buffers but produce/consume a single logical byte stream. This is a performance optimization, not a semantic distinction. No impact on the ByteStream model.

4. **sendfile() and splice().** Zero-copy operations that move bytes between fds without passing through userspace. The ByteStream abstraction still applies — bytes move from one stream to another — but the implementation avoids materializing them in user memory. Model as a composition of read + write with an optimization note?

5. **Memory-mapped I/O (mmap on sockets).** Rare but possible. The ByteStream abstraction doesn't cover random-access patterns. Not relevant for stream sockets.

6. **Backpressure representation.** The model tracks `sendBufCapacity` and `sendBufUsed` in `SocketEntry`. Should ByteStream itself carry capacity, or is that purely a buffer-management concern layered on top? (Probably the latter — the abstract stream is unbounded; the OS imposes bounds via SO_SNDBUF.)

## Source Specs / Prior Art

- **POSIX.1-2017** (IEEE Std 1003.1): The authoritative spec for read(2), write(2), socket(2), and stream semantics
- **RFC 9293** (TCP): Section 3.1 — "TCP is a connection-oriented, end-to-end reliable protocol... [providing] a continuous stream of octets"
- **Stevens, "Unix Network Programming" Vol 1** (2003): Chapter 2 (byte stream vs message boundaries), Chapter 3 (socket introduction), Chapter 5 (TCP client-server lifecycle)
- **Stevens, "Advanced Programming in the UNIX Environment"** (2013): Chapter 3 (file I/O and fd semantics), Chapter 15 (IPC)
- **Kerrisk, "The Linux Programming Interface"** (2010): Chapters 56-61 (sockets, TCP/UDP, socket I/O)
- **Linux kernel source**: `net/core/stream.c` (generic stream socket support), `include/net/sock.h` (struct sock — the kernel-internal stream state)
- **CSLib**: LTS for ByteStream state machine (write/read/close transitions); bisimulation for proving TCP refines ByteStream
- **Milner, "Communication and Concurrency"** (1989): CCS channels — ByteStream is the concrete realization of a reliable FIFO channel restricted to byte granularity
