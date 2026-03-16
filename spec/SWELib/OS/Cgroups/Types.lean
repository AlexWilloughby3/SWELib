
/-!
# Control Groups Types

Type definitions for cgroup controllers, limits, and configuration.

References:
- cgroups(7): https://man7.org/linux/man-pages/man7/cgroups.7.html
- cgroup-v2: https://docs.kernel.org/admin-guide/cgroup-v2.html
-/

namespace SWELib.OS

/-- A control group path in the cgroup filesystem. -/
structure Cgroup where
  /-- Path to the cgroup directory in the cgroup filesystem. -/
  path : String
  deriving DecidableEq, Repr, Inhabited

instance : ToString Cgroup where
  toString cg := s!"cgroup({cg.path})"

/-- Check if a cgroup path is valid (non-empty and doesn't contain ".."). -/
def Cgroup.isValid (cg : Cgroup) : Bool :=
  cg.path ≠ "" && !cg.path.contains ".."

/-- Cgroup controller types. -/
inductive CgroupController where
  /-- Memory controller: limits memory usage. -/
  | memory
  /-- CPU controller: controls CPU bandwidth. -/
  | cpu
  /-- PID controller: limits number of processes. -/
  | pids
  /-- CPUSet controller: assigns CPUs and memory nodes. -/
  | cpuset
  /-- IO controller: controls block I/O bandwidth. -/
  | io
  deriving DecidableEq, Repr

instance : ToString CgroupController where
  toString controller :=
    match controller with
    | .memory => "memory"
    | .cpu => "cpu"
    | .pids => "pids"
    | .cpuset => "cpuset"
    | .io => "io"

/-- Cgroup type (v2 hierarchy). -/
inductive CgroupType where
  /-- Domain cgroup: can contain processes and child cgroups. -/
  | domain
  /-- Threaded cgroup: can contain threads. -/
  | threaded
  /-- Domain threaded cgroup: can be both domain and threaded. -/
  | domain_threaded
  /-- Invalid cgroup type. -/
  | domain_invalid
  deriving DecidableEq, Repr

instance : ToString CgroupType where
  toString ctype :=
    match ctype with
    | .domain => "domain"
    | .threaded => "threaded"
    | .domain_threaded => "domain threaded"
    | .domain_invalid => "domain invalid"

/-- Resource limits for cgroups. -/
inductive CgroupLimit where
  /-- Memory limit in bytes. -/
  | memory (bytes : Nat)
  /-- CPU weight (1-10000). -/
  | cpuWeight (weight : Nat)
  /-- CPU bandwidth limit: quota (microseconds) per period (microseconds). -/
  | cpuMax (quota : Nat) (period : Nat)
  /-- Maximum number of processes. -/
  | pidCount (count : Nat)
  /-- CPU set assignment: list of CPU numbers. -/
  | cpuset (cpus : List Nat)
  deriving DecidableEq, Repr

instance : ToString CgroupLimit where
  toString limit :=
    match limit with
    | .memory bytes => s!"memory({bytes} bytes)"
    | .cpuWeight weight => s!"cpu.weight({weight})"
    | .cpuMax quota period => s!"cpu.max({quota}us/{period}us)"
    | .pidCount count => s!"pids.max({count})"
    | .cpuset cpus => s!"cpuset.cpus({cpus})"

/-- Check if a CPU weight is valid (1-10000). -/
def CgroupLimit.cpuWeightValid (weight : Nat) : Bool :=
  1 ≤ weight ∧ weight ≤ 10000

/-- Check if a CPU max quota/period is valid. -/
def CgroupLimit.cpuMaxValid (quota period : Nat) : Bool :=
  period > 0 ∧ (quota = 0 ∨ quota ≥ 1000)  -- quota=0 means no limit, otherwise minimum 1000us

/-- Cgroup control files for reading/writing limits. -/
inductive CgroupFile where
  /-- memory.max: maximum memory usage. -/
  | memoryMax
  /-- memory.current: current memory usage. -/
  | memoryCurrent
  /-- cpu.weight: CPU weight (1-10000). -/
  | cpuWeight
  /-- cpu.max: CPU bandwidth limit. -/
  | cpuMax
  /-- pids.max: maximum number of processes. -/
  | pidsMax
  /-- cgroup.procs: list of processes in cgroup. -/
  | cgroupProcs
  /-- cgroup.threads: list of threads in cgroup. -/
  | cgroupThreads
  /-- cgroup.controllers: list of enabled controllers. -/
  | cgroupControllers
  /-- cgroup.subtree_control: controllers enabled in subtree. -/
  | cgroupSubtreeControl
  deriving DecidableEq, Repr

instance : ToString CgroupFile where
  toString file :=
    match file with
    | .memoryMax => "memory.max"
    | .memoryCurrent => "memory.current"
    | .cpuWeight => "cpu.weight"
    | .cpuMax => "cpu.max"
    | .pidsMax => "pids.max"
    | .cgroupProcs => "cgroup.procs"
    | .cgroupThreads => "cgroup.threads"
    | .cgroupControllers => "cgroup.controllers"
    | .cgroupSubtreeControl => "cgroup.subtree_control"

/-- Get the controller for a cgroup file. -/
def CgroupFile.controller : CgroupFile → Option CgroupController
  | .memoryMax => some .memory
  | .memoryCurrent => some .memory
  | .cpuWeight => some .cpu
  | .cpuMax => some .cpu
  | .pidsMax => some .pids
  | .cgroupProcs => none
  | .cgroupThreads => none
  | .cgroupControllers => none
  | .cgroupSubtreeControl => none

end SWELib.OS