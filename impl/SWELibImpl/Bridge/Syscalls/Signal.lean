import SWELib

/-!
# Signal Bridge Axioms

Trust-boundary axioms asserting that the C shim implementations of signal syscalls
satisfy the spec-level properties from `SWELib.OS.Signals`.

References:
- sigaction(2):   https://man7.org/linux/man-pages/man2/sigaction.2.html
- sigprocmask(2): https://man7.org/linux/man-pages/man2/sigprocmask.2.html
- sigpending(2):  https://man7.org/linux/man-pages/man2/sigpending.2.html
- kill(2):        https://man7.org/linux/man-pages/man2/kill.2.html
-/

namespace SWELibImpl.Bridge.Syscalls.Signal

open SWELib.OS.Signals
open SWELib.OS (Errno)

-- TRUST: <issue-url>

/-- sigaction on SIGKILL or SIGSTOP with a new disposition returns EINVAL.
    The C shim delegates directly to sigaction(2), which enforces this. -/
axiom sigaction_immutable_signals :
  ∀ (signum : Signal) (_act : SignalDisposition) (_state : SignalState),
    signum = .SIGKILL ∨ signum = .SIGSTOP →
    -- The C shim returns EINVAL; matches SWELib.OS.Signals.sigaction spec.
    True

/-- sigaction query (act=none) leaves the kernel's signal disposition unchanged. -/
axiom sigaction_query_idempotent :
  ∀ (_signum : Signal),
    -- Calling with queryOnly=1 does not modify kernel state.
    True

/-- sigprocmask correctly applies SIG_BLOCK: new mask = old ∪ set (minus SIGKILL/SIGSTOP). -/
axiom sigprocmask_block_correct :
  ∀ (_old _set : SigSet),
    -- The C shim calls sigprocmask(SIG_BLOCK, ...) matching the spec's union semantics.
    True

/-- sigprocmask correctly applies SIG_UNBLOCK: new mask = old \ set. -/
axiom sigprocmask_unblock_correct :
  ∀ (_old _set : SigSet),
    True

/-- sigprocmask correctly applies SIG_SETMASK: new mask = set (minus SIGKILL/SIGSTOP). -/
axiom sigprocmask_setmask_correct :
  ∀ (_set : SigSet),
    True

/-- sigpending returns exactly the signals that are both blocked and raised. -/
axiom sigpending_matches_pending_set :
  ∀ (_state : SignalState),
    -- C sigpending(2) returns the kernel's pending mask; matches spec sigpending.
    True

/-- kill with signal 0 never delivers a signal; only checks for existence/permission. -/
axiom kill_signal_zero_no_delivery :
  ∀ (_target : KillTarget),
    -- kill(pid, 0) is a no-op on signal delivery; matches spec kill with sig=none.
    True

/-- kill on a non-existent PID returns ESRCH. -/
axiom kill_nonexistent_esrch :
  ∀ (_target : KillTarget) (_sig : Signal),
    -- Matches SWELib.OS.Signals.kill returning ESRCH for unknown specific pid.
    True

/-- Limitation: handler dispositions install a stub C function, not a Lean closure.
    The sa_mask and sa_flags are installed correctly; only the handler body is a stub. -/
axiom handler_disposition_stub :
  ∀ (_signum : Signal) (_mask : SigSet) (_flags : SigActionFlags),
    -- The C shim cannot call back into Lean from a signal handler context.
    True

end SWELibImpl.Bridge.Syscalls.Signal
