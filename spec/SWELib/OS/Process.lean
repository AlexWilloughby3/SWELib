import SWELib.OS.Io
import SWELib.OS.Environment

/-!
# Process Lifecycle

POSIX process model: fork, exec, exit, wait, kill.

References:
- fork(2):    https://man7.org/linux/man-pages/man2/fork.2.html
- execve(2):  https://man7.org/linux/man-pages/man2/execve.2.html
- _exit(2):   https://man7.org/linux/man-pages/man2/_exit.2.html
- waitpid(2): https://man7.org/linux/man-pages/man2/waitpid.2.html
- kill(2):    https://man7.org/linux/man-pages/man2/kill.2.html
-/

namespace SWELib.OS

/-! ## Process identity -/

/-- A process identifier. -/
structure PID where
  pid : Nat
  deriving DecidableEq, Repr

instance : ToString PID where
  toString p := s!"pid({p.pid})"

/-! ## Signals -/

/-- A subset of POSIX signals relevant to process lifecycle. -/
inductive Signal where
  | SIGKILL
  | SIGTERM
  | SIGSTOP
  | SIGCONT
  /-- Segmentation fault: invalid memory reference. -/
  | SIGSEGV
  /-- Bus error: misaligned or non-existent physical address. -/
  | SIGBUS
  deriving DecidableEq, Repr

/-! ## Process status -/

/-- The lifecycle state of a process. -/
inductive ProcessStatus where
  /-- Process is running normally. -/
  | running
  /-- Process is stopped (e.g., by SIGSTOP). -/
  | stopped
  /-- Process has exited but not yet waited on. Holds the exit code. -/
  | zombie (exitCode : UInt8)
  deriving Repr

/-! ## Process state -/

/-- Per-process state tracked in the process table. -/
structure ProcessState where
  /-- This process's PID. -/
  pid : PID
  /-- Parent process's PID. -/
  ppid : PID
  /-- Current lifecycle status. -/
  status : ProcessStatus
  /-- Process environment variables. -/
  env : Environment
  /-- File descriptor table. -/
  fdTable : FdTable

/-! ## Process table -/

/-- The system-wide process table: maps PID numbers to process state. -/
def ProcessTable := Nat → Option ProcessState

/-- The empty process table. -/
def ProcessTable.empty : ProcessTable := fun _ => none

/-- Look up a process by PID. -/
def ProcessTable.lookup (pt : ProcessTable) (pid : PID) : Option ProcessState :=
  pt pid.pid

/-- Update a single entry in the process table. -/
def ProcessTable.update (pt : ProcessTable) (pid : PID) (ps : ProcessState) :
    ProcessTable :=
  fun n => if n = pid.pid then some ps else pt n

/-- Remove a process from the table. -/
def ProcessTable.remove (pt : ProcessTable) (pid : PID) : ProcessTable :=
  fun n => if n = pid.pid then none else pt n

/-! ## fork(2) -/

/-- `fork(2)`: create a child process.
    The child gets `childPid` (modeled as an explicit parameter since the
    kernel allocates PIDs externally). The child inherits the parent's
    environment and fd table. -/
def ProcessTable.fork (pt : ProcessTable) (parentPid childPid : PID) :
    ProcessTable × Except Errno PID :=
  match pt.lookup parentPid with
  | some parent =>
    match parent.status with
    | .running =>
      let child : ProcessState :=
        { pid := childPid
          ppid := parentPid
          status := .running
          env := parent.env
          fdTable := parent.fdTable }
      (pt.update childPid child, .ok childPid)
    | _ => (pt, .error .EPERM)
  | none => (pt, .error .ESRCH)

/-! ## _exit(2) -/

/-- `_exit(2)`: terminate the calling process.
    Transitions the process to zombie status with the given exit code. -/
def ProcessTable.exit (pt : ProcessTable) (pid : PID) (code : UInt8) :
    ProcessTable × Except Errno Unit :=
  match pt.lookup pid with
  | some ps =>
    match ps.status with
    | .running | .stopped =>
      let ps' := { ps with status := .zombie code }
      (pt.update pid ps', .ok ())
    | .zombie _ => (pt, .error .ESRCH)
  | none => (pt, .error .ESRCH)

/-! ## waitpid(2) -/

/-- `waitpid(2)`: wait for a child process.
    If the child is a zombie, reaps it (removes from table) and returns
    the exit code. Otherwise returns ECHILD. -/
def ProcessTable.waitpid (pt : ProcessTable) (parentPid childPid : PID) :
    ProcessTable × Except Errno UInt8 :=
  match pt.lookup childPid with
  | some child =>
    if child.ppid == parentPid then
      match child.status with
      | .zombie code => (pt.remove childPid, .ok code)
      | _ => (pt, .error .ECHILD)  -- child exists but not zombie
    else
      (pt, .error .ECHILD)  -- not our child
  | none => (pt, .error .ECHILD)

/-! ## kill(2) -/

/-- `kill(2)`: send a signal to a process.
    Simplified model: SIGKILL/SIGTERM → zombie (code 137/143),
    SIGSTOP → stopped, SIGCONT → running. -/
def ProcessTable.kill (pt : ProcessTable) (target : PID) (sig : Signal) :
    ProcessTable × Except Errno Unit :=
  match pt.lookup target with
  | some ps =>
    match ps.status with
    | .zombie _ => (pt, .error .ESRCH)
    | .running | .stopped =>
      let ps' := match sig with
        | .SIGKILL => { ps with status := .zombie ⟨137⟩ }
        | .SIGTERM => { ps with status := .zombie ⟨143⟩ }
        | .SIGSTOP => { ps with status := .stopped }
        | .SIGCONT => { ps with status := .running }
        | .SIGSEGV => { ps with status := .zombie ⟨139⟩ }
        | .SIGBUS  => { ps with status := .zombie ⟨135⟩ }
      (pt.update target ps', .ok ())
  | none => (pt, .error .ESRCH)

/-! ## exec(2) -/

/-- `exec(2)`: replace the process image.
    Modeled as environment replacement only — code loading is external. -/
def ProcessTable.exec (pt : ProcessTable) (pid : PID)
    (newEnv : Environment) : ProcessTable × Except Errno Unit :=
  match pt.lookup pid with
  | some ps =>
    match ps.status with
    | .running =>
      let ps' := { ps with env := newEnv }
      (pt.update pid ps', .ok ())
    | _ => (pt, .error .EPERM)
  | none => (pt, .error .ESRCH)

/-! ## Theorems -/

/-- fork produces a child with a different PID from the parent. -/
theorem ProcessTable.fork_distinct_pids (pt : ProcessTable)
    (parentPid childPid : PID) (parent : ProcessState)
    (h_found : pt.lookup parentPid = some parent)
    (h_running : parent.status = .running)
    (h_ne : parentPid ≠ childPid) :
    ∀ result, (pt.fork parentPid childPid).2 = .ok result →
      result ≠ parentPid := by
  intro result h_ok
  simp [ProcessTable.fork, h_found, h_running] at h_ok
  rw [← h_ok]
  exact Ne.symm h_ne

/-- fork child inherits parent's environment. -/
theorem ProcessTable.fork_child_inherits_env (pt : ProcessTable)
    (parentPid childPid : PID) (parent : ProcessState)
    (h_found : pt.lookup parentPid = some parent)
    (h_running : parent.status = .running) :
    (pt.fork parentPid childPid).1.lookup childPid =
      some { pid := childPid, ppid := parentPid, status := .running,
             env := parent.env, fdTable := parent.fdTable } := by
  simp [ProcessTable.fork, h_found, h_running]
  simp [ProcessTable.lookup, ProcessTable.update]

/-- fork child inherits parent's fd table. -/
theorem ProcessTable.fork_child_inherits_fdTable (pt : ProcessTable)
    (parentPid childPid : PID) (parent : ProcessState)
    (h_found : pt.lookup parentPid = some parent)
    (h_running : parent.status = .running) :
    match (pt.fork parentPid childPid).1.lookup childPid with
    | some child => child.fdTable = parent.fdTable
    | none => False := by
  simp [ProcessTable.fork, h_found, h_running]
  simp [ProcessTable.lookup, ProcessTable.update]

/-- exit transitions a running process to zombie with the given code. -/
theorem ProcessTable.exit_to_zombie (pt : ProcessTable) (pid : PID)
    (code : UInt8) (ps : ProcessState)
    (h_found : pt.lookup pid = some ps)
    (h_running : ps.status = .running) :
    match (pt.exit pid code).1.lookup pid with
    | some ps' => ps'.status = .zombie code
    | none => False := by
  simp [ProcessTable.exit, h_found, h_running]
  simp [ProcessTable.lookup, ProcessTable.update]

/-- waitpid reaps a zombie child and returns its exit code. -/
theorem ProcessTable.wait_reaps_zombie (pt : ProcessTable)
    (parentPid childPid : PID) (child : ProcessState) (code : UInt8)
    (h_found : pt.lookup childPid = some child)
    (h_parent : (child.ppid == parentPid) = true)
    (h_zombie : child.status = .zombie code) :
    (pt.waitpid parentPid childPid).2 = .ok code := by
  simp [ProcessTable.waitpid, h_found, h_parent, h_zombie]

/-- waitpid on a non-child returns ECHILD. -/
theorem ProcessTable.wait_non_child_echild (pt : ProcessTable)
    (parentPid childPid : PID) (child : ProcessState)
    (h_found : pt.lookup childPid = some child)
    (h_not_parent : (child.ppid == parentPid) = false) :
    (pt.waitpid parentPid childPid).2 = .error .ECHILD := by
  simp [ProcessTable.waitpid, h_found, h_not_parent]

/-- kill on a non-existent process returns ESRCH. -/
theorem ProcessTable.kill_nonexistent_esrch (pt : ProcessTable)
    (target : PID) (sig : Signal)
    (h : pt.lookup target = none) :
    (pt.kill target sig).2 = .error .ESRCH := by
  simp [ProcessTable.kill, h]

/-- SIGKILL always transitions running to zombie. -/
theorem ProcessTable.sigkill_kills_running (pt : ProcessTable)
    (target : PID) (ps : ProcessState)
    (h_found : pt.lookup target = some ps)
    (h_running : ps.status = .running) :
    match (pt.kill target .SIGKILL).1.lookup target with
    | some ps' => ps'.status = .zombie ⟨137⟩
    | none => False := by
  simp [ProcessTable.kill, h_found, h_running]
  simp [ProcessTable.lookup, ProcessTable.update]

/-- SIGKILL always transitions stopped to zombie. -/
theorem ProcessTable.sigkill_kills_stopped (pt : ProcessTable)
    (target : PID) (ps : ProcessState)
    (h_found : pt.lookup target = some ps)
    (h_stopped : ps.status = .stopped) :
    match (pt.kill target .SIGKILL).1.lookup target with
    | some ps' => ps'.status = .zombie ⟨137⟩
    | none => False := by
  simp [ProcessTable.kill, h_found, h_stopped]
  simp [ProcessTable.lookup, ProcessTable.update]

end SWELib.OS
