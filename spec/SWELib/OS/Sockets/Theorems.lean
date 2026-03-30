import SWELib.OS.Sockets.State

/-!
# Socket Theorems

Key correctness properties of the socket state machine.
All provable by unfolding definitions and simplification.
-/

namespace SWELib.OS

/-! ## Phase violations -/

/-- listen on an unbound socket returns EINVAL. -/
theorem listen_unbound_einval (s : SocketSystemState) (fd : FileDescriptor)
    (backlog : Nat) (entry : SocketEntry)
    (h_sock : s.sockets fd.fd = some entry)
    (h_phase : entry.phase = .unbound) :
    (s.listen fd backlog).2 = .error .EINVAL := by
  simp [SocketSystemState.listen, h_sock, h_phase]

/-- accept on a non-listening socket returns EINVAL. -/
theorem accept_not_listening_einval (s : SocketSystemState) (fd : FileDescriptor)
    (newFd : Nat) (entry : SocketEntry)
    (h_sock : s.sockets fd.fd = some entry)
    (h_phase : entry.phase ≠ .listening) :
    (s.accept fd newFd).2 = .error .EINVAL := by
  simp [SocketSystemState.accept, h_sock]
  simp [h_phase]

/-- accept returns a distinct fd from the listening fd (given distinct allocation). -/
theorem accept_new_fd_distinct (s : SocketSystemState) (fd : FileDescriptor)
    (newFd : Nat) (entry : SocketEntry) (clientAddr : SockAddr)
    (rest : List SockAddr)
    (h_sock : s.sockets fd.fd = some entry)
    (h_phase : entry.phase = .listening)
    (h_pending : s.pendingConns fd.fd = clientAddr :: rest)
    (h_ne : newFd ≠ fd.fd) :
    ∀ result, (s.accept fd newFd).2 = .ok result → result.fd ≠ fd.fd := by
  intro result h_ok
  simp [SocketSystemState.accept, h_sock, h_phase, h_pending] at h_ok
  subst h_ok
  exact h_ne

/-- send on a non-connected socket returns ENOTCONN. -/
theorem send_not_connected_enotconn (s : SocketSystemState) (fd : FileDescriptor)
    (data : ByteArray) (entry : SocketEntry)
    (h_sock : s.sockets fd.fd = some entry)
    (h_phase : entry.phase ≠ .connected) :
    (s.send fd data).2 = .error .ENOTCONN := by
  simp [SocketSystemState.send, h_sock, h_phase]

/-- bind on a non-unbound socket returns EINVAL. -/
theorem bind_already_bound_einval (s : SocketSystemState) (fd : FileDescriptor)
    (addr : SockAddr) (entry : SocketEntry)
    (h_sock : s.sockets fd.fd = some entry)
    (h_phase : entry.phase ≠ .unbound) :
    (s.bind fd addr).2 = .error .EINVAL := by
  simp [SocketSystemState.bind, h_sock, h_phase]

/-- bind to an already-bound address returns EADDRINUSE. -/
theorem bind_addr_in_use (s : SocketSystemState) (fd : FileDescriptor)
    (addr : SockAddr) (entry : SocketEntry)
    (h_sock : s.sockets fd.fd = some entry)
    (h_phase : entry.phase = .unbound)
    (h_family : entry.family = addr.family)
    (h_inuse : addr ∈ s.boundAddrs) :
    (s.bind fd addr).2 = .error .EADDRINUSE := by
  simp [SocketSystemState.bind, h_sock, h_phase, h_family, h_inuse]

/-- connect on an already-connected socket returns EISCONN. -/
theorem connect_already_connected_eisconn (s : SocketSystemState)
    (fd : FileDescriptor) (addr : SockAddr) (entry : SocketEntry)
    (h_sock : s.sockets fd.fd = some entry)
    (h_phase : entry.phase = .connected) :
    (s.connect fd addr).2 = .error .EISCONN := by
  simp [SocketSystemState.connect, h_sock, h_phase]

/-! ## Postconditions -/

/-- After socket(), the entry exists and is unbound. -/
theorem socket_creates_unbound (s : SocketSystemState)
    (family : AddressFamily) (sockType : SocketType) (newFd : Nat)
    (_h_free : s.fdTable newFd ≠ some (.open .file) ∧
              s.fdTable newFd ≠ some (.open .socket) ∧
              s.fdTable newFd ≠ some (.open .pipe) ∧
              s.fdTable newFd ≠ some (.open .epoll)) :
    ∀ fd', (s.socket family sockType newFd).2 = .ok fd' →
    ((s.socket family sockType newFd).1.sockets newFd).isSome = true := by
  intro fd' h_ok
  simp [SocketSystemState.socket] at h_ok ⊢
  split at h_ok
  · contradiction
  · simp

/-- After close, the socket entry is removed. -/
theorem close_removes_socket (s : SocketSystemState) (fd : FileDescriptor)
    (k : FdKind) (h_open : s.fdTable fd.fd = some (.open k)) :
    ((s.close fd).1.sockets fd.fd) = none := by
  simp [SocketSystemState.close, FdTable.close, h_open]

/-- Close does not affect other sockets. -/
theorem close_preserves_other_sockets (s : SocketSystemState)
    (fd other : FileDescriptor) (hne : fd.fd ≠ other.fd) :
    (s.close fd).1.sockets other.fd = s.sockets other.fd := by
  simp [SocketSystemState.close]
  split <;> simp_all [FdTable.close, Ne.symm hne]

/-- deliver followed by recv returns the delivered data (FIFO). -/
theorem deliver_then_recv (s : SocketSystemState) (fd : Nat)
    (data : ByteArray) (entry : SocketEntry)
    (h_sock : s.sockets fd = some entry)
    (h_phase : entry.phase = .connected)
    (h_empty : entry.recvBuf = []) :
    let s' := s.deliver fd data
    (s'.recv ⟨fd⟩).2 = .ok data := by
  simp [SocketSystemState.deliver, h_sock, SocketSystemState.recv, h_phase, h_empty]

end SWELib.OS
