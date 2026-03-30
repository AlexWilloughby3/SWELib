import SWELib.OS.Sockets

/-!
# Epoll

Level-triggered epoll specification: `epoll_create`, `epoll_ctl`, `epoll_wait`.

Epoll wraps `SocketSystemState` — sockets don't know about epoll, but
epoll observes socket buffer state to determine readiness.

References:
- epoll_create(2): https://man7.org/linux/man-pages/man2/epoll_create.2.html
- epoll_ctl(2):    https://man7.org/linux/man-pages/man2/epoll_ctl.2.html
- epoll_wait(2):   https://man7.org/linux/man-pages/man2/epoll_wait.2.html
-/

namespace SWELib.OS

private theorem take_eq_self_of_length_le {α : Type} (xs : List α) (n : Nat)
    (h : xs.length ≤ n) : xs.take n = xs := by
  induction xs generalizing n with
  | nil => simp
  | cons x xs ih =>
      cases n with
      | zero => cases h
      | succ n =>
          simp at h ⊢
          exact ih n h

/-! ## Types -/

/-- Events of interest / readiness for an epoll fd. -/
structure EpollEvents where
  epollin  : Bool := false
  epollout : Bool := false
  epollerr : Bool := false
  epollhup : Bool := false
  deriving DecidableEq, Repr

/-- epoll_ctl operations. -/
inductive EpollCtlOp where
  | ADD
  | MOD
  | DEL
  deriving DecidableEq, Repr

/-- An interest registration: which fd and what events to watch. -/
structure EpollInterest where
  fd : Nat
  events : EpollEvents
  deriving DecidableEq, Repr

/-- An epoll instance: its list of interest registrations. -/
structure EpollInstance where
  interests : List EpollInterest
  deriving Repr

/-- An event returned by epoll_wait: which fd is ready and for what. -/
structure EpollEvent where
  fd : Nat
  events : EpollEvents
  deriving Repr

/-! ## System state -/

/-- Complete system state with epoll layered on top of sockets. -/
structure EpollSystemState where
  /-- Underlying socket system state. -/
  sockState : SocketSystemState
  /-- Map from epoll fd number to epoll instance. -/
  epollInstances : Nat → Option EpollInstance

/-- Empty epoll system state. -/
def EpollSystemState.empty : EpollSystemState :=
  { sockState := SocketSystemState.empty
    epollInstances := fun _ => none }

/-! ## epoll_create(2) -/

/-- `epoll_create(2)`: create a new epoll instance.
    `newFd` models the kernel's fd allocation. -/
def EpollSystemState.epollCreate (s : EpollSystemState) (newFd : Nat) :
    EpollSystemState × Except Errno FileDescriptor :=
  match s.sockState.fdTable newFd with
  | some (.open _) => (s, .error .EMFILE)
  | _ =>
    let s' : EpollSystemState :=
      { s with
        sockState.fdTable := s.sockState.fdTable.update newFd (.open .epoll)
        epollInstances := fun n =>
          if n = newFd then some { interests := [] } else s.epollInstances n }
    (s', .ok ⟨newFd⟩)

/-! ## epoll_ctl(2) -/

/-- `epoll_ctl(2)`: add, modify, or delete an interest on an epoll instance. -/
def EpollSystemState.epollCtl (s : EpollSystemState)
    (epfd : FileDescriptor) (op : EpollCtlOp) (targetFd : Nat)
    (events : EpollEvents) :
    EpollSystemState × Except Errno Unit :=
  match s.epollInstances epfd.fd with
  | none => (s, .error .EBADF)
  | some inst =>
    -- Target fd must be open
    if !s.sockState.fdTable.isOpen ⟨targetFd⟩ then (s, .error .EBADF)
    else
      let alreadyRegistered := inst.interests.any (·.fd == targetFd)
      match op with
      | .ADD =>
        if alreadyRegistered then (s, .error .EEXIST)
        else
          let interest : EpollInterest := { fd := targetFd, events }
          let inst' := { inst with interests := interest :: inst.interests }
          let s' := { s with
            epollInstances := fun n =>
              if n = epfd.fd then some inst' else s.epollInstances n }
          (s', .ok ())
      | .MOD =>
        if !alreadyRegistered then (s, .error .ENOENT)
        else
          let interests' := inst.interests.map fun i =>
            if i.fd == targetFd then { i with events } else i
          let inst' := { inst with interests := interests' }
          let s' := { s with
            epollInstances := fun n =>
              if n = epfd.fd then some inst' else s.epollInstances n }
          (s', .ok ())
      | .DEL =>
        if !alreadyRegistered then (s, .error .ENOENT)
        else
          let interests' := inst.interests.filter (·.fd != targetFd)
          let inst' := { inst with interests := interests' }
          let s' := { s with
            epollInstances := fun n =>
              if n = epfd.fd then some inst' else s.epollInstances n }
          (s', .ok ())

/-! ## Readiness -/

/-- Check whether a socket is ready for the requested events.
    Level-triggered: EPOLLIN ready ↔ recvBuf non-empty,
    EPOLLOUT ready ↔ sendBuf has space. -/
def isReady (sockState : SocketSystemState) (interest : EpollInterest) : EpollEvents :=
  match sockState.sockets interest.fd with
  | none => { epollerr := true }
  | some entry =>
    { epollin  := interest.events.epollin && !entry.recvBuf.isEmpty
      epollout := interest.events.epollout &&
        (entry.sendBufUsed < entry.sendBufCapacity)
      epollerr := false
      epollhup := entry.phase == .shutdown }

/-- Whether an EpollEvents has any active flag. -/
def EpollEvents.any (e : EpollEvents) : Bool :=
  e.epollin || e.epollout || e.epollerr || e.epollhup

/-! ## epoll_wait(2) -/

/-- `epoll_wait(2)`: return up to `maxEvents` ready fds.
    Level-triggered: reports all currently-ready interests. -/
def EpollSystemState.epollWait (s : EpollSystemState)
    (epfd : FileDescriptor) (maxEvents : Nat) :
    Except Errno (List EpollEvent) :=
  match s.epollInstances epfd.fd with
  | none => .error .EBADF
  | some inst =>
    if maxEvents == 0 then .error .EINVAL
    else
      let ready := inst.interests.filterMap fun interest =>
        let evts := isReady s.sockState interest
        if evts.any then some { fd := interest.fd, events := evts : EpollEvent }
        else none
      .ok (ready.take maxEvents)

/-! ## close -/

/-- Close an epoll fd: removes the epoll instance. -/
def EpollSystemState.closeEpoll (s : EpollSystemState)
    (fd : FileDescriptor) :
    EpollSystemState × Except Errno Unit :=
  let (fdTable', result) := s.sockState.fdTable.close fd
  match result with
  | .ok () =>
    let s' : EpollSystemState :=
      { s with
        sockState.fdTable := fdTable'
        epollInstances := fun n =>
          if n = fd.fd then none else s.epollInstances n }
    (s', .ok ())
  | .error e => (s, .error e)

/-- Close a socket fd: delegates to socket close and auto-removes the fd
    from all epoll interest lists. -/
def EpollSystemState.closeSocket (s : EpollSystemState)
    (fd : FileDescriptor) :
    EpollSystemState × Except Errno Unit :=
  let (sockState', result) := s.sockState.close fd
  match result with
  | .ok () =>
    -- Remove fd from all epoll interest lists
    let epollInstances' : Nat → Option EpollInstance := fun n =>
      match s.epollInstances n with
      | none => none
      | some inst =>
        some { interests := inst.interests.filter (·.fd != fd.fd) }
    let s' : EpollSystemState :=
      { sockState := sockState'
        epollInstances := epollInstances' }
    (s', .ok ())
  | .error e => (s, .error e)

/-! ## Theorems -/

/-- DEL removes the fd from the interest list. -/
theorem epollCtl_del_removes (s : EpollSystemState)
    (epfd : FileDescriptor) (targetFd : Nat) (events : EpollEvents)
    (inst : EpollInstance)
    (h_inst : s.epollInstances epfd.fd = some inst)
    (h_open : s.sockState.fdTable.isOpen ⟨targetFd⟩ = true)
    (h_reg : inst.interests.any (·.fd == targetFd) = true) :
    let (s', _) := s.epollCtl epfd .DEL targetFd events
    ∀ inst', s'.epollInstances epfd.fd = some inst' →
    inst'.interests.any (·.fd == targetFd) = false := by
  simp [EpollSystemState.epollCtl, h_inst, h_open, h_reg]

/-- A DEL'd fd never appears in subsequent epoll_wait results. -/
theorem epollWait_after_del (s : EpollSystemState)
    (epfd : FileDescriptor) (targetFd : Nat) (events : EpollEvents)
    (maxEvents : Nat) (h_max : maxEvents > 0)
    (inst : EpollInstance)
    (h_inst : s.epollInstances epfd.fd = some inst)
    (h_open : s.sockState.fdTable.isOpen ⟨targetFd⟩ = true)
    (h_reg : inst.interests.any (·.fd == targetFd) = true) :
    let (s', _) := s.epollCtl epfd .DEL targetFd events
    ∀ results, s'.epollWait epfd maxEvents = .ok results →
    results.all (·.fd != targetFd) = true := by
  simp [EpollSystemState.epollCtl, h_inst, h_open, h_reg]
  intro results h_wait
  have h_ne0 : maxEvents ≠ 0 := Nat.ne_of_gt h_max
  simp [EpollSystemState.epollWait, h_ne0] at h_wait
  subst h_wait
  intro x hx
  have hx' := List.mem_of_mem_take hx
  simp only [List.mem_filterMap] at hx'
  rcases hx' with ⟨interest, h_interest, h_map⟩
  have h_interest' : interest ∈ List.filter (fun x => x.fd != targetFd) inst.interests := h_interest
  simp only [List.mem_filter] at h_interest'
  have h_keep : interest.fd ≠ targetFd := by
    simpa using h_interest'.2
  by_cases h_ready : (isReady s.sockState interest).any = true
  · simp [h_ready] at h_map
    subst h_map
    simpa using h_keep
  · simp [h_ready] at h_map

/-- EPOLLIN registered + recvBuf non-empty → fd appears in wait results. -/
-- NOTE: epollWait_ready_when_data requires maxEvents ≥ inst.interests.length to avoid
-- truncation cutting off targetFd. With h_max_large the take becomes identity.
theorem epollWait_ready_when_data (s : EpollSystemState)
    (epfd : FileDescriptor) (targetFd : Nat) (maxEvents : Nat)
    (inst : EpollInstance) (entry : SocketEntry)
    (h_inst : s.epollInstances epfd.fd = some inst)
    (h_max : maxEvents > 0)
    (h_max_large : inst.interests.length ≤ maxEvents)
    (h_interest : inst.interests.any
      (fun i => i.fd == targetFd && i.events.epollin) = true)
    (h_sock : s.sockState.sockets targetFd = some entry)
    (h_data : entry.recvBuf ≠ []) :
    ∀ results, s.epollWait epfd maxEvents = .ok results →
    results.any (·.fd == targetFd) = true := by
  intro results h_wait
  have h_ne0 : maxEvents ≠ 0 := Nat.ne_of_gt h_max
  simp [EpollSystemState.epollWait, h_inst, h_ne0] at h_wait
  have h_mem : ∃ interest ∈ inst.interests, interest.fd = targetFd ∧ interest.events.epollin = true := by
    simpa using h_interest
  rcases h_mem with ⟨interest, h_interest_mem, h_fd, h_in⟩
  have h_recv : entry.recvBuf.isEmpty = false := by
    cases h_buf : entry.recvBuf with
    | nil => contradiction
    | cons _ _ => simp
  have h_ready_any : (isReady s.sockState interest).any = true := by
    simp [isReady, EpollEvents.any, h_sock, h_fd, h_in, h_recv]
  have h_event_mem : { fd := interest.fd, events := isReady s.sockState interest : EpollEvent } ∈
      List.filterMap
        (fun interest =>
          if (isReady s.sockState interest).any = true then
            some { fd := interest.fd, events := isReady s.sockState interest : EpollEvent }
          else none)
        inst.interests := by
    simp only [List.mem_filterMap]
    refine ⟨interest, h_interest_mem, ?_⟩
    simp [h_ready_any]
  have h_len_ready :
      (List.filterMap
        (fun interest =>
          if (isReady s.sockState interest).any = true then
            some { fd := interest.fd, events := isReady s.sockState interest : EpollEvent }
          else none)
        inst.interests).length ≤ maxEvents := by
    exact Nat.le_trans (List.length_filterMap_le _ _) h_max_large
  have h_take :
      List.take maxEvents
        (List.filterMap
          (fun interest =>
            if (isReady s.sockState interest).any = true then
              some { fd := interest.fd, events := isReady s.sockState interest : EpollEvent }
            else none)
          inst.interests) =
      List.filterMap
        (fun interest =>
          if (isReady s.sockState interest).any = true then
            some { fd := interest.fd, events := isReady s.sockState interest : EpollEvent }
          else none)
        inst.interests :=
    take_eq_self_of_length_le _ _ h_len_ready
  subst h_wait
  rw [h_take]
  rw [List.any_eq_true]
  refine ⟨{ fd := interest.fd, events := isReady s.sockState interest }, h_event_mem, ?_⟩
  simp [h_fd]

/-- epoll_create produces an fd of kind `.epoll`. -/
theorem epollCreate_is_epoll_kind (s : EpollSystemState) (newFd : Nat)
    (_h_free : s.sockState.fdTable newFd ≠ some (.open .file) ∧
              s.sockState.fdTable newFd ≠ some (.open .socket) ∧
              s.sockState.fdTable newFd ≠ some (.open .pipe) ∧
              s.sockState.fdTable newFd ≠ some (.open .epoll)) :
    ∀ fd', (s.epollCreate newFd).2 = .ok fd' →
    (s.epollCreate newFd).1.sockState.fdTable newFd = some (.open .epoll) := by
  intro fd' h_ok
  simp [EpollSystemState.epollCreate] at h_ok ⊢
  split at h_ok
  · contradiction
  · simp [FdTable.update]

/-- Closing a socket fd removes it from all epoll interest lists. -/
theorem close_auto_removes_from_epoll (s : EpollSystemState)
    (fd : FileDescriptor) (k : FdKind)
    (h_open : s.sockState.fdTable fd.fd = some (.open k))
    (epollFd : Nat) (inst : EpollInstance)
    (h_inst : s.epollInstances epollFd = some inst) :
    ∀ inst', (s.closeSocket fd).1.epollInstances epollFd = some inst' →
    inst'.interests.all (·.fd != fd.fd) = true := by
  intro inst' h_inst'
  simp [EpollSystemState.closeSocket, SocketSystemState.close,
        FdTable.close, h_open, h_inst] at h_inst'
  subst h_inst'
  simp [List.all_filter]

end SWELib.OS
