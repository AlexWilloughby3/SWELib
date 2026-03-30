import SWELib
import SWELibImpl.Bridge
import SWELibImpl.Ffi.Syscalls

/-!
# SignalOps

Typed wrappers around raw signal syscalls.
Converts between spec types (Signal, SigSet, SignalDisposition, SigActionHow,
KillTarget) from `SWELib.OS.Signals` and the raw integers consumed by the C shims.

Wraps: sigaction(2), sigprocmask(2), sigpending(2), kill(2).
-/

namespace SWELibImpl.OS.SignalOps

open SWELib.OS.Signals
open SWELib.OS (Errno)

/-! ## Signal number encoding -/

/-- Encode a `Signal` as its Linux kernel signal number. -/
def signalToUInt32 (s : Signal) : UInt32 :=
  s.toNat.toUInt32

/-! ## Bitmask ↔ SigSet -/

/-- Encode a `SigSet` as a UInt64 bitmask: signal N maps to bit N-1. -/
def sigSetToMask (ss : SigSet) : UInt64 :=
  ss.foldl (fun acc s =>
    acc ||| ((1 : UInt64) <<< (s.toNat - 1).toUInt64)) 0

/-- Inverse mapping from a kernel signal number to a `Signal`. -/
private def signalOfNat : Nat → Option Signal
  | 1  => some .SIGHUP    | 2  => some .SIGINT    | 3  => some .SIGQUIT
  | 4  => some .SIGILL    | 5  => some .SIGTRAP   | 6  => some .SIGABRT
  | 7  => some .SIGBUS    | 8  => some .SIGFPE    | 9  => some .SIGKILL
  | 10 => some .SIGUSR1   | 11 => some .SIGSEGV   | 12 => some .SIGUSR2
  | 13 => some .SIGPIPE   | 14 => some .SIGALRM   | 15 => some .SIGTERM
  | 16 => some .SIGSTKFLT | 17 => some .SIGCHLD   | 18 => some .SIGCONT
  | 19 => some .SIGSTOP   | 20 => some .SIGTSTP   | 21 => some .SIGTTIN
  | 22 => some .SIGTTOU   | 23 => some .SIGURG    | 24 => some .SIGXCPU
  | 25 => some .SIGXFSZ   | 26 => some .SIGVTALRM | 27 => some .SIGPROF
  | 28 => some .SIGWINCH  | 29 => some .SIGIO     | 30 => some .SIGPWR
  | 31 => some .SIGSYS
  | n  =>
    if n >= 32 then
      let offset := n - 32
      if h : offset < 33 then some (.rt ⟨offset, h⟩) else none
    else
      none

/-- Decode a UInt64 bitmask to a `SigSet`: bit N-1 → signal N. -/
def maskToSigSet (mask : UInt64) : SigSet :=
  (List.range 64).filterMap fun i =>
    if mask &&& ((1 : UInt64) <<< i.toUInt64) != 0 then
      signalOfNat (i + 1)
    else
      none

/-! ## SigActionFlags encoding -/

/-- Encode `SigActionFlags` as Linux sa_flags bits. -/
def sigActionFlagsToUInt32 (f : SigActionFlags) : UInt32 :=
  (if f.nocldstop then 0x00000001 else 0) |||   -- SA_NOCLDSTOP
  (if f.nocldwait then 0x00000002 else 0) |||   -- SA_NOCLDWAIT
  (if f.siginfo   then 0x00000004 else 0) |||   -- SA_SIGINFO
  (if f.onstack   then 0x08000000 else 0) |||   -- SA_ONSTACK
  (if f.restart   then 0x10000000 else 0) |||   -- SA_RESTART
  (if f.nodefer   then 0x40000000 else 0) |||   -- SA_NODEFER
  (if f.resethand then 0x80000000 else 0)        -- SA_RESETHAND

/-- Decode Linux sa_flags bits into `SigActionFlags`. -/
def sigActionFlagsFromUInt32 (flags : UInt32) : SigActionFlags :=
  { nocldstop := flags &&& 0x00000001 != 0
    nocldwait := flags &&& 0x00000002 != 0
    siginfo   := flags &&& 0x00000004 != 0
    onstack   := flags &&& 0x08000000 != 0
    restart   := flags &&& 0x10000000 != 0
    nodefer   := flags &&& 0x40000000 != 0
    resethand := flags &&& 0x80000000 != 0 }

/-! ## SignalDisposition encoding -/

/-- Encode a `SignalDisposition` to (kind, mask, flags) for the C shim.
    kind: 0=SIG_DFL, 1=SIG_IGN, 2=stub handler. -/
def dispositionToRaw : SignalDisposition → UInt32 × UInt64 × UInt32
  | .default     => (0, 0, 0)
  | .ignore      => (1, 0, 0)
  | .handler m f => (2, sigSetToMask m, sigActionFlagsToUInt32 f)

/-- Decode (kind, mask, flags) from the C shim to a `SignalDisposition`. -/
def rawToDisposition (kind : UInt32) (mask : UInt64) (flags : UInt32) : SignalDisposition :=
  match kind with
  | 0 => .default
  | 1 => .ignore
  | _ => .handler (maskToSigSet mask) (sigActionFlagsFromUInt32 flags)

/-! ## SigActionHow encoding -/

/-- Encode `SigActionHow` as the POSIX SIG_BLOCK/SIG_UNBLOCK/SIG_SETMASK constant. -/
def sigActionHowToUInt32 : SigActionHow → UInt32
  | .block   => 0  -- SIG_BLOCK
  | .unblock => 1  -- SIG_UNBLOCK
  | .setmask => 2  -- SIG_SETMASK

/-! ## KillTarget encoding -/

/-- Encode a `KillTarget` as the raw `pid` argument to kill(2).
    Positive → specific PID; negative → process group; 0 → caller's group; -1 → all. -/
def killTargetToInt32 : KillTarget → Int32
  | .specific pid      => pid.toInt32
  | .processGroup pgid => (0 : Int32) - pgid.toInt32
  | .callerGroup        => (0 : Int32)
  | .allReachable       => (0 : Int32) - (1 : Int32)

/-! ## Operations -/

/-- `sigaction(2)`: examine and/or change the action for `signum`.
    - `act = none`: query only; disposition is unchanged.
    - `act = some .default | .ignore`: sets SIG_DFL / SIG_IGN.
    - `act = some (.handler m f)`: installs a stub C handler with the given
      additional mask and flags (Lean functions cannot be signal handlers).
    Returns the previous disposition, or EINVAL for SIGKILL/SIGSTOP with a new action. -/
def sigaction (signum : Signal) (act : Option SignalDisposition) :
    IO (Except Errno SignalDisposition) := do
  let (queryOnly, kind, mask, flags) : UInt32 × UInt32 × UInt64 × UInt32 :=
    match act with
    | none   => (1, 0, 0, 0)
    | some d =>
      let (k, m, f) := dispositionToRaw d
      (0, k, m, f)
  let result ← SWELibImpl.Ffi.Syscalls.sigaction_
    (signalToUInt32 signum) queryOnly kind mask flags
  return result.map fun (oldKind, oldMask, oldFlags) =>
    rawToDisposition oldKind oldMask oldFlags

/-- `sigprocmask(2)`: examine and/or change the calling thread's signal mask.
    - `set = none`: query only; mask is unchanged.
    - Otherwise: applies `how` to compute the new blocked set.
    Returns the previous blocked signal set.
    SIGKILL and SIGSTOP are silently excluded by the kernel. -/
def sigprocmask (how : SigActionHow) (set : Option SigSet) :
    IO (Except Errno SigSet) := do
  let (queryOnly, newMask) : UInt32 × UInt64 :=
    match set with
    | none   => (1, 0)
    | some s => (0, sigSetToMask s)
  let result ← SWELibImpl.Ffi.Syscalls.sigprocmask_
    (sigActionHowToUInt32 how) queryOnly newMask
  return result.map maskToSigSet

/-- `sigpending(2)`: return the set of signals pending for the calling thread. -/
def sigpending : IO (Except Errno SigSet) := do
  let result ← SWELibImpl.Ffi.Syscalls.sigpending_
  return result.map maskToSigSet

/-- `kill(2)`: send a signal to a process or group.
    - `sig = none`: signal 0 — existence/permission check only, no signal delivered.
    - `target = .specific pid`: send to that PID.
    - `target = .processGroup pgid`: send to all processes in the group (kill(-pgid, sig)).
    - `target = .callerGroup`: send to all processes in the caller's group (kill(0, sig)).
    - `target = .allReachable`: send to all reachable processes except PID 1 (kill(-1, sig)). -/
def sendSignal (target : KillTarget) (sig : Option Signal) :
    IO (Except Errno Unit) :=
  let rawPid := killTargetToInt32 target
  let rawSig : UInt32 := match sig with
    | none   => 0
    | some s => signalToUInt32 s
  SWELibImpl.Ffi.Syscalls.kill rawPid rawSig

end SWELibImpl.OS.SignalOps
