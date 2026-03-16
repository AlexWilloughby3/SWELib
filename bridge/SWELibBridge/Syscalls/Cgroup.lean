import SWELib
import SWELib.OS.Cgroups.Types
import SWELib.OS.Cgroups.Operations
import SWELib.OS.Cgroups.Invariants

/-!
# Cgroup

Bridge axioms for Cgroup syscalls/operations.
-/


namespace SWELibBridge.Syscalls

-- TRUST: External implementation satisfies cgroup specification
-- Bridge axioms for cgroup operations

/-- Axiom: cgroup_create implementation. -/
axiom cgroup_create_impl (parent : Cgroup) (name : String) : Except CgroupError Cgroup

/-- Axiom: cgroup_delete implementation. -/
axiom cgroup_delete_impl (cg : Cgroup) : Except CgroupError Unit

/-- Axiom: cgroup_move_process implementation. -/
axiom cgroup_move_process_impl (cg : Cgroup) (pid : PID) : Except CgroupError Unit

/-- Axiom: cgroup_set_limit implementation. -/
axiom cgroup_set_limit_impl (cg : Cgroup) (controller : CgroupController)
  (limit : CgroupLimit) : Except CgroupError Unit

/-- Axiom: cgroup_get_usage implementation. -/
axiom cgroup_get_usage_impl (cg : Cgroup) (controller : CgroupController)
  : Except CgroupError Nat

/-- Axiom: cgroup_enable_controller implementation. -/
axiom cgroup_enable_controller_impl (cg : Cgroup) (controller : CgroupController)
  : Except CgroupError Unit

/-- Bridge theorem: cgroup_create matches specification. -/
theorem cgroup_create_bridge (parent : Cgroup) (name : String) :
  cgroup_create parent name = cgroup_create_impl parent name :=
  by rfl

/-- Bridge theorem: cgroup_delete matches specification. -/
theorem cgroup_delete_bridge (cg : Cgroup) :
  cgroup_delete cg = cgroup_delete_impl cg :=
  by rfl

/-- Bridge theorem: cgroup_move_process matches specification. -/
theorem cgroup_move_process_bridge (cg : Cgroup) (pid : PID) :
  cgroup_move_process cg pid = cgroup_move_process_impl cg pid :=
  by rfl

/-- Bridge theorem: cgroup_set_limit matches specification. -/
theorem cgroup_set_limit_bridge (cg : Cgroup) (controller : CgroupController)
  (limit : CgroupLimit) :
  cgroup_set_limit cg controller limit = cgroup_set_limit_impl cg controller limit :=
  by rfl

/-- Bridge theorem: cgroup_get_usage matches specification. -/
theorem cgroup_get_usage_bridge (cg : Cgroup) (controller : CgroupController) :
  cgroup_get_usage cg controller = cgroup_get_usage_impl cg controller :=
  by rfl

/-- Bridge theorem: cgroup_enable_controller matches specification. -/
theorem cgroup_enable_controller_bridge (cg : Cgroup) (controller : CgroupController) :
  cgroup_enable_controller cg controller = cgroup_enable_controller_impl cg controller :=
  by rfl

/-- Axiom: Cgroup tree structure property. -/
axiom cgroup_tree_structure_axiom (cg1 cg2 : Cgroup) :
  cg1.path.startsWith cg2.path ∨ cg2.path.startsWith cg1.path ∨
  (¬ cg1.path.startsWith cg2.path ∧ ¬ cg2.path.startsWith cg1.path)

/-- Axiom: Single membership property. -/
axiom single_membership_axiom (pid : PID) (cg1 cg2 : Cgroup)
  (h1 : pid_in_cgroup pid cg1) (h2 : pid_in_cgroup pid cg2) :
  cg1 = cg2

/-- Axiom: Memory limit OOM property. -/
axiom memory_limit_oom_axiom (cg : Cgroup) (limit : Nat)
  (h : cgroup_set_limit cg .memory (CgroupLimit.memory limit) = .ok ())
  (h2 : cgroup_get_usage cg .memory ≥ limit) :
  oom_killer_invoked cg

/-- Axiom: PID limit enforcement property. -/
axiom pid_limit_enforcement_axiom (cg : Cgroup) (limit : Nat)
  (h : cgroup_set_limit cg .pids (CgroupLimit.pidCount limit) = .ok ())
  (h2 : current_pid_count cg ≥ limit) :
  fork_would_fail_with_EAGAIN cg

end SWELibBridge.Syscalls
