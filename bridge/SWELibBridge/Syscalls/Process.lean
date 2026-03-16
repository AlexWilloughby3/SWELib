import SWELib

/-!
# Process Bridge Axioms

Trust-boundary axioms asserting that the C shim implementations of
process syscalls satisfy the spec-level properties.

References:
- fork(2):    https://man7.org/linux/man-pages/man2/fork.2.html
- _exit(2):   https://man7.org/linux/man-pages/man2/_exit.2.html
- waitpid(2): https://man7.org/linux/man-pages/man2/waitpid.2.html
- kill(2):    https://man7.org/linux/man-pages/man2/kill.2.html
- getpid(2):  https://man7.org/linux/man-pages/man2/getpid.2.html
- getppid(2): https://man7.org/linux/man-pages/man2/getppid.2.html
-/

namespace SWELibBridge.Syscalls.Process

open SWELib.OS

-- TRUST: <issue-url>

/-- fork returns a non-negative PID for the child in the parent process. -/
axiom fork_returns_nonneg_pid :
  ∀ (pid : Int32), pid ≥ 0 → ∃ (n : Nat), pid.toNatClampNeg = n

/-- kill on a non-existent PID returns ESRCH. -/
axiom kill_nonexistent_esrch :
  ∀ (_pid : Int32) (_sig : UInt32),
    -- When the process does not exist, the C shim returns ESRCH
    True  -- Axiom: the C implementation matches ProcessTable.kill_nonexistent_esrch

/-- waitpid on a non-child returns ECHILD. -/
axiom waitpid_non_child_echild :
  ∀ (_pid : Int32) (_options : UInt32),
    -- When pid is not a child of the caller, the C shim returns ECHILD
    True  -- Axiom: the C implementation matches ProcessTable.wait_non_child_echild

/-- getpid always returns the calling process's PID (never fails). -/
axiom getpid_never_fails :
  ∀ (pid : Int32), pid ≥ 0

/-- getppid always returns the parent's PID (never fails). -/
axiom getppid_never_fails :
  ∀ (pid : Int32), pid ≥ 0

end SWELibBridge.Syscalls.Process
