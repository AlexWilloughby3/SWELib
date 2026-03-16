import SWELib.OS.Sockets.Types

/-!
# Socket System State & Operations

State machine and operations for the POSIX socket lifecycle:
`socket → bind → listen → accept → recv → send → close`.

All operations are pure functions: `State → args → State × Except Errno Result`.

References:
- socket(2):  https://man7.org/linux/man-pages/man2/socket.2.html
- bind(2):    https://man7.org/linux/man-pages/man2/bind.2.html
- listen(2):  https://man7.org/linux/man-pages/man2/listen.2.html
- accept(2):  https://man7.org/linux/man-pages/man2/accept.2.html
- connect(2): https://man7.org/linux/man-pages/man2/connect.2.html
- send(2):    https://man7.org/linux/man-pages/man2/send.2.html
- recv(2):    https://man7.org/linux/man-pages/man2/recv.2.html
- sendto(2):  https://man7.org/linux/man-pages/man2/sendto.2.html
- recvfrom(2):https://man7.org/linux/man-pages/man2/recvfrom.2.html
- shutdown(2):https://man7.org/linux/man-pages/man2/shutdown.2.html
-/

namespace SWELib.OS

/-! ## System state -/

/-- Complete socket system state.
    Extends the fd table with socket-specific bookkeeping. -/
structure SocketSystemState where
  /-- Per-process fd table. -/
  fdTable : FdTable
  /-- Map from fd number to socket entry. -/
  sockets : Nat → Option SocketEntry
  /-- Addresses currently bound by some socket. -/
  boundAddrs : List SockAddr
  /-- Pending connection queue per listening socket fd. -/
  pendingConns : Nat → List SockAddr

/-- Empty socket system state. -/
def SocketSystemState.empty : SocketSystemState :=
  { fdTable := FdTable.empty
    sockets := fun _ => none
    boundAddrs := []
    pendingConns := fun _ => [] }

/-! ## socket(2) -/

/-- `socket(2)`: create a new socket fd.
    `newFd` models the kernel's fd allocation. -/
def SocketSystemState.socket (s : SocketSystemState)
    (family : AddressFamily) (sockType : SocketType) (newFd : Nat) :
    SocketSystemState × Except Errno FileDescriptor :=
  -- Check if fd slot is already in use (EMFILE simplification)
  match s.fdTable newFd with
  | some (.open _) => (s, .error .EMFILE)
  | _ =>
    let entry := SocketEntry.fresh family sockType
    let s' : SocketSystemState :=
      { s with
        fdTable := s.fdTable.update newFd (.open .socket)
        sockets := fun n => if n = newFd then some entry else s.sockets n }
    (s', .ok ⟨newFd⟩)

/-! ## bind(2) -/

/-- `bind(2)`: bind a socket to a local address. -/
def SocketSystemState.bind (s : SocketSystemState)
    (fd : FileDescriptor) (addr : SockAddr) :
    SocketSystemState × Except Errno Unit :=
  match s.sockets fd.fd with
  | none => (s, .error .EBADF)
  | some entry =>
    if entry.phase != .unbound then (s, .error .EINVAL)
    else if entry.family != addr.family then (s, .error .EAFNOSUPPORT)
    else if s.boundAddrs.contains addr then (s, .error .EADDRINUSE)
    else
      let entry' := { entry with phase := .bound, localAddr := some addr }
      let s' : SocketSystemState :=
        { s with
          sockets := fun n => if n = fd.fd then some entry' else s.sockets n
          boundAddrs := addr :: s.boundAddrs }
      (s', .ok ())

/-! ## listen(2) -/

/-- `listen(2)`: mark a bound stream socket as listening. -/
def SocketSystemState.listen (s : SocketSystemState)
    (fd : FileDescriptor) (_backlog : Nat) :
    SocketSystemState × Except Errno Unit :=
  match s.sockets fd.fd with
  | none => (s, .error .EBADF)
  | some entry =>
    if entry.phase != .bound then (s, .error .EINVAL)
    else if entry.sockType != .SOCK_STREAM then (s, .error .EINVAL)
    else
      let entry' := { entry with phase := .listening }
      let s' : SocketSystemState :=
        { s with
          sockets := fun n => if n = fd.fd then some entry' else s.sockets n }
      (s', .ok ())

/-! ## accept(2) -/

/-- `accept(2)`: accept a pending connection on a listening socket.
    `newFd` models the kernel's allocation of the client fd. -/
def SocketSystemState.accept (s : SocketSystemState)
    (fd : FileDescriptor) (newFd : Nat) :
    SocketSystemState × Except Errno FileDescriptor :=
  match s.sockets fd.fd with
  | none => (s, .error .EBADF)
  | some entry =>
    if entry.phase != .listening then (s, .error .EINVAL)
    else
      match s.pendingConns fd.fd with
      | [] => (s, .error .EAGAIN)
      | clientAddr :: rest =>
        let clientEntry : SocketEntry :=
          { family := entry.family
            sockType := .SOCK_STREAM
            phase := .connected
            options := []
            recvBuf := []
            sendBufCapacity := 65536
            sendBufUsed := 0
            localAddr := entry.localAddr
            remoteAddr := some clientAddr }
        let s' : SocketSystemState :=
          { s with
            fdTable := s.fdTable.update newFd (.open .socket)
            sockets := fun n =>
              if n = newFd then some clientEntry else s.sockets n
            pendingConns := fun n =>
              if n = fd.fd then rest else s.pendingConns n }
        (s', .ok ⟨newFd⟩)

/-! ## connect(2) -/

/-- `connect(2)`: initiate a connection to a remote address.
    For simplicity, connect succeeds immediately (no SYN_SENT modeling). -/
def SocketSystemState.connect (s : SocketSystemState)
    (fd : FileDescriptor) (addr : SockAddr) :
    SocketSystemState × Except Errno Unit :=
  match s.sockets fd.fd with
  | none => (s, .error .EBADF)
  | some entry =>
    if entry.phase == .connected || entry.phase == .shutdown then
      (s, .error .EISCONN)
    else if entry.phase == .listening then (s, .error .EINVAL)
    else if entry.family != addr.family then (s, .error .EAFNOSUPPORT)
    else
      let entry' := { entry with phase := .connected, remoteAddr := some addr }
      let s' : SocketSystemState :=
        { s with
          sockets := fun n => if n = fd.fd then some entry' else s.sockets n }
      (s', .ok ())

/-! ## send(2) -/

/-- `send(2)`: send data on a connected socket.
    Returns the number of bytes accepted into the send buffer. -/
def SocketSystemState.send (s : SocketSystemState)
    (fd : FileDescriptor) (data : ByteArray) :
    SocketSystemState × Except Errno Nat :=
  match s.sockets fd.fd with
  | none => (s, .error .EBADF)
  | some entry =>
    if entry.phase != .connected then (s, .error .ENOTCONN)
    else
      let available := entry.sendBufCapacity - entry.sendBufUsed
      if available == 0 then (s, .error .EAGAIN)
      else
        let toSend := min data.size available
        let entry' := { entry with sendBufUsed := entry.sendBufUsed + toSend }
        let s' : SocketSystemState :=
          { s with
            sockets := fun n => if n = fd.fd then some entry' else s.sockets n }
        (s', .ok toSend)

/-! ## recv(2) -/

/-- `recv(2)`: receive data from a connected socket.
    Pops from the front of the receive buffer (FIFO). -/
def SocketSystemState.recv (s : SocketSystemState)
    (fd : FileDescriptor) :
    SocketSystemState × Except Errno ByteArray :=
  match s.sockets fd.fd with
  | none => (s, .error .EBADF)
  | some entry =>
    if entry.phase != .connected then (s, .error .ENOTCONN)
    else
      match entry.recvBuf with
      | [] => (s, .error .EAGAIN)
      | chunk :: rest =>
        let entry' := { entry with recvBuf := rest }
        let s' : SocketSystemState :=
          { s with
            sockets := fun n => if n = fd.fd then some entry' else s.sockets n }
        (s', .ok chunk)

/-! ## sendto(2) -/

/-- `sendto(2)`: send data on a datagram socket to a specific address.
    Returns the number of bytes sent. -/
def SocketSystemState.sendto (s : SocketSystemState)
    (fd : FileDescriptor) (data : ByteArray) (dest : SockAddr) :
    SocketSystemState × Except Errno Nat :=
  match s.sockets fd.fd with
  | none => (s, .error .EBADF)
  | some entry =>
    if entry.sockType != .SOCK_DGRAM then (s, .error .EINVAL)
    else if entry.family != dest.family then (s, .error .EAFNOSUPPORT)
    else
      -- Datagrams: just accept the full message
      (s, .ok data.size)

/-! ## recvfrom(2) -/

/-- `recvfrom(2)`: receive data from a datagram socket.
    Returns the data and the source address. -/
def SocketSystemState.recvfrom (s : SocketSystemState)
    (fd : FileDescriptor) :
    SocketSystemState × Except Errno (ByteArray × SockAddr) :=
  match s.sockets fd.fd with
  | none => (s, .error .EBADF)
  | some entry =>
    if entry.sockType != .SOCK_DGRAM then (s, .error .EINVAL)
    else
      match entry.recvBuf with
      | [] => (s, .error .EAGAIN)
      | chunk :: rest =>
        -- For datagrams we need a source addr; use remoteAddr as placeholder
        match entry.remoteAddr with
        | some srcAddr =>
          let entry' := { entry with recvBuf := rest }
          let s' : SocketSystemState :=
            { s with
              sockets := fun n => if n = fd.fd then some entry' else s.sockets n }
          (s', .ok (chunk, srcAddr))
        | none =>
          -- No source address available
          (s, .error .EAGAIN)

/-! ## shutdown(2) -/

/-- `shutdown(2)`: shut down part or all of a full-duplex connection. -/
def SocketSystemState.shutdown (s : SocketSystemState)
    (fd : FileDescriptor) (_how : ShutdownHow) :
    SocketSystemState × Except Errno Unit :=
  match s.sockets fd.fd with
  | none => (s, .error .EBADF)
  | some entry =>
    if entry.phase != .connected then (s, .error .ENOTCONN)
    else
      let entry' := { entry with phase := .shutdown }
      let s' : SocketSystemState :=
        { s with
          sockets := fun n => if n = fd.fd then some entry' else s.sockets n }
      (s', .ok ())

/-! ## setsockopt(2) / getsockopt(2) -/

/-- `setsockopt(2)`: enable a socket option. -/
def SocketSystemState.setsockopt (s : SocketSystemState)
    (fd : FileDescriptor) (opt : SocketOption) :
    SocketSystemState × Except Errno Unit :=
  match s.sockets fd.fd with
  | none => (s, .error .EBADF)
  | some entry =>
    if entry.options.contains opt then (s, .ok ())  -- already set
    else
      let entry' := { entry with options := opt :: entry.options }
      let s' : SocketSystemState :=
        { s with
          sockets := fun n => if n = fd.fd then some entry' else s.sockets n }
      (s', .ok ())

/-- `getsockopt(2)`: check whether a socket option is enabled. -/
def SocketSystemState.getsockopt (s : SocketSystemState)
    (fd : FileDescriptor) (opt : SocketOption) :
    Except Errno Bool :=
  match s.sockets fd.fd with
  | none => .error .EBADF
  | some entry => .ok (entry.options.contains opt)

/-! ## deliver (network event) -/

/-- Model an incoming data delivery: appends a chunk to the receive buffer.
    This is a pure specification-level transition, not a syscall. -/
def SocketSystemState.deliver (s : SocketSystemState)
    (fd : Nat) (data : ByteArray) :
    SocketSystemState :=
  match s.sockets fd with
  | none => s
  | some entry =>
    let entry' := { entry with recvBuf := entry.recvBuf ++ [data] }
    { s with
      sockets := fun n => if n = fd then some entry' else s.sockets n }

/-! ## close(2) -/

/-- `close(2)` for sockets: release the fd and remove socket state. -/
def SocketSystemState.close (s : SocketSystemState)
    (fd : FileDescriptor) :
    SocketSystemState × Except Errno Unit :=
  let (fdTable', result) := s.fdTable.close fd
  match result with
  | .ok () =>
    -- Remove bound address if any
    let removedAddr := match s.sockets fd.fd with
      | some entry => entry.localAddr
      | none => none
    let boundAddrs' := match removedAddr with
      | some addr => s.boundAddrs.filter (· != addr)
      | none => s.boundAddrs
    let s' : SocketSystemState :=
      { s with
        fdTable := fdTable'
        sockets := fun n => if n = fd.fd then none else s.sockets n
        boundAddrs := boundAddrs'
        pendingConns := fun n => if n = fd.fd then [] else s.pendingConns n }
    (s', .ok ())
  | .error e => (s, .error e)

end SWELib.OS
