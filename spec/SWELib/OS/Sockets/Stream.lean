import SWELib.Basics.ByteStream
import SWELib.OS.Io
import SWELib.OS.Sockets.Types

/-!
# Stream Sockets — ByteStream Anchored to File Descriptors

The OS-level view of byte streams: anchored to file descriptors, mediated by
the kernel, with reference-counted sharing (fork, dup, SCM_RIGHTS).

## Source Specs
- POSIX.1-2017: read(2), write(2), close(2), shutdown(2)
- socket(7): SO_RCVBUF, SO_SNDBUF
- tcp(7): buffer sizes, backpressure
- Stevens, "Unix Network Programming" Vol 1, Chapter 3
-/

namespace SWELib.OS.Sockets

open SWELib.Basics
open SWELib.OS

/-! ## StreamDescriptor -/

/-- A stream descriptor is the kernel-internal reference to a stream.
    Multiple fds (possibly in different processes) can point to the same one.
    This mirrors the Linux kernel's `struct socket` / `struct sock` separation:
    the fd is a per-process handle; the socket is a kernel-global object
    with a reference count.

    When `refCount` drops to 0, the stream is torn down (TCP sends FIN). -/
structure StreamDescriptor where
  /-- Kernel-internal identifier. -/
  id : Nat
  /-- The bidirectional byte stream. -/
  stream : StreamPair
  /-- Number of fds currently pointing to this descriptor. -/
  refCount : Nat
  /-- Reference count is always positive for a live descriptor. -/
  inv_refCount : refCount > 0 := by omega
  deriving Repr

/-! ## BoundStream -/

/-- A byte stream anchored to a file descriptor.
    This is the OS-visible object — the fd is how userspace refers to the stream.
    The fd must be open and of kind `.socket` in the process's FdTable.

    The chain from socket creation to stream:
    1. `socket()` creates fd (FdKind.socket) — no stream yet
    2. `bind()` + `listen()` — fd is a listener, not a stream
    3. `accept()` creates NEW fd + allocates a StreamPair → BoundStream
    4. `connect()` on a client socket → fd becomes a BoundStream
    5. `read(fd)`/`write(fd)` operates on the BoundStream's streams
    6. `close(fd)` closes the fd AND signals EOF on the outgoing stream -/
structure BoundStream where
  /-- The file descriptor through which userspace accesses this stream. -/
  fd : FileDescriptor
  /-- The underlying kernel stream descriptor. -/
  descriptor : StreamDescriptor
  /-- Local socket address (IP + port, or Unix path). -/
  local_ : SockAddr
  /-- Remote socket address. -/
  remote : SockAddr
  deriving Repr

/-- The bidirectional stream pair for this bound stream. -/
def BoundStream.streamPair (bs : BoundStream) : StreamPair :=
  bs.descriptor.stream

/-- Bytes available to read on the incoming side. -/
def BoundStream.recvAvailable (bs : BoundStream) : Nat :=
  bs.descriptor.stream.incoming.available

/-- Bytes currently buffered on the outgoing side. -/
def BoundStream.sendBufUsed (bs : BoundStream) : Nat :=
  bs.descriptor.stream.outgoing.available

/-! ## Operations -/

/-- Read up to `n` bytes from a bound stream (models `read(fd, buf, n)`).
    Returns EBADF if the fd is not open, otherwise returns bytes read
    and updated bound stream. -/
def BoundStream.sysRead (bs : BoundStream) (fdTable : FdTable) (n : Nat)
    : Except Errno (List UInt8 × BoundStream) :=
  match fdTable.lookup bs.fd with
  | some (FdState.open _) =>
    let (bytes, stream') := bs.descriptor.stream.incoming.read n
    .ok (bytes, { bs with descriptor := { bs.descriptor with
      stream := { bs.descriptor.stream with incoming := stream' } } })
  | _ => .error .EBADF

/-- Write bytes to a bound stream (models `write(fd, buf, n)`).
    Returns EBADF if fd not open, EPIPE if outgoing is closed. -/
def BoundStream.sysWrite (bs : BoundStream) (fdTable : FdTable) (bytes : List UInt8)
    : Except Errno BoundStream :=
  match fdTable.lookup bs.fd with
  | some (FdState.open _) =>
    if bs.descriptor.stream.outgoing.closed then .error .EPIPE
    else .ok { bs with descriptor := { bs.descriptor with
      stream := { bs.descriptor.stream with
        outgoing := bs.descriptor.stream.outgoing.write bytes } } }
  | _ => .error .EBADF

/-- Shutdown one or both directions of the stream (models `shutdown(fd, how)`). -/
def BoundStream.sysShutdown (bs : BoundStream) (how : ShutdownHow)
    : BoundStream :=
  let stream' := match how with
    | .SHUT_RD => bs.descriptor.stream.closeIncoming
    | .SHUT_WR => bs.descriptor.stream.closeOutgoing
    | .SHUT_RDWR => bs.descriptor.stream.closeBoth
  { bs with descriptor := { bs.descriptor with stream := stream' } }

/-! ## Theorems -/

/-- Closing the fd (via shutdown SHUT_WR) signals EOF on outgoing. -/
theorem BoundStream.shutdown_wr_closes_outgoing (bs : BoundStream) :
    (bs.sysShutdown .SHUT_WR).descriptor.stream.outgoing.closed = true := by
  simp [sysShutdown, StreamPair.closeOutgoing, ByteStream.close]

/-- Shutdown SHUT_WR does not affect the incoming stream (half-close). -/
theorem BoundStream.shutdown_wr_preserves_incoming (bs : BoundStream) :
    (bs.sysShutdown .SHUT_WR).descriptor.stream.incoming =
    bs.descriptor.stream.incoming := by
  simp [sysShutdown, StreamPair.closeOutgoing]

/-- Shutdown SHUT_RD does not affect the outgoing stream (half-close). -/
theorem BoundStream.shutdown_rd_preserves_outgoing (bs : BoundStream) :
    (bs.sysShutdown .SHUT_RD).descriptor.stream.outgoing =
    bs.descriptor.stream.outgoing := by
  simp [sysShutdown, StreamPair.closeIncoming]

/-- Writing to a closed outgoing stream returns EPIPE. -/
theorem BoundStream.write_closed_epipe (bs : BoundStream) (fdTable : FdTable)
    (bytes : List UInt8)
    (hOpen : fdTable.lookup bs.fd = some (FdState.open .socket))
    (hClosed : bs.descriptor.stream.outgoing.closed = true) :
    bs.sysWrite fdTable bytes = .error .EPIPE := by
  simp [sysWrite, hOpen, hClosed]

/-! ## Epoll Readiness in Terms of ByteStream -/

/-- EPOLLIN readiness: the incoming stream has bytes available or is at EOF. -/
def BoundStream.epollInReady (bs : BoundStream) : Bool :=
  bs.descriptor.stream.incoming.available > 0 ||
  bs.descriptor.stream.incoming.eof

/-- EPOLLOUT readiness: the outgoing stream is open (can accept writes). -/
def BoundStream.epollOutReady (bs : BoundStream) : Bool :=
  !bs.descriptor.stream.outgoing.closed

/-- EPOLLHUP: both directions are closed. -/
def BoundStream.epollHup (bs : BoundStream) : Bool :=
  bs.descriptor.stream.outgoing.closed &&
  bs.descriptor.stream.incoming.closed

end SWELib.OS.Sockets
