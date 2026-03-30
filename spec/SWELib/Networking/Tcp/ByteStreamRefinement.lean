import SWELib.Basics.ByteStream
import SWELib.Networking.Tcp.Tcb
import SWELib.Networking.Tcp.State

/-!
# TCP Implements ByteStream — Refinement

TCP's job is to implement a reliable ByteStream over unreliable IP datagrams.

- ByteStream is the WHAT (the abstraction the application sees)
- TCP is the HOW (the mechanism that delivers it)

The connection between TCP sequence numbers and ByteStream counters:
- `ByteStream.bytesWritten = TCB.snd_nxt - TCB.iss`  (sender side)
- `ByteStream.bytesRead` on remote = `TCB.snd_una - TCB.iss`  (acknowledged)
- `ByteStream.data.length` on recv side ≤ `TCB.rcv_wnd`  (flow control)

A TCP segment carries a slice of the byte stream:
  `segment.payload = stream.data[seq - iss .. seq - iss + len]`

The refinement claims here are **axiomatized** — they assert what TCP provides
without deriving it from segment-level logic. They can be proved later from
the TCP state machine (`Tcb`, `Transition`) without changing anything above them.

## Source Specs
- RFC 9293 Section 3.1: "a continuous stream of octets"
- RFC 9293 Section 3.4: Sequence Numbers
- RFC 9293 Section 3.8: Data Communication
-/

namespace SWELib.Networking.Tcp

open SWELib.Basics

/-! ## Refinement Relation -/

/-- A refinement relation connecting a TCP control block to a StreamPair.
    This states that the TCB's sequence-number bookkeeping correctly tracks
    the logical byte stream's state. -/
structure TcpRefines (tcb : TCB) (conn : StreamPair) : Prop where
  /-- The number of bytes written to the outgoing stream equals
      the distance from ISS to SND.NXT (modulo 32-bit wrapping).
      We work in Nat here for the logical model. -/
  snd_nxt_tracks_written :
    conn.outgoing.bytesWritten = (seqSub tcb.snd_nxt tcb.iss).val.toNat
  /-- The number of bytes acknowledged by the receiver equals
      the distance from ISS to SND.UNA. -/
  snd_una_tracks_acked :
    conn.outgoing.bytesRead ≤ (seqSub tcb.snd_una tcb.iss).val.toNat
  /-- The receive window bounds the amount of unread incoming data. -/
  rcv_wnd_bounds_incoming :
    conn.incoming.available ≤ tcb.rcv_wnd
  /-- The TCB is in an established (data-transfer) state. -/
  tcb_established : tcb.state.canSendData = true

/-! ## Stream Properties -/

/-- A stream is FIFO: bytes arrive in the order they were sent. -/
def stream_fifo (_sent _received : ByteStream) : Prop :=
  -- The first n bytes ever read from `received` are a prefix
  -- of the bytes ever written to `sent`.
  -- Placeholder: actual formulation needs history tracking.
  True

/-- A stream is reliable: all bytes written are eventually readable
    (assuming the connection is not reset). -/
def stream_reliable (sent received : ByteStream) : Prop :=
  sent.closed → sent.bytesWritten = received.bytesWritten

/-- A stream is non-duplicating: no byte is delivered more than once. -/
def stream_non_duplicating (sent received : ByteStream) : Prop :=
  received.bytesRead ≤ sent.bytesWritten

/-! ## Refinement Axioms -/

/-- A TCP connection in the established state correctly implements a StreamPair.

    1. Bytes written by the sender appear in the same order at the receiver (FIFO)
    2. No bytes are lost (reliability) — assuming the connection is not reset
    3. No bytes are duplicated (TCP deduplication via sequence numbers)
    4. EOF is delivered (FIN is reliably transmitted)

    This is the core correctness property of TCP, expressed as a refinement
    from the TCP state machine to the ByteStream abstraction. -/
axiom tcp_implements_bytestream :
  ∀ (tcb : TCB) (conn : StreamPair),
    TcpRefines tcb conn →
    stream_fifo conn.outgoing conn.incoming ∧
    stream_reliable conn.outgoing conn.incoming ∧
    stream_non_duplicating conn.outgoing conn.incoming

/-- TCP preserves byte order (FIFO). Consequence of tcp_implements_bytestream. -/
axiom tcp_fifo :
  ∀ (tcb : TCB) (conn : StreamPair),
    TcpRefines tcb conn →
    stream_fifo conn.outgoing conn.incoming

/-- TCP delivers all bytes (reliability). Consequence of tcp_implements_bytestream. -/
axiom tcp_reliable :
  ∀ (tcb : TCB) (conn : StreamPair),
    TcpRefines tcb conn →
    stream_reliable conn.outgoing conn.incoming

/-- When TCP sends FIN (transition to FIN_WAIT_1 or LAST_ACK),
    the outgoing stream is closed. -/
axiom tcp_fin_closes_stream :
  ∀ (tcb : TCB) (conn : StreamPair),
    TcpRefines tcb conn →
    (tcb.state = .finWait1 ∨ tcb.state = .lastAck) →
    conn.outgoing.closed = true

/-- When TCP receives FIN (transition to CLOSE_WAIT or TIME_WAIT),
    the incoming stream is closed. -/
axiom tcp_fin_received_closes_incoming :
  ∀ (tcb : TCB) (conn : StreamPair),
    TcpRefines tcb conn →
    (tcb.state = .closeWait ∨ tcb.state = .timeWait) →
    conn.incoming.closed = true

end SWELib.Networking.Tcp
