import SWELib.OS.Cgroups.Types
import SWELib.OS.Cgroups.Operations
import SWELib.OS.Cgroups.Invariants

/-!
# Control Groups (cgroups)

Cgroup types, operations, and invariants for container resource limits.

References:
- cgroups(7): https://man7.org/linux/man-pages/man7/cgroups.7.html
- cgroup-v2: https://docs.kernel.org/admin-guide/cgroup-v2.html
-/

namespace SWELib.OS


/-- The root cgroup. -/
def Cgroup.root : Cgroup := ⟨"/"⟩

/-- Join two cgroup paths. -/
def Cgroup.join (parent child : Cgroup) : Cgroup :=
  if parent.path = "/" then
    ⟨"/" ++ child.path⟩
  else
    ⟨parent.path ++ "/" ++ child.path⟩

/-- Get the parent cgroup path. -/
def Cgroup.parent (cg : Cgroup) : Option Cgroup :=
  if cg.path = "/" then
    none
  else
    match cg.path.splitOn "/" with
    | [] => none
    | [_] => some ⟨"/"⟩
    | parts =>
      let parentParts := parts.take (parts.length - 1)
      let parentPath := String.intercalate "/" parentParts
      if parentPath = "" then some ⟨"/"⟩ else some ⟨parentPath⟩

end SWELib.OS
