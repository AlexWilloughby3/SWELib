import SWELib.OS.Namespaces.Types
import SWELib.OS.Namespaces.Operations
import SWELib.OS.Namespaces.Invariants

/-!
# Linux Namespaces

Linux namespace types and operations for process isolation.

References:
- namespaces(7): https://man7.org/linux/man-pages/man7/namespaces.7.html
- clone(2): https://man7.org/linux/man-pages/man2/clone.2.html
- unshare(2): https://man7.org/linux/man-pages/man2/unshare.2.html
- setns(2): https://man7.org/linux/man-pages/man2/setns.2.html
-/

namespace SWELib.OS


/-- All namespace types as a list. -/
def Namespace.all : List Namespace :=
  [.pid, .network, .mount, .ipc, .uts, .user, .cgroup, .time]

/-- Check if a namespace provides filesystem isolation. -/
def Namespace.isFilesystemIsolated : Namespace → Bool
  | .mount => true
  | .user => true  -- user namespace can affect filesystem permissions
  | _ => false

/-- Check if a namespace provides network isolation. -/
def Namespace.isNetworkIsolated : Namespace → Bool
  | .network => true
  | _ => false

/-- Check if a namespace provides process ID isolation. -/
def Namespace.isPidIsolated : Namespace → Bool
  | .pid => true
  | _ => false

end SWELib.OS
