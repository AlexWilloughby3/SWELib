/-!
# ByteStream

The fundamental data-plane abstraction for stream-oriented protocols.
A ByteStream is an ordered, reliable sequence of bytes — what `read(fd)` returns
and `write(fd)` consumes on a `SOCK_STREAM` socket.

This module defines the pure mathematical objects (no OS dependencies):
- `ByteStream`: finite/growing ordered byte sequence
- `StreamPair`: bidirectional connection (two independent ByteStreams)
- `MessageStream`: boundary-preserving message sequence (for datagrams)
- `FramingProtocol`: segments a ByteStream into typed messages

## Source Specs
- POSIX.1-2017: read(2), write(2) semantics
- RFC 9293 Section 3.1: "a continuous stream of octets"
- Stevens, "Unix Network Programming" Vol 1, Chapter 2
-/

namespace SWELib.Basics

/-! ## ByteStream -/

/-- A byte stream is a finite sequence of octets, potentially still growing.
    Models the *logical content* of a stream — the sequence of bytes
    that have been (or will be) written/read, independent of buffering,
    segmentation, or delivery mechanism.

    - `data`: bytes currently available to read (the buffer)
    - `bytesWritten`: total bytes ever appended (monotonically increasing)
    - `bytesRead`: total bytes ever consumed (monotonically increasing)
    - `closed`: the writer has signaled end-of-stream (TCP FIN, shutdown(SHUT_WR))

    An open stream may grow; a closed stream is final.

    Why `List UInt8` and not `ByteArray`? We need structural induction and `List`
    lemmas (prefix, append, FIFO properties). `ByteArray` is opaque FFI-backed
    in Lean — fine for computation, not useful for proofs. -/
structure ByteStream where
  /-- Bytes available to read (the buffer). -/
  data : List UInt8
  /-- Total bytes ever appended. Corresponds to TCP's `snd_nxt - iss`. -/
  bytesWritten : Nat
  /-- Total bytes ever consumed. Corresponds to TCP's bytes acknowledged by receiver. -/
  bytesRead : Nat
  /-- Writer has signaled end-of-stream. -/
  closed : Bool
  deriving Repr, DecidableEq

/-- The fundamental invariant: bytesRead + data.length = bytesWritten. -/
def ByteStream.invCounts (s : ByteStream) : Prop :=
  s.bytesRead + s.data.length = s.bytesWritten

/-- An empty, open byte stream. -/
def ByteStream.empty : ByteStream where
  data := []
  bytesWritten := 0
  bytesRead := 0
  closed := false

/-- Number of bytes available to read. -/
def ByteStream.available (s : ByteStream) : Nat := s.data.length

/-- Is the stream at EOF? (closed and fully drained) -/
def ByteStream.eof (s : ByteStream) : Bool := s.closed && s.data.isEmpty

/-- Append bytes to an open stream (models the writer side).
    No-op if the stream is closed. -/
def ByteStream.write (s : ByteStream) (bytes : List UInt8) : ByteStream :=
  if s.closed then s
  else {
    data := s.data ++ bytes
    bytesWritten := s.bytesWritten + bytes.length
    bytesRead := s.bytesRead
    closed := false
  }

/-- Read and consume up to `n` bytes from the front (models the reader side).
    Returns the bytes read and the stream with those bytes removed.
    If fewer than `n` bytes are available, returns what's there.
    Returns empty list on a closed, empty stream (EOF). -/
def ByteStream.read (s : ByteStream) (n : Nat) : List UInt8 × ByteStream :=
  let taken := s.data.take n
  let remaining := s.data.drop n
  (taken, {
    data := remaining
    bytesWritten := s.bytesWritten
    bytesRead := s.bytesRead + taken.length
    closed := s.closed
  })

/-- Peek at up to `n` bytes without consuming (models MSG_PEEK). -/
def ByteStream.peek (s : ByteStream) (n : Nat) : List UInt8 :=
  s.data.take n

/-- Close the stream (no more writes allowed). -/
def ByteStream.close (s : ByteStream) : ByteStream :=
  { s with closed := true }

/-! ## ByteStream Theorems -/

/-- The empty stream satisfies the invariant. -/
theorem ByteStream.empty_invCounts : ByteStream.empty.invCounts := by
  simp [empty, invCounts]

/-- Writing preserves the invariant. -/
theorem ByteStream.write_invCounts (s : ByteStream) (bytes : List UInt8)
    (h : s.invCounts) :
    (s.write bytes).invCounts := by
  unfold invCounts at *
  unfold write
  split
  · exact h
  · simp [List.length_append]; omega

/-- Reading preserves the invariant. -/
theorem ByteStream.read_invCounts (s : ByteStream) (n : Nat)
    (h : s.invCounts) :
    (s.read n).2.invCounts := by
  unfold invCounts at *
  simp [read]
  have key : (s.data.take n).length + (s.data.drop n).length = s.data.length := by
    simp [List.length_take, List.length_drop]; omega
  omega

/-- Closing preserves the invariant. -/
theorem ByteStream.close_invCounts (s : ByteStream) (h : s.invCounts) :
    s.close.invCounts := by
  unfold invCounts at *; simp [ByteStream.close]; exact h

/-- FIFO: read returns bytes in the order they were written.
    Writing `bytes₁` then `bytes₂` to an empty open stream, then reading
    the total length, yields `bytes₁ ++ bytes₂`. -/
theorem ByteStream.read_fifo (bytes₁ bytes₂ : List UInt8) :
    let s₁ := ByteStream.empty.write bytes₁
    let s₂ := s₁.write bytes₂
    (s₂.read (bytes₁.length + bytes₂.length)).1 = bytes₁ ++ bytes₂ := by
  simp [ByteStream.empty, write, read]
  have : bytes₁.length + bytes₂.length = (bytes₁ ++ bytes₂).length := by
    simp [List.length_append]
  rw [this, List.take_length]

/-- Write-read conservation: writing increases bytesWritten by the number of bytes. -/
theorem ByteStream.write_conservation (s : ByteStream) (bytes : List UInt8)
    (h : s.closed = false) :
    (s.write bytes).bytesWritten = s.bytesWritten + bytes.length := by
  simp [write, h]

/-- Close is permanent: closing a stream sets closed to true. -/
theorem ByteStream.close_is_final (s : ByteStream) :
    s.close.closed = true := by
  simp [ByteStream.close]

/-- EOF stability: reading from a closed empty stream returns empty. -/
theorem ByteStream.eof_read_empty (s : ByteStream) (h : s.eof = true) (n : Nat) :
    (s.read n).1 = [] := by
  unfold eof at h
  simp only [Bool.and_eq_true_iff] at h
  have hd : s.data = [] := List.isEmpty_iff.mp h.2
  simp [read, hd]

/-- Boundary erasure: `write (a ++ b)` is the same as `write a` then `write b`.
    This IS the defining property of a byte stream vs a message stream. -/
theorem ByteStream.boundary_erasure (s : ByteStream) (a b : List UInt8)
    (h : s.closed = false) :
    s.write (a ++ b) = (s.write a).write b := by
  unfold write
  simp [h, List.append_assoc, List.length_append, Nat.add_assoc]

/-- Peek returns the same bytes as read without consuming them. -/
theorem ByteStream.peek_eq_read_fst (s : ByteStream) (n : Nat) :
    s.peek n = (s.read n).1 := by
  simp [peek, read]

/-- Writing to a closed stream is a no-op. -/
theorem ByteStream.write_closed_noop (s : ByteStream) (bytes : List UInt8)
    (h : s.closed = true) :
    s.write bytes = s := by
  simp [write, h]

/-- Reading 0 bytes returns empty and leaves the stream unchanged. -/
theorem ByteStream.read_zero (s : ByteStream) :
    (s.read 0).1 = [] ∧ (s.read 0).2 = s := by
  simp [read]

/-! ## StreamPair -/

/-- A bidirectional byte stream connection.
    Models a connected SOCK_STREAM socket.
    Each direction is an independent ByteStream.

    - `outgoing`: bytes flowing from local to remote (local writes, remote reads)
    - `incoming`: bytes flowing from remote to local (remote writes, local reads) -/
structure StreamPair where
  /-- Bytes flowing from local to remote (local writes, remote reads). -/
  outgoing : ByteStream
  /-- Bytes flowing from remote to local (remote writes, local reads). -/
  incoming : ByteStream
  deriving Repr, DecidableEq

/-- A fresh bidirectional stream (both directions open and empty). -/
def StreamPair.empty : StreamPair where
  outgoing := ByteStream.empty
  incoming := ByteStream.empty

/-- Write bytes to the outgoing stream. -/
def StreamPair.writeOutgoing (sp : StreamPair) (bytes : List UInt8) : StreamPair :=
  { sp with outgoing := sp.outgoing.write bytes }

/-- Read bytes from the incoming stream. -/
def StreamPair.readIncoming (sp : StreamPair) (n : Nat) : List UInt8 × StreamPair :=
  let (bytes, incoming') := sp.incoming.read n
  (bytes, { sp with incoming := incoming' })

/-- Close the outgoing stream (models shutdown(SHUT_WR)).
    The incoming stream remains open — half-close. -/
def StreamPair.closeOutgoing (sp : StreamPair) : StreamPair :=
  { sp with outgoing := sp.outgoing.close }

/-- Close the incoming stream (models shutdown(SHUT_RD)). -/
def StreamPair.closeIncoming (sp : StreamPair) : StreamPair :=
  { sp with incoming := sp.incoming.close }

/-- Close both directions (models close(fd)). -/
def StreamPair.closeBoth (sp : StreamPair) : StreamPair where
  outgoing := sp.outgoing.close
  incoming := sp.incoming.close

/-! ## StreamPair Theorems -/

/-- Direction independence: writing to outgoing doesn't affect incoming. -/
theorem StreamPair.writeOutgoing_preserves_incoming (sp : StreamPair) (bytes : List UInt8) :
    (sp.writeOutgoing bytes).incoming = sp.incoming := by
  simp [writeOutgoing]

/-- Direction independence: reading from incoming doesn't affect outgoing. -/
theorem StreamPair.readIncoming_preserves_outgoing (sp : StreamPair) (n : Nat) :
    (sp.readIncoming n).2.outgoing = sp.outgoing := by
  simp [readIncoming]

/-- Half-close: closing outgoing doesn't close incoming. -/
theorem StreamPair.half_close_outgoing (sp : StreamPair) :
    (sp.closeOutgoing).incoming.closed = sp.incoming.closed := by
  simp [closeOutgoing]

/-- Half-close: closing incoming doesn't close outgoing. -/
theorem StreamPair.half_close_incoming (sp : StreamPair) :
    (sp.closeIncoming).outgoing.closed = sp.outgoing.closed := by
  simp [closeIncoming]

/-! ## MessageStream -/

/-- A message stream preserves message boundaries.
    Each read returns exactly one message (or none).
    Models SOCK_DGRAM (UDP), SOCK_SEQPACKET, and application-level framing.

    When `α = List UInt8`, this is a raw datagram stream.
    When `α = HttpRequest`, it's an HTTP request stream.
    When `α = WebSocketFrame`, it's a WebSocket frame stream.

    The key distinction from ByteStream: a MessageStream *preserves boundaries*.
    Each message is delivered as a unit. In contrast, ByteStream has no internal
    boundaries — `write([1,2])` followed by `write([3])` is indistinguishable
    from `write([1])` followed by `write([2,3])`.

    This maps to the Linux syscall difference:
    - `read()` on SOCK_STREAM: returns up to N bytes, no boundary preservation
    - `recvfrom()` on SOCK_DGRAM: returns exactly one datagram -/
structure MessageStream (α : Type) where
  /-- Messages available to read, in FIFO order. -/
  messages : List α
  /-- No more messages will arrive. -/
  closed : Bool
  deriving Repr

/-- An empty, open message stream. -/
def MessageStream.empty : MessageStream α where
  messages := []
  closed := false

/-- Enqueue a message. -/
def MessageStream.send (ms : MessageStream α) (msg : α) : MessageStream α :=
  if ms.closed then ms
  else { ms with messages := ms.messages ++ [msg] }

/-- Dequeue one message (FIFO). -/
def MessageStream.recv (ms : MessageStream α) : Option α × MessageStream α :=
  match ms.messages with
  | [] => (none, ms)
  | m :: rest => (some m, { ms with messages := rest })

/-- Number of messages available. -/
def MessageStream.available (ms : MessageStream α) : Nat := ms.messages.length

/-- Close the message stream. -/
def MessageStream.close (ms : MessageStream α) : MessageStream α :=
  { ms with closed := true }

/-! ## MessageStream Theorems -/

/-- Boundary preservation: sending two messages preserves both boundaries.
    This is the dual of ByteStream.boundary_erasure — messages do NOT merge. -/
theorem MessageStream.boundary_preservation
    (ms : MessageStream α) (m₁ m₂ : α) (h : ms.closed = false) :
    let ms' := (ms.send m₁).send m₂
    ms'.messages = ms.messages ++ [m₁, m₂] := by
  simp [send, h, List.append_assoc]

/-- Receiving from a two-message send on an empty stream yields the first message. -/
theorem MessageStream.recv_order (m₁ m₂ : α) :
    let ms := (MessageStream.empty.send m₁).send m₂
    ms.recv.1 = some m₁ := by
  simp [MessageStream.empty, send, recv]

/-! ## FramingProtocol -/

/-- A framing protocol segments a ByteStream into typed messages.
    This is the bridge from byte-level transport to message-level protocol.

    Instances include:
    - HTTP/1.1: headers delimited by `\r\n\r\n`, body by Content-Length or chunked TE
    - TLS: 5-byte record header (content type + version + length)
    - WebSocket: 2+ byte frame header (opcode + length + optional mask)
    - Length-prefixed: protobuf/gRPC
    - Line-delimited: Redis RESP, SMTP (`\r\n`)

    A `FramingProtocol α` over a `ByteStream` produces a `MessageStream α`.
    This restores the message boundaries that TCP erases:
      ByteStream + FramingProtocol α ≈ ChannelProcess α (reliable, FIFO) -/
structure FramingProtocol (α : Type) where
  /-- Parse one message from the front of the byte stream.
      Returns the message and remaining bytes, or `none` if incomplete. -/
  parse : List UInt8 → Option (α × List UInt8)
  /-- Serialize a message to bytes. -/
  serialize : α → List UInt8
  /-- Round-trip: parsing serialized output recovers the message exactly. -/
  roundtrip : ∀ m, parse (serialize m) = some (m, [])
  /-- Prefix-free round-trip: parsing serialized output with trailing bytes
      recovers the message and leaves the trailing bytes untouched. -/
  roundtrip_prefix : ∀ m rest, parse (serialize m ++ rest) = some (m, rest)
  /-- Parsing consumes at least one byte (well-foundedness for parseAll). -/
  parse_progress : ∀ bytes msg rest, parse bytes = some (msg, rest) →
    rest.length < bytes.length

/-- Parse all complete messages from a byte buffer using a framing protocol. -/
def FramingProtocol.parseAll (fp : FramingProtocol α) : List UInt8 → List α × List UInt8
  | bytes =>
    match h : fp.parse bytes with
    | none => ([], bytes)
    | some (msg, rest) =>
      have : rest.length < bytes.length := fp.parse_progress bytes msg rest h
      let (msgs, leftover) := fp.parseAll rest
      (msg :: msgs, leftover)
termination_by bytes => bytes.length

/-- Serializing then parsing a single message recovers it exactly. -/
theorem FramingProtocol.serialize_parse_roundtrip (fp : FramingProtocol α) (m : α) :
    fp.parse (fp.serialize m) = some (m, []) :=
  fp.roundtrip m

/-- Serializing a list of messages then parsing recovers them all. -/
theorem FramingProtocol.parseAll_serialized (fp : FramingProtocol α) (msgs : List α) :
    (fp.parseAll (msgs.flatMap fp.serialize)).1 = msgs := by
  induction msgs with
  | nil =>
    simp only [List.flatMap_nil]
    unfold parseAll
    dsimp only
    cases heq : fp.parse [] with
    | none => rfl
    | some v =>
      obtain ⟨msg, rest⟩ := v
      exfalso; have h := fp.parse_progress [] msg rest heq; simp [List.length] at h
  | cons m rest ih =>
    simp only [List.flatMap_cons]
    unfold parseAll
    dsimp only
    rw [fp.roundtrip_prefix m (rest.flatMap fp.serialize)]
    simp [ih]

end SWELib.Basics
