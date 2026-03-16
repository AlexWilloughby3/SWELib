import SWELib.OS.Io

/-!
# Linux Capabilities

Linux capability model for fine-grained privilege separation.

References:
- capabilities(7): https://man7.org/linux/man-pages/man7/capabilities.7.html
-/

namespace SWELib.OS

/-- Linux capabilities for fine-grained privilege separation.
    Based on Linux capability set from capabilities(7). -/
inductive Capability where
  /-- Bypass permission checks for chown(2). -/
  | CAP_CHOWN
  /-- Bypass permission checks for operations on files with UID or GID equal to the process UID or GID. -/
  | CAP_DAC_OVERRIDE
  /-- Bypass file read, write, and execute permission checks. -/
  | CAP_DAC_READ_SEARCH
  /-- Bypass permission checks for sending signals. -/
  | CAP_KILL
  /-- Bypass permission checks for setting group ID. -/
  | CAP_SETGID
  /-- Bypass permission checks for setting user ID. -/
  | CAP_SETUID
  /-- Bypass permission checks for setting file capabilities. -/
  | CAP_SETPCAP
  /-- Bypass permission checks for performing IPC operations. -/
  | CAP_IPC_OWNER
  /-- Bypass permission checks for performing system administration tasks. -/
  | CAP_SYS_ADMIN
  /-- Bypass permission checks for raw I/O port access. -/
  | CAP_SYS_RAWIO
  /-- Bypass permission checks for module loading and unloading. -/
  | CAP_SYS_MODULE
  /-- Bypass permission checks for chroot(2). -/
  | CAP_SYS_CHROOT
  /-- Bypass permission checks for manipulating process accounting. -/
  | CAP_SYS_PACCT
  /-- Bypass permission checks for system time manipulation. -/
  | CAP_SYS_TIME
  /-- Bypass permission checks for resource limits. -/
  | CAP_SYS_RESOURCE
  /-- Bypass permission checks for nice(2). -/
  | CAP_SYS_NICE
  /-- Bypass permission checks for mlock(2), mlockall(2), mmap(2), shmctl(2). -/
  | CAP_SYSLOG
  /-- Bypass permission checks for reboot(2). -/
  | CAP_SYS_BOOT
  deriving DecidableEq, Repr, Inhabited

instance : ToString Capability where
  toString cap :=
    match cap with
    | .CAP_CHOWN => "CAP_CHOWN"
    | .CAP_DAC_OVERRIDE => "CAP_DAC_OVERRIDE"
    | .CAP_DAC_READ_SEARCH => "CAP_DAC_READ_SEARCH"
    | .CAP_KILL => "CAP_KILL"
    | .CAP_SETGID => "CAP_SETGID"
    | .CAP_SETUID => "CAP_SETUID"
    | .CAP_SETPCAP => "CAP_SETPCAP"
    | .CAP_IPC_OWNER => "CAP_IPC_OWNER"
    | .CAP_SYS_ADMIN => "CAP_SYS_ADMIN"
    | .CAP_SYS_RAWIO => "CAP_SYS_RAWIO"
    | .CAP_SYS_MODULE => "CAP_SYS_MODULE"
    | .CAP_SYS_CHROOT => "CAP_SYS_CHROOT"
    | .CAP_SYS_PACCT => "CAP_SYS_PACCT"
    | .CAP_SYS_TIME => "CAP_SYS_TIME"
    | .CAP_SYS_RESOURCE => "CAP_SYS_RESOURCE"
    | .CAP_SYS_NICE => "CAP_SYS_NICE"
    | .CAP_SYSLOG => "CAP_SYSLOG"
    | .CAP_SYS_BOOT => "CAP_SYS_BOOT"

/-- Check if a capability allows filesystem operations. -/
def Capability.isFilesystemCap : Capability → Bool
  | .CAP_CHOWN => true
  | .CAP_DAC_OVERRIDE => true
  | .CAP_DAC_READ_SEARCH => true
  | .CAP_SYS_CHROOT => true
  | _ => false

/-- Check if a capability allows process manipulation. -/
def Capability.isProcessCap : Capability → Bool
  | .CAP_KILL => true
  | .CAP_SETGID => true
  | .CAP_SETUID => true
  | .CAP_SYS_PACCT => true
  | .CAP_SYS_NICE => true
  | _ => false

/-- Check if a capability allows system administration. -/
def Capability.isSysAdminCap : Capability → Bool
  | .CAP_SYS_ADMIN => true
  | .CAP_SYS_RAWIO => true
  | .CAP_SYS_MODULE => true
  | .CAP_SYS_TIME => true
  | .CAP_SYS_RESOURCE => true
  | .CAP_SYSLOG => true
  | .CAP_SYS_BOOT => true
  | _ => false

/-- The empty capability set. -/
def CapabilitySet : Type := Array Capability

/-- Check if a capability set contains a specific capability. -/
def CapabilitySet.contains (set : CapabilitySet) (cap : Capability) : Bool :=
  set.contains cap

/-- Add a capability to a set. -/
def CapabilitySet.add (set : CapabilitySet) (cap : Capability) : CapabilitySet :=
  if set.contains cap then set else set.push cap

/-- Remove a capability from a set. -/
def CapabilitySet.remove (set : CapabilitySet) (cap : Capability) : CapabilitySet :=
  set.filter (· ≠ cap)

/-- Check if a capability set is a subset of another. -/
def CapabilitySet.subset (s1 s2 : CapabilitySet) : Bool :=
  s1.all (s2.contains ·)

end SWELib.OS