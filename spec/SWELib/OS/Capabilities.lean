import SWELib.OS.Io

/-!
# Linux Capabilities

Linux capability model for fine-grained privilege separation.

References:
- capabilities(7): https://man7.org/linux/man-pages/man7/capabilities.7.html
-/

namespace SWELib.OS

/-- Linux capabilities for fine-grained privilege separation.
    Based on Linux capability set from capabilities(7).
    Enumerated in capability number order (0–40). -/
inductive Capability where
  /-- (0) Make arbitrary changes to file UIDs and GIDs. -/
  | CAP_CHOWN
  /-- (1) Bypass file read, write, and execute permission checks. -/
  | CAP_DAC_OVERRIDE
  /-- (2) Bypass file read permission checks and directory read/execute. -/
  | CAP_DAC_READ_SEARCH
  /-- (3) Bypass permission checks on operations requiring FS UID match. -/
  | CAP_FOWNER
  /-- (4) Don't clear set-user-ID and set-group-ID mode bits on file modification. -/
  | CAP_FSETID
  /-- (5) Bypass permission checks for sending signals. -/
  | CAP_KILL
  /-- (6) Make arbitrary manipulations of process GIDs. -/
  | CAP_SETGID
  /-- (7) Make arbitrary manipulations of process UIDs. -/
  | CAP_SETUID
  /-- (8) Modify process capability bounding set; drop caps from ambient set. -/
  | CAP_SETPCAP
  /-- (9) Set immutable and append-only file attributes. -/
  | CAP_LINUX_IMMUTABLE
  /-- (10) Bind a socket to privileged ports (< 1024). -/
  | CAP_NET_BIND_SERVICE
  /-- (11) Make socket broadcasts and listen to multicasts. -/
  | CAP_NET_BROADCAST
  /-- (12) Perform various network-related operations (interface config, routing, etc.). -/
  | CAP_NET_ADMIN
  /-- (13) Use RAW and PACKET sockets; bind to any address for transparent proxying. -/
  | CAP_NET_RAW
  /-- (14) Lock memory (mlock, mlockall, mmap MAP_LOCKED, shmctl SHM_LOCK). -/
  | CAP_IPC_LOCK
  /-- (15) Bypass permission checks for IPC operations. -/
  | CAP_IPC_OWNER
  /-- (16) Load and unload kernel modules. -/
  | CAP_SYS_MODULE
  /-- (17) Perform I/O port operations (iopl, ioperm). -/
  | CAP_SYS_RAWIO
  /-- (18) Use chroot(2). -/
  | CAP_SYS_CHROOT
  /-- (19) Trace arbitrary processes using ptrace(2). -/
  | CAP_SYS_PTRACE
  /-- (20) Use acct(2) to enable/disable process accounting. -/
  | CAP_SYS_PACCT
  /-- (21) Perform system administration operations. -/
  | CAP_SYS_ADMIN
  /-- (22) Use reboot(2) and kexec_load(2). -/
  | CAP_SYS_BOOT
  /-- (23) Set nice/scheduling, set CPU affinity, I/O scheduling. -/
  | CAP_SYS_NICE
  /-- (24) Override resource limits (setrlimit, ulimit). -/
  | CAP_SYS_RESOURCE
  /-- (25) Set system clock (settimeofday, adjtimex); set real-time clock. -/
  | CAP_SYS_TIME
  /-- (26) Use vhangup(2); various privileged ioctl operations on virtual terminals. -/
  | CAP_SYS_TTY_CONFIG
  /-- (27) Create special files using mknod(2). -/
  | CAP_MKNOD
  /-- (28) Establish leases on files (fcntl F_SETLEASE). -/
  | CAP_LEASE
  /-- (29) Write records to kernel auditing log. -/
  | CAP_AUDIT_WRITE
  /-- (30) Enable/disable kernel auditing; change auditing filter rules. -/
  | CAP_AUDIT_CONTROL
  /-- (31) Set arbitrary capabilities on a file. -/
  | CAP_SETFCAP
  /-- (32) Override MAC (Smack/AppArmor). -/
  | CAP_MAC_OVERRIDE
  /-- (33) Allow MAC configuration or state changes (Smack/AppArmor). -/
  | CAP_MAC_ADMIN
  /-- (34) Use syslog(2); read kernel log via /dev/kmsg. -/
  | CAP_SYSLOG
  /-- (35) Trigger something that will wake up the system (set CLOCK_REALTIME_ALARM). -/
  | CAP_WAKE_ALARM
  /-- (36) Employ features that can block system suspend. -/
  | CAP_BLOCK_SUSPEND
  /-- (37) Allow reading the audit log via multicast netlink socket. -/
  | CAP_AUDIT_READ
  /-- (38) Employ privileged perf/BPF operations (since Linux 5.8). -/
  | CAP_PERFMON
  /-- (39) Employ privileged BPF operations (since Linux 5.8). -/
  | CAP_BPF
  /-- (40) Checkpoint/restore (since Linux 5.9). -/
  | CAP_CHECKPOINT_RESTORE
  deriving DecidableEq, Repr, Inhabited

instance : ToString Capability where
  toString
    | .CAP_CHOWN => "CAP_CHOWN"
    | .CAP_DAC_OVERRIDE => "CAP_DAC_OVERRIDE"
    | .CAP_DAC_READ_SEARCH => "CAP_DAC_READ_SEARCH"
    | .CAP_FOWNER => "CAP_FOWNER"
    | .CAP_FSETID => "CAP_FSETID"
    | .CAP_KILL => "CAP_KILL"
    | .CAP_SETGID => "CAP_SETGID"
    | .CAP_SETUID => "CAP_SETUID"
    | .CAP_SETPCAP => "CAP_SETPCAP"
    | .CAP_LINUX_IMMUTABLE => "CAP_LINUX_IMMUTABLE"
    | .CAP_NET_BIND_SERVICE => "CAP_NET_BIND_SERVICE"
    | .CAP_NET_BROADCAST => "CAP_NET_BROADCAST"
    | .CAP_NET_ADMIN => "CAP_NET_ADMIN"
    | .CAP_NET_RAW => "CAP_NET_RAW"
    | .CAP_IPC_LOCK => "CAP_IPC_LOCK"
    | .CAP_IPC_OWNER => "CAP_IPC_OWNER"
    | .CAP_SYS_MODULE => "CAP_SYS_MODULE"
    | .CAP_SYS_RAWIO => "CAP_SYS_RAWIO"
    | .CAP_SYS_CHROOT => "CAP_SYS_CHROOT"
    | .CAP_SYS_PTRACE => "CAP_SYS_PTRACE"
    | .CAP_SYS_PACCT => "CAP_SYS_PACCT"
    | .CAP_SYS_ADMIN => "CAP_SYS_ADMIN"
    | .CAP_SYS_BOOT => "CAP_SYS_BOOT"
    | .CAP_SYS_NICE => "CAP_SYS_NICE"
    | .CAP_SYS_RESOURCE => "CAP_SYS_RESOURCE"
    | .CAP_SYS_TIME => "CAP_SYS_TIME"
    | .CAP_SYS_TTY_CONFIG => "CAP_SYS_TTY_CONFIG"
    | .CAP_MKNOD => "CAP_MKNOD"
    | .CAP_LEASE => "CAP_LEASE"
    | .CAP_AUDIT_WRITE => "CAP_AUDIT_WRITE"
    | .CAP_AUDIT_CONTROL => "CAP_AUDIT_CONTROL"
    | .CAP_SETFCAP => "CAP_SETFCAP"
    | .CAP_MAC_OVERRIDE => "CAP_MAC_OVERRIDE"
    | .CAP_MAC_ADMIN => "CAP_MAC_ADMIN"
    | .CAP_SYSLOG => "CAP_SYSLOG"
    | .CAP_WAKE_ALARM => "CAP_WAKE_ALARM"
    | .CAP_BLOCK_SUSPEND => "CAP_BLOCK_SUSPEND"
    | .CAP_AUDIT_READ => "CAP_AUDIT_READ"
    | .CAP_PERFMON => "CAP_PERFMON"
    | .CAP_BPF => "CAP_BPF"
    | .CAP_CHECKPOINT_RESTORE => "CAP_CHECKPOINT_RESTORE"

/-- Check if a capability allows filesystem operations. -/
def Capability.isFilesystemCap : Capability → Bool
  | .CAP_CHOWN => true
  | .CAP_DAC_OVERRIDE => true
  | .CAP_DAC_READ_SEARCH => true
  | .CAP_FOWNER => true
  | .CAP_FSETID => true
  | .CAP_LINUX_IMMUTABLE => true
  | .CAP_SYS_CHROOT => true
  | .CAP_MKNOD => true
  | .CAP_LEASE => true
  | _ => false

/-- Check if a capability allows process manipulation. -/
def Capability.isProcessCap : Capability → Bool
  | .CAP_KILL => true
  | .CAP_SETGID => true
  | .CAP_SETUID => true
  | .CAP_SETPCAP => true
  | .CAP_SYS_PTRACE => true
  | .CAP_SYS_PACCT => true
  | .CAP_SYS_NICE => true
  | _ => false

/-- Check if a capability allows network operations. -/
def Capability.isNetworkCap : Capability → Bool
  | .CAP_NET_BIND_SERVICE => true
  | .CAP_NET_BROADCAST => true
  | .CAP_NET_ADMIN => true
  | .CAP_NET_RAW => true
  | _ => false

/-- Check if a capability allows system administration. -/
def Capability.isSysAdminCap : Capability → Bool
  | .CAP_SYS_ADMIN => true
  | .CAP_SYS_RAWIO => true
  | .CAP_SYS_MODULE => true
  | .CAP_SYS_TIME => true
  | .CAP_SYS_RESOURCE => true
  | .CAP_SYS_TTY_CONFIG => true
  | .CAP_SYSLOG => true
  | .CAP_SYS_BOOT => true
  | _ => false

/-- The empty capability set. -/
def CapabilitySet : Type := Array Capability

/-- Check if a capability set contains a specific capability. -/
def CapabilitySet.contains (set : CapabilitySet) (cap : Capability) : Bool :=
  Array.contains set cap

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
