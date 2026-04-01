import SWELib.OS.Process
import SWELib.OS.Users
import SWELib.OS.Namespaces
import SWELib.OS.Cgroups
import SWELib.OS.Capabilities
import SWELib.Basics.Semver
import SWELib.Basics.Time

/-!
# OCI Runtime Types

Open Container Initiative runtime specification types.

References:
- OCI Runtime Specification v1.0: https://github.com/opencontainers/runtime-spec
-/

namespace SWELib.Cloud.Oci

/-- Container lifecycle status. -/
inductive ContainerStatus where
  /-- Container is being created. -/
  | creating
  /-- Container has been created but not started. -/
  | created
  /-- Container is running. -/
  | running
  /-- Container has been stopped. -/
  | stopped
  /-- Container has been paused. -/
  | paused
  deriving DecidableEq, Repr, Inhabited

instance : ToString ContainerStatus where
  toString status :=
    match status with
    | .creating => "creating"
    | .created => "created"
    | .running => "running"
    | .stopped => "stopped"
    | .paused => "paused"

/-- Root filesystem configuration for a container. -/
structure Root where
  /-- Path to the root filesystem. -/
  path : String
  /-- Whether the root filesystem is read-only. -/
  readonly : Bool := false
  deriving DecidableEq, Repr, Inhabited

/-- Filesystem mount configuration. -/
structure Mount where
  /-- Mount source (device, directory, etc.). -/
  source : String
  /-- Mount target path inside container. -/
  destination : String
  /-- Filesystem type (e.g., "proc", "tmpfs", "bind"). -/
  fstype : String
  /-- Mount options (e.g., "ro", "noexec"). -/
  options : Array String := #[]
  deriving DecidableEq, Repr, Inhabited

/-- Seccomp profile (simplified as opaque string for now). -/
def Seccomp := String

/-- Process configuration for container init process. -/
structure ProcessConfig where
  /-- Process arguments (argv). -/
  args : Array String
  /-- Process environment variables. -/
  env : Array String := #[]
  /-- Working directory. -/
  cwd : String := "/"
  /-- User credentials for the process. -/
  user : SWELib.OS.UserCredentials
  /-- Linux capabilities for the process. -/
  capabilities : Array SWELib.OS.Capability := #[]
  /-- Resource limits (rlimits). -/
  rlimits : Array String := #[]  -- Simplified for now
  /-- Whether the terminal is attached. -/
  terminal : Bool := false

/-- Hook configuration. -/
structure Hooks where
  /-- Pre-create hooks. -/
  precreate : Array (Unit → Except String Unit) := #[]
  /-- Post-create hooks. -/
  postcreate : Array (Unit → Except String Unit) := #[]
  /-- Pre-start hooks. -/
  prestart : Array (Unit → Except String Unit) := #[]
  /-- Post-start hooks. -/
  poststart : Array (Unit → Except String Unit) := #[]
  /-- Post-stop hooks. -/
  poststop : Array (Unit → Except String Unit) := #[]

/-- Linux-specific configuration. -/
structure LinuxConfig where
  /-- Namespaces to create for the container. -/
  namespaces : Array SWELib.OS.Namespace := #[]
  /-- Cgroup configuration. -/
  cgroups : SWELib.OS.Cgroup := ⟨"/"⟩
  /-- Resource limits (memory, CPU, PIDs). -/
  resources : Array SWELib.OS.CgroupLimit := #[]
  /-- Seccomp profile. -/
  seccomp : Option Seccomp := none
  /-- Masked paths (paths to mask with tmpfs). -/
  maskedPaths : Array String := #[]
  /-- Read-only paths. -/
  readonlyPaths : Array String := #[]

/-- Container configuration bundle. -/
structure ContainerConfig where
  /-- OCI version (must be "1.0.0" or compatible). -/
  ociVersion : SWELib.Basics.Semver
  /-- Root filesystem configuration. -/
  root : Root
  /-- Process configuration. -/
  process : ProcessConfig
  /-- Hostname for the container. -/
  hostname : String := "container"
  /-- Mounts to set up in the container. -/
  mounts : Array Mount := #[]
  /-- Hooks to execute at lifecycle events. -/
  hooks : Hooks := {}
  /-- Linux-specific configuration. -/
  linux : LinuxConfig := {}

/-- Container runtime state. -/
structure ContainerState where
  /-- Container identifier. -/
  id : String
  /-- Bundle path containing container configuration. -/
  bundle : String
  /-- Current container status. -/
  status : ContainerStatus
  /-- Container process ID (if running). -/
  pid : Option SWELib.OS.PID := none
  /-- Container configuration. -/
  config : ContainerConfig
  /-- Creation timestamp. -/
  createdAt : SWELib.Basics.NumericDate
  /-- Start timestamp (if started). -/
  startedAt : Option SWELib.Basics.NumericDate := none
  /-- Stop timestamp (if stopped). -/
  stoppedAt : Option SWELib.Basics.NumericDate := none

/-- Check if a container configuration is valid. -/
def ContainerConfig.isValid (config : ContainerConfig) : Bool :=
  -- OCI version must be 1.0.0 or compatible
  let versionOk := config.ociVersion.major = 1 && config.ociVersion.minor = 0
  -- Root path must be non-empty
  let rootOk := config.root.path ≠ ""
  -- Process must have at least one argument
  let processOk := !config.process.args.isEmpty
  versionOk && rootOk && processOk

/-- Check if a container state transition is valid. -/
def ContainerStatus.canTransition (src dst : ContainerStatus) : Bool :=
  match src, dst with
  | .creating, .created => true
  | .created, .running => true
  | .running, .stopped => true
  | .running, .paused => true
  | .paused, .running => true
  | .stopped, .created => false  -- cannot restart from stopped
  | _, .creating => false  -- cannot go back to creating
  | _, _ => false

/-- Get the default OCI version (1.0.0). -/
def defaultOciVersion : SWELib.Basics.Semver :=
  { major := 1, minor := 0, patch := 0 }

end SWELib.Cloud.Oci
