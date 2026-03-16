import SWELib.OS.Signals.Types

/-!
# Signals -- Operations

sigaction, sigprocmask, sigpending, kill.

References:
- kill(2):        https://man7.org/linux/man-pages/man2/kill.2.html
- sigaction(2):   https://man7.org/linux/man-pages/man2/sigaction.2.html
- sigprocmask(2): https://man7.org/linux/man-pages/man2/sigprocmask.2.html
- sigpending(2):  https://man7.org/linux/man-pages/man2/sigpending.2.html
-/

namespace SWELib.OS.Signals

/-! ## sigaction(2) -/

/-- `sigaction(2)`: examine and/or change a signal action.
    - `act = none`: query only; state is unchanged.
    - `signum in {SIGKILL, SIGSTOP}` with `act = some _`: returns EINVAL.
    - Otherwise: installs the new disposition and returns the old one. -/
def sigaction (signum : Signal) (act : Option SignalDisposition) (state : SignalState) :
    SignalState × Except SWELib.OS.Errno SignalDisposition :=
  let old := state.dispositions signum
  match act with
  | none => (state, .ok old)
  | some d =>
    if signum == .SIGKILL || signum == .SIGSTOP then
      (state, .error .EINVAL)
    else
      let newDisps : Signal -> SignalDisposition :=
        fun s => if s == signum then d else state.dispositions s
      ({ state with dispositions := newDisps }, .ok old)

/-! ## sigprocmask(2) -/

/-- `sigprocmask(2)`: examine and/or change the signal mask.
    - `set = none`: query only; returns current blocked set.
    - Otherwise: applies `how` to compute the new blocked set (SIGKILL/SIGSTOP silently excluded). -/
def sigprocmask (how : SigActionHow) (set : Option SigSet) (state : SignalState) :
    SignalState × Except SWELib.OS.Errno SigSet :=
  let old := state.blocked
  match set with
  | none => (state, .ok old)
  | some s =>
    let newBlocked :=
      match how with
      | .block   => effectiveMask (SigSet.union state.blocked s)
      | .unblock => SigSet.sdiff state.blocked s
      | .setmask => effectiveMask s
    ({ state with blocked := newBlocked }, .ok old)

/-! ## sigpending(2) -/

/-- `sigpending(2)`: return the set of signals pending for delivery.
    Always succeeds; the pending set is the set of blocked+raised signals. -/
def sigpending (state : SignalState) : Except SWELib.OS.Errno SigSet :=
  .ok state.pending

/-! ## ProcessTable for signals -/

/-- A signal-oriented process table: maps PIDs to per-process signal state. -/
def SignalTable := Nat -> Option SignalState

/-- Update a single entry. -/
def SignalTable.update (t : SignalTable) (pid : Nat) (s : SignalState) : SignalTable :=
  fun n => if n = pid then some s else t n

/-- Deliver a signal to a process:
    - If blocked and not ignored: add to pending.
    - If not blocked and not ignored: delivered immediately (no pending change in this model).
    - If ignored: discard silently. -/
def deliverSignal (sig : Signal) (state : SignalState) : SignalState :=
  if SigSet.member sig state.blocked then
    match state.dispositions sig with
    | .ignore => state
    | _       => { state with pending := SigSet.insert sig state.pending }
  else
    state

/-! ## kill(2) -/

/-- `kill(2)`: send a signal to one or more processes.
    - `sig = none` (signal 0): existence/permission check only; no state change.
    - `target = .specific pid`: deliver to that process, or return ESRCH if unknown.
    - Other targets: stub (multi-process iteration requires a finite PID list). -/
def kill (target : KillTarget) (sig : Option Signal) (_callerPid : Nat)
    (t : SignalTable) : SignalTable × Except SWELib.OS.Errno Unit :=
  match sig with
  | none => (t, .ok ())
  | some s =>
    match target with
    | .specific pid =>
      match t pid with
      | none     => (t, .error .ESRCH)
      | some st  => (SignalTable.update t pid (deliverSignal s st), .ok ())
    | _ => (t, .ok ())

end SWELib.OS.Signals
