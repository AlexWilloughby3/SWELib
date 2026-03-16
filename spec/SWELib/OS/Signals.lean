import SWELib.OS.Signals.Types
import SWELib.OS.Signals.Operations
import SWELib.OS.Signals.Invariants

/-!
# Signals

POSIX signal model: disposition, masking, pending sets, and key invariants.

Sub-modules:
- `SWELib.OS.Signals.Types`      -- Signal, SigSet, SignalDisposition, SignalState, KillTarget
- `SWELib.OS.Signals.Operations` -- sigaction, sigprocmask, sigpending, kill
- `SWELib.OS.Signals.Invariants` -- invariant theorems
-/
