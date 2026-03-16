import SWELib

/-!
# Socket Bridge Axioms

Axioms asserting that POSIX socket syscalls conform to the
specifications in `SWELib.OS.Sockets`.

Each axiom represents an unproven trust assumption about the kernel.
-/

namespace SWELibBridge.Syscalls.Socket

open SWELib.OS

/-! ## socket(2) -/

-- TRUST: <issue-url>
/-- Linux `socket(2)` conforms to `SocketSystemState.socket`:
    allocates a new fd of kind `.socket` in phase `unbound`. -/
axiom socket_conforms (s : SocketSystemState) (family : AddressFamily)
    (sockType : SocketType) (newFd : Nat) :
    ∀ (linuxResult : Except Errno FileDescriptor),
    linuxResult = (s.socket family sockType newFd).2

/-! ## bind(2) -/

-- TRUST: <issue-url>
/-- Linux `bind(2)` conforms to `SocketSystemState.bind`:
    transitions unbound → bound, rejects EADDRINUSE / EINVAL. -/
axiom bind_conforms (s : SocketSystemState) (fd : FileDescriptor)
    (addr : SockAddr) :
    ∀ (linuxResult : Except Errno Unit),
    linuxResult = (s.bind fd addr).2

/-! ## listen(2) -/

-- TRUST: <issue-url>
/-- Linux `listen(2)` conforms to `SocketSystemState.listen`:
    transitions bound → listening for SOCK_STREAM. -/
axiom listen_conforms (s : SocketSystemState) (fd : FileDescriptor)
    (backlog : Nat) :
    ∀ (linuxResult : Except Errno Unit),
    linuxResult = (s.listen fd backlog).2

/-! ## accept(2) -/

-- TRUST: <issue-url>
/-- Linux `accept(2)` conforms to `SocketSystemState.accept`:
    dequeues a pending connection and returns a connected fd. -/
axiom accept_conforms (s : SocketSystemState) (fd : FileDescriptor)
    (newFd : Nat) :
    ∀ (linuxResult : Except Errno FileDescriptor),
    linuxResult = (s.accept fd newFd).2

/-! ## connect(2) -/

-- TRUST: <issue-url>
/-- Linux `connect(2)` conforms to `SocketSystemState.connect`:
    transitions to connected, rejects EISCONN. -/
axiom connect_conforms (s : SocketSystemState) (fd : FileDescriptor)
    (addr : SockAddr) :
    ∀ (linuxResult : Except Errno Unit),
    linuxResult = (s.connect fd addr).2

/-! ## send(2) -/

-- TRUST: <issue-url>
/-- Linux `send(2)` conforms to `SocketSystemState.send`:
    accepts bytes into the send buffer on a connected socket. -/
axiom send_conforms (s : SocketSystemState) (fd : FileDescriptor)
    (data : ByteArray) :
    ∀ (linuxResult : Except Errno Nat),
    linuxResult = (s.send fd data).2

/-! ## recv(2) -/

-- TRUST: <issue-url>
/-- Linux `recv(2)` conforms to `SocketSystemState.recv`:
    pops from the receive buffer FIFO on a connected socket. -/
axiom recv_conforms (s : SocketSystemState) (fd : FileDescriptor) :
    ∀ (linuxResult : Except Errno ByteArray),
    linuxResult = (s.recv fd).2

/-! ## shutdown(2) -/

-- TRUST: <issue-url>
/-- Linux `shutdown(2)` conforms to `SocketSystemState.shutdown`:
    transitions connected → shutdown. -/
axiom shutdown_conforms (s : SocketSystemState) (fd : FileDescriptor)
    (how : ShutdownHow) :
    ∀ (linuxResult : Except Errno Unit),
    linuxResult = (s.shutdown fd how).2

/-! ## close(2) -/

-- TRUST: <issue-url>
/-- Linux `close(2)` on a socket conforms to `SocketSystemState.close`:
    releases fd, removes socket entry and bound address. -/
axiom close_conforms (s : SocketSystemState) (fd : FileDescriptor) :
    ∀ (linuxResult : Except Errno Unit),
    linuxResult = (s.close fd).2

end SWELibBridge.Syscalls.Socket
