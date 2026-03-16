import SWELib.OS.Process

/-!
# Linux Namespace Types

Type definitions for Linux namespaces, clone flags, and namespace-aware process IDs.

References:
- clone(2): https://man7.org/linux/man-pages/man2/clone.2.html
- unshare(2): https://man7.org/linux/man-pages/man2/unshare.2.html
- setns(2): https://man7.org/linux/man-pages/man2/setns.2.html
-/

namespace SWELib.OS

/-- Linux namespace types for process isolation. -/
inductive Namespace where
  /-- PID namespace: isolates process ID number space. -/
  | pid
  /-- Network namespace: isolates network interfaces, routing tables, etc. -/
  | network
  /-- Mount namespace: isolates filesystem mount points. -/
  | mount
  /-- IPC namespace: isolates System V IPC, POSIX message queues. -/
  | ipc
  /-- UTS namespace: isolates hostname and NIS domain name. -/
  | uts
  /-- User namespace: isolates user and group ID number spaces. -/
  | user
  /-- Cgroup namespace: isolates cgroup root directory. -/
  | cgroup
  /-- Time namespace: isolates system clocks. -/
  | time
  deriving DecidableEq, Repr, Inhabited

instance : ToString Namespace where
  toString ns :=
    match ns with
    | .pid => "pid"
    | .network => "network"
    | .mount => "mount"
    | .ipc => "ipc"
    | .uts => "uts"
    | .user => "user"
    | .cgroup => "cgroup"
    | .time => "time"

/-- A file descriptor referencing a namespace. -/
structure NamespaceFD where
  /-- The file descriptor number. -/
  fd : Nat
  /-- The type of namespace referenced. -/
  nsType : Namespace
  deriving DecidableEq, Repr

instance : ToString NamespaceFD where
  toString ns := s!"NamespaceFD(fd={ns.fd}, type={ns.nsType})"

/-- Clone flags for creating new namespaces. -/
inductive CloneFlag where
  /-- Create new PID namespace. -/
  | NEWPID
  /-- Create new network namespace. -/
  | NEWNET
  /-- Create new mount namespace. -/
  | NEWNS
  /-- Create new IPC namespace. -/
  | NEWIPC
  /-- Create new UTS namespace. -/
  | NEWUTS
  /-- Create new user namespace. -/
  | NEWUSER
  /-- Create new cgroup namespace. -/
  | NEWCGROUP
  /-- Create new time namespace. -/
  | NEWTIME
  /-- Clone filesystem information. -/
  | FS
  /-- Clone VM address space. -/
  | VM
  /-- Clone signal handlers. -/
  | SIGHAND
  /-- Create thread (share TGID). -/
  | THREAD
  /-- Clone System V semaphore undo values. -/
  | SYSVSEM
  /-- Set up TLS (thread-local storage). -/
  | SETTLS
  /-- Write child TID into parent's memory. -/
  | PARENT_SETTID
  /-- Clear child TID in child memory. -/
  | CHILD_CLEARTID
  /-- Create detached thread. -/
  | DETACHED
  /-- Don't trace child (ptrace). -/
  | UNTRACED
  /-- Write child TID into child memory. -/
  | CHILD_SETTID
  deriving DecidableEq, Repr

instance : ToString CloneFlag where
  toString flag :=
    match flag with
    | .NEWPID => "CLONE_NEWPID"
    | .NEWNET => "CLONE_NEWNET"
    | .NEWNS => "CLONE_NEWNS"
    | .NEWIPC => "CLONE_NEWIPC"
    | .NEWUTS => "CLONE_NEWUTS"
    | .NEWUSER => "CLONE_NEWUSER"
    | .NEWCGROUP => "CLONE_NEWCGROUP"
    | .NEWTIME => "CLONE_NEWTIME"
    | .FS => "CLONE_FS"
    | .VM => "CLONE_VM"
    | .SIGHAND => "CLONE_SIGHAND"
    | .THREAD => "CLONE_THREAD"
    | .SYSVSEM => "CLONE_SYSVSEM"
    | .SETTLS => "CLONE_SETTLS"
    | .PARENT_SETTID => "CLONE_PARENT_SETTID"
    | .CHILD_CLEARTID => "CLONE_CHILD_CLEARTID"
    | .DETACHED => "CLONE_DETACHED"
    | .UNTRACED => "CLONE_UNTRACED"
    | .CHILD_SETTID => "CLONE_CHILD_SETTID"

/-- Set of clone flags for namespace creation. -/
def CloneFlags := List CloneFlag

/-- Mount propagation flags for mount namespaces. -/
inductive MountPropagation where
  /-- Mount events propagate to peer mounts. -/
  | SHARED
  /-- Mount events don't propagate. -/
  | PRIVATE
  /-- Mount events propagate from master to slave. -/
  | SLAVE
  /-- Mount can't be bind mounted. -/
  | UNBINDABLE
  deriving DecidableEq, Repr

instance : ToString MountPropagation where
  toString prop :=
    match prop with
    | .SHARED => "MS_SHARED"
    | .PRIVATE => "MS_PRIVATE"
    | .SLAVE => "MS_SLAVE"
    | .UNBINDABLE => "MS_UNBINDABLE"

/-- Process ID with namespace context. -/
structure NamespacedPID extends PID where
  /-- Opaque namespace identifier for PID namespace isolation. -/
  namespaceId : Nat
  deriving DecidableEq, Repr

instance : ToString NamespacedPID where
  toString p := s!"NamespacedPID(pid={p.pid}, namespace={p.namespaceId})"

/-- Check if a PID is in the same namespace as another. -/
def NamespacedPID.sameNamespace (p1 p2 : NamespacedPID) : Bool :=
  p1.namespaceId = p2.namespaceId

/-- Check if a PID is in the initial namespace (namespace ID 0). -/
def NamespacedPID.isInitialNamespace (p : NamespacedPID) : Bool :=
  p.namespaceId = 0

end SWELib.OS