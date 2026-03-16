import SWELib.OS.FileSystem

/-!
# Users and Permissions

POSIX user/group identity model and permission checking.

References:
- getuid(2):  https://man7.org/linux/man-pages/man2/getuid.2.html
- geteuid(2): https://man7.org/linux/man-pages/man2/geteuid.2.html
- credentials(7): https://man7.org/linux/man-pages/man7/credentials.7.html
-/

namespace SWELib.OS

/-! ## Identity types -/

/-- A POSIX user ID (uid_t). -/
structure UserId where
  uid : Nat
  deriving DecidableEq, Repr

/-- A POSIX group ID (gid_t). -/
structure GroupId where
  gid : Nat
  deriving DecidableEq, Repr

/-- The root user has uid 0. -/
def UserId.root : UserId := ⟨0⟩

/-- The root group has gid 0. -/
def GroupId.root : GroupId := ⟨0⟩

/-- Process credentials: real and effective user/group IDs. -/
structure UserCredentials where
  /-- Real user ID (who launched the process). -/
  ruid : UserId
  /-- Effective user ID (used for permission checks). -/
  euid : UserId
  /-- Real group ID. -/
  rgid : GroupId
  /-- Effective group ID. -/
  egid : GroupId
  deriving Repr

/-! ## Permission checking -/

/-- Which access is being requested. -/
inductive AccessRequest where
  | read
  | write
  | exec
  deriving DecidableEq, Repr

/-- Check whether a single permission bit grants the requested access. -/
def PermissionBits.grants (pb : PermissionBits) (req : AccessRequest) : Bool :=
  match req with
  | .read  => pb.read
  | .write => pb.write
  | .exec  => pb.exec

/-- Check whether `creds` can perform `req` on a file with the given `stat`.
    Follows the POSIX algorithm:
    1. euid = 0 (root) ⟹ always granted
    2. euid = file owner ⟹ check owner bits
    3. egid = file group ⟹ check group bits
    4. otherwise ⟹ check other bits -/
def checkPermission (creds : UserCredentials) (stat : FileStat)
    (req : AccessRequest) : Bool :=
  if creds.euid.uid = 0 then true
  else if creds.euid.uid = stat.uid then stat.permissions.owner.grants req
  else if creds.egid.gid = stat.gid then stat.permissions.group.grants req
  else stat.permissions.other.grants req

/-! ## Theorems -/

/-- Root (euid=0) bypasses all permission checks. -/
theorem root_bypasses_permission (creds : UserCredentials) (stat : FileStat)
    (req : AccessRequest) (h : creds.euid.uid = 0) :
    checkPermission creds stat req = true := by
  simp [checkPermission, h]

/-- When euid matches the file owner and owner.read is set, read is granted. -/
theorem owner_read_check (creds : UserCredentials) (stat : FileStat)
    (_h_not_root : creds.euid.uid ≠ 0)
    (h_owner : creds.euid.uid = stat.uid)
    (h_read : stat.permissions.owner.read = true) :
    checkPermission creds stat .read = true := by
  simp [checkPermission, h_owner, PermissionBits.grants, h_read]

/-- When euid matches the file owner and owner.write is set, write is granted. -/
theorem owner_write_check (creds : UserCredentials) (stat : FileStat)
    (_h_not_root : creds.euid.uid ≠ 0)
    (h_owner : creds.euid.uid = stat.uid)
    (h_write : stat.permissions.owner.write = true) :
    checkPermission creds stat .write = true := by
  simp [checkPermission, h_owner, PermissionBits.grants, h_write]

end SWELib.OS
