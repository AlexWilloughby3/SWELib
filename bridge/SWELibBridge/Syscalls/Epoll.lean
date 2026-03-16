import SWELib

/-!
# Epoll Bridge Axioms

Axioms asserting that Linux epoll syscalls conform to the
specifications in `SWELib.OS.Epoll`.

Each axiom represents an unproven trust assumption about the kernel.
-/

namespace SWELibBridge.Syscalls.Epoll

open SWELib.OS

-- TRUST: <issue-url>
/-- Linux `epoll_create1(2)` conforms to `EpollSystemState.epollCreate`:
    allocates an epoll fd with an empty interest list. -/
axiom epoll_create_conforms (s : EpollSystemState) (newFd : Nat) :
    ∀ (linuxResult : Except Errno FileDescriptor),
    linuxResult = (s.epollCreate newFd).2

-- TRUST: <issue-url>
/-- Linux `epoll_ctl(2)` conforms to `EpollSystemState.epollCtl`:
    ADD/MOD/DEL on the interest list with correct error semantics. -/
axiom epoll_ctl_conforms (s : EpollSystemState) (epfd : FileDescriptor)
    (op : EpollCtlOp) (targetFd : Nat) (events : EpollEvents) :
    ∀ (linuxResult : Except Errno Unit),
    linuxResult = (s.epollCtl epfd op targetFd events).2

-- TRUST: <issue-url>
/-- Linux `epoll_wait(2)` conforms to `EpollSystemState.epollWait`:
    returns up to maxEvents ready fds using level-triggered semantics. -/
axiom epoll_wait_conforms (s : EpollSystemState) (epfd : FileDescriptor)
    (maxEvents : Nat) :
    ∀ (linuxResult : Except Errno (List EpollEvent)),
    linuxResult = s.epollWait epfd maxEvents

end SWELibBridge.Syscalls.Epoll
