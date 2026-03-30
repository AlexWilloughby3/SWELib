import SWELib
import SWELibImpl.Bridge
import SWELibImpl.Ffi.Syscalls

/-!
# ProcessOps

Typed wrappers around raw process/env/user syscalls.
Converts between spec types (PID, Signal, UserId, etc.) and raw integers.
-/

namespace SWELibImpl.OS.ProcessOps

open SWELib.OS

/-! ## Process operations -/

/-- Fork the current process. Returns the child's PID in the parent. -/
def forkProcess : IO (Except Errno PID) := do
  let result ← SWELibImpl.Ffi.Syscalls.fork
  match result with
  | .ok pid => return .ok ⟨pid.toNatClampNeg⟩
  | .error e => return .error e

/-- Exit the current process with the given code. -/
def exitProcess (code : UInt8) : IO Unit :=
  SWELibImpl.Ffi.Syscalls.exit_ code

/-- Wait for a specific child process. Returns the exit status. -/
def waitForChild (child : PID) : IO (Except Errno UInt8) := do
  let result ← SWELibImpl.Ffi.Syscalls.waitpid child.pid.toInt32 0
  match result with
  | .ok (_, status) => return .ok status.toUInt8
  | .error e => return .error e

/-- Send a signal to a process. -/
def killProcess (target : PID) (sig : Signal) : IO (Except Errno Unit) := do
  let sigNum : UInt32 := match sig with
    | .SIGKILL => 9
    | .SIGTERM => 15
    | .SIGSTOP => 19
    | .SIGCONT => 18
    | .SIGSEGV => 11
    | .SIGBUS  => 7
  SWELibImpl.Ffi.Syscalls.kill target.pid.toInt32 sigNum

/-- Get the current process's PID. -/
def getPid : IO PID := do
  let pid ← SWELibImpl.Ffi.Syscalls.getpid
  return ⟨pid.toNatClampNeg⟩

/-- Get the parent process's PID. -/
def getParentPid : IO PID := do
  let pid ← SWELibImpl.Ffi.Syscalls.getppid
  return ⟨pid.toNatClampNeg⟩

/-! ## Environment operations -/

/-- Get an environment variable. -/
def getEnv (name : String) : IO (Option String) :=
  SWELibImpl.Ffi.Syscalls.getenv name

/-- Set an environment variable. -/
def setEnv (name value : String) : IO (Except Errno Unit) :=
  SWELibImpl.Ffi.Syscalls.setenv name value 1

/-- Unset an environment variable. -/
def unsetEnv (name : String) : IO (Except Errno Unit) :=
  SWELibImpl.Ffi.Syscalls.unsetenv name

/-- Get the current working directory. -/
def getCwd : IO (Except Errno String) :=
  SWELibImpl.Ffi.Syscalls.getcwd

/-- Change the current working directory. -/
def changeCwd (path : String) : IO (Except Errno Unit) :=
  SWELibImpl.Ffi.Syscalls.chdir path

/-! ## User/group operations -/

/-- Get the real user ID. -/
def getUid : IO UserId := do
  let uid ← SWELibImpl.Ffi.Syscalls.getuid
  return ⟨uid.toNat⟩

/-- Get the effective user ID. -/
def getEffectiveUid : IO UserId := do
  let uid ← SWELibImpl.Ffi.Syscalls.geteuid
  return ⟨uid.toNat⟩

/-- Get the real group ID. -/
def getGid : IO GroupId := do
  let gid ← SWELibImpl.Ffi.Syscalls.getgid
  return ⟨gid.toNat⟩

/-- Get the effective group ID. -/
def getEffectiveGid : IO GroupId := do
  let gid ← SWELibImpl.Ffi.Syscalls.getegid
  return ⟨gid.toNat⟩

/-- Get the full credentials of the current process. -/
def getCredentials : IO UserCredentials := do
  let ruid ← getUid
  let euid ← getEffectiveUid
  let rgid ← getGid
  let egid ← getEffectiveGid
  return { ruid, euid, rgid, egid }

end SWELibImpl.OS.ProcessOps
