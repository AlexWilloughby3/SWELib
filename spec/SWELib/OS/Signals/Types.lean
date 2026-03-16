import SWELib.OS.Io

/-!
# Signals -- Types

Signal numbers, dispositions, signal sets, and state.

References:
- signal(7):      https://man7.org/linux/man-pages/man7/signal.7.html
- sigaction(2):   https://man7.org/linux/man-pages/man2/sigaction.2.html
- sigprocmask(2): https://man7.org/linux/man-pages/man2/sigprocmask.2.html
-/

namespace SWELib.OS.Signals

/-! ## Signal numbers -/

/-- Full POSIX signal set for Linux x86/ARM. -/
inductive Signal where
  | SIGHUP    -- 1  Hangup
  | SIGINT    -- 2  Interrupt (Ctrl-C)
  | SIGQUIT   -- 3  Quit
  | SIGILL    -- 4  Illegal instruction
  | SIGTRAP   -- 5  Trace trap
  | SIGABRT   -- 6  Abort
  | SIGBUS    -- 7  Bus error
  | SIGFPE    -- 8  Floating-point exception
  | SIGKILL   -- 9  Kill (unblockable)
  | SIGUSR1   -- 10 User-defined signal 1
  | SIGSEGV   -- 11 Segmentation fault
  | SIGUSR2   -- 12 User-defined signal 2
  | SIGPIPE   -- 13 Broken pipe
  | SIGALRM   -- 14 Alarm clock
  | SIGTERM   -- 15 Termination
  | SIGSTKFLT  -- 16 Stack fault on coprocessor (unused/obsolete)
  | SIGCHLD   -- 17 Child status change
  | SIGCONT   -- 18 Continue
  | SIGSTOP   -- 19 Stop (unblockable)
  | SIGTSTP   -- 20 Keyboard stop
  | SIGTTIN   -- 21 Background read from tty
  | SIGTTOU   -- 22 Background write to tty
  | SIGURG    -- 23 Urgent condition on socket
  | SIGXCPU   -- 24 CPU time limit exceeded
  | SIGXFSZ   -- 25 File size limit exceeded
  | SIGVTALRM -- 26 Virtual timer alarm
  | SIGPROF   -- 27 Profiling timer alarm
  | SIGWINCH  -- 28 Window resize
  | SIGIO     -- 29 I/O now possible
  | SIGPWR    -- 30 Power failure
  | SIGSYS    -- 31 Bad system call
  | rt (n : Fin 33)  -- Real-time signals SIGRTMIN+n (kernel numbers 32..64)
  deriving DecidableEq, Repr

instance : BEq Signal := instBEqOfDecidableEq

/-- Kernel signal number. -/
def Signal.toNat : Signal -> Nat
  | .SIGHUP    => 1
  | .SIGINT    => 2
  | .SIGQUIT   => 3
  | .SIGILL    => 4
  | .SIGTRAP   => 5
  | .SIGABRT   => 6
  | .SIGBUS    => 7
  | .SIGFPE    => 8
  | .SIGKILL   => 9
  | .SIGUSR1   => 10
  | .SIGSEGV   => 11
  | .SIGUSR2   => 12
  | .SIGPIPE   => 13
  | .SIGALRM   => 14
  | .SIGTERM   => 15
  | .SIGSTKFLT => 16
  | .SIGCHLD   => 17
  | .SIGCONT   => 18
  | .SIGSTOP   => 19
  | .SIGTSTP   => 20
  | .SIGTTIN   => 21
  | .SIGTTOU   => 22
  | .SIGURG    => 23
  | .SIGXCPU   => 24
  | .SIGXFSZ   => 25
  | .SIGVTALRM => 26
  | .SIGPROF   => 27
  | .SIGWINCH  => 28
  | .SIGIO     => 29
  | .SIGPWR    => 30
  | .SIGSYS    => 31
  | .rt n      => 32 + n.val

/-! ## Default disposition -/

/-- The five standard default signal behaviors from signal(7). -/
inductive DefaultDisposition where
  /-- Terminate the process. -/
  | term
  /-- Ignore the signal. -/
  | ign
  /-- Terminate and produce a core dump. -/
  | core
  /-- Suspend the process. -/
  | stop
  /-- Resume a stopped process. -/
  | cont
  deriving DecidableEq, Repr

/-- Default disposition for each signal per signal(7). -/
def Signal.defaultDisposition : Signal -> DefaultDisposition
  | .SIGHUP    => .term
  | .SIGINT    => .term
  | .SIGQUIT   => .core
  | .SIGILL    => .core
  | .SIGTRAP   => .core
  | .SIGABRT   => .core
  | .SIGBUS    => .core
  | .SIGFPE    => .core
  | .SIGKILL   => .term
  | .SIGUSR1   => .term
  | .SIGSEGV   => .core
  | .SIGUSR2   => .term
  | .SIGPIPE   => .term
  | .SIGALRM   => .term
  | .SIGTERM   => .term
  | .SIGSTKFLT => .term
  | .SIGCHLD   => .ign
  | .SIGCONT   => .cont
  | .SIGSTOP   => .stop
  | .SIGTSTP   => .stop
  | .SIGTTIN   => .stop
  | .SIGTTOU   => .stop
  | .SIGURG    => .ign
  | .SIGXCPU   => .core
  | .SIGXFSZ   => .core
  | .SIGVTALRM => .term
  | .SIGPROF   => .term
  | .SIGWINCH  => .ign
  | .SIGIO     => .term
  | .SIGPWR    => .term
  | .SIGSYS    => .core
  | .rt _      => .term

/-! ## SigSet -/

/-- A set of signals, represented as a list.
    SIGKILL and SIGSTOP are never effectively in the blocked set;
    this is enforced operationally via `effectiveMask`. -/
def SigSet := List Signal

instance : Inhabited SigSet := inferInstanceAs (Inhabited (List Signal))
instance : Repr SigSet := inferInstanceAs (Repr (List Signal))

/-- The empty signal set. -/
def SigSet.empty : SigSet := []

/-- Test membership. -/
def SigSet.member (s : Signal) (ss : SigSet) : Bool :=
  ss.any (s == .)

/-- Insert a signal (no-op if already present). -/
def SigSet.insert (s : Signal) (ss : SigSet) : SigSet :=
  if SigSet.member s ss then ss else s :: ss

/-- Remove a signal from a set. -/
def SigSet.remove (s : Signal) (ss : SigSet) : SigSet :=
  ss.filter (s != .)

/-- Union of two signal sets. -/
def SigSet.union (a b : SigSet) : SigSet :=
  b.foldl (fun acc s => SigSet.insert s acc) a

/-- Set difference: signals in a but not in b. -/
def SigSet.sdiff (a b : SigSet) : SigSet :=
  a.filter (fun s => !SigSet.member s b)

/-- Strip SIGKILL and SIGSTOP from a mask (kernel silently ignores attempts to block them). -/
def effectiveMask (ss : SigSet) : SigSet :=
  ss.filter (fun s => s != .SIGKILL && s != .SIGSTOP)

/-! ## SigActionFlags -/

/-- Flags that modify signal handler behavior (from sigaction(2) sa_flags). -/
structure SigActionFlags where
  /-- Do not generate SIGCHLD when children stop or resume. -/
  nocldstop : Bool := false
  /-- Do not create zombie children on wait. -/
  nocldwait : Bool := false
  /-- Do not block the signal during its own handler (SA_NODEFER). -/
  nodefer   : Bool := false
  /-- Execute handler on alternate signal stack (SA_ONSTACK). -/
  onstack   : Bool := false
  /-- Reset disposition to default on handler entry (SA_RESETHAND). -/
  resethand : Bool := false
  /-- Restart interrupted system calls (SA_RESTART). -/
  restart   : Bool := false
  /-- Pass extended siginfo_t to handler (SA_SIGINFO). -/
  siginfo   : Bool := false
  deriving DecidableEq, Repr

/-- Default flags: all false. -/
def SigActionFlags.defaults : SigActionFlags := {}

/-! ## SignalDisposition -/

/-- The per-signal action registered for a process. -/
inductive SignalDisposition where
  /-- Execute the kernel default behavior for this signal. -/
  | default
  /-- Discard the signal. -/
  | ignore
  /-- Invoke a user-space handler with the given additional mask and flags. -/
  | handler (mask : SigSet) (flags : SigActionFlags)
  deriving Repr

/-! ## SigActionHow -/

/-- The `how` parameter to sigprocmask(2). -/
inductive SigActionHow where
  /-- new = old union set -/
  | block
  /-- new = old \ set -/
  | unblock
  /-- new = set -/
  | setmask
  deriving DecidableEq, Repr

/-! ## SignalState -/

/-- Per-process signal state: blocked mask, pending set, and per-signal dispositions.
    Invariant (maintained operationally): SIGKILL and SIGSTOP are never in `blocked`. -/
structure SignalState where
  /-- Currently blocked signals (never contains SIGKILL or SIGSTOP). -/
  blocked      : SigSet
  /-- Signals raised while blocked, awaiting delivery. -/
  pending      : SigSet
  /-- Per-signal disposition table. -/
  dispositions : Signal -> SignalDisposition

/-- Initial signal state: nothing blocked or pending, all dispositions default. -/
def SignalState.initial : SignalState :=
  { blocked := [], pending := [], dispositions := fun _ => .default }

/-! ## KillTarget -/

/-- Encodes the `pid` argument to kill(2). -/
inductive KillTarget where
  /-- Signal a specific process. -/
  | specific     (pid  : Nat)
  /-- Signal all processes in a process group. -/
  | processGroup (pgid : Nat)
  /-- Signal all processes in the caller's process group. -/
  | callerGroup
  /-- Signal all reachable processes except PID 1. -/
  | allReachable
  deriving DecidableEq, Repr

end SWELib.OS.Signals
