import SWELib.Security.Iam.Gcp.Types
import SWELib.Security.Iam.Gcp.Operations

/-!
# GCP IAM Invariants

Theorem statements capturing key properties of GCP IAM policy evaluation,
plus concrete examples demonstrating the operations.

Reference: https://cloud.google.com/iam/docs/overview
-/

namespace SWELib.Security.Iam.Gcp

-- STRUCTURAL: closes by unfolding gcpEvaluateRequest and simp on boolean conditions
theorem inv1_deny_before_allow
    (ctx : GcpPolicyContext) (store : GcpPolicyStore)
    (h_pab : gcpEvaluatePab ctx.resource (gcpLookupPrincipalPabs ctx.principal store) = true)
    (h_deny : (gcpEffectiveDenyPolicies (gcpCollectAncestorPath ctx.resource store) store).any
                (fun dp => dp.rules.any (fun rule => gcpDenyRuleAppliesToRequest rule ctx)) = true) :
    gcpEvaluateRequest ctx store = AccessDecision.explicitDeny := by
  unfold gcpEvaluateRequest
  simp [h_pab, h_deny]

-- STRUCTURAL: consequence of inv1
theorem inv2_deny_overrides_allow
    (ctx : GcpPolicyContext) (store : GcpPolicyStore)
    (h_pab : gcpEvaluatePab ctx.resource (gcpLookupPrincipalPabs ctx.principal store) = true)
    (h_deny : (gcpEffectiveDenyPolicies (gcpCollectAncestorPath ctx.resource store) store).any
                (fun dp => dp.rules.any (fun rule => gcpDenyRuleAppliesToRequest rule ctx)) = true) :
    gcpEvaluateRequest ctx store ≠ AccessDecision.explicitAllow := by
  rw [inv1_deny_before_allow ctx store h_pab h_deny]
  decide

-- STRUCTURAL: direct unfolding of gcpDenyRuleAppliesToRequest
theorem inv3_exception_principal_blocks_deny
    (rule : GcpDenyRule) (ctx : GcpPolicyContext)
    (h_exception : rule.exceptionPrincipals.any (gcpPrincipalMatches · ctx.principal) = true) :
    gcpDenyRuleAppliesToRequest rule ctx = false := by
  unfold gcpDenyRuleAppliesToRequest
  simp [h_exception]

-- REQUIRES_HUMAN: depends on gcpEvalCondition axiom structure
-- Allow side: unevaluable condition means binding does not apply
theorem inv4a_allow_unevaluable_not_applies
    (binding : GcpBinding) (ctx : GcpPolicyContext)
    (h_cond : gcpEvalCondition binding.condition ctx.requestAttributes = ConditionResult.unevaluable) :
    gcpBindingAppliesToRequest binding ctx = false := by
  unfold gcpBindingAppliesToRequest
  simp [h_cond]

-- REQUIRES_HUMAN: depends on gcpEvalCondition axiom structure
-- Deny side: unevaluable condition means deny applies (given principal and permission match)
theorem inv4b_deny_unevaluable_applies
    (rule : GcpDenyRule) (ctx : GcpPolicyContext)
    (h_principal : rule.deniedPrincipals.any (gcpPrincipalMatches · ctx.principal) = true)
    (h_not_exc_principal : rule.exceptionPrincipals.any (gcpPrincipalMatches · ctx.principal) = false)
    (h_permission : rule.deniedPermissions.any (gcpPermissionMatches · ctx.permission) = true)
    (h_not_exc_perm : rule.exceptionPermissions.any (gcpPermissionMatches · ctx.permission) = false)
    (h_cond : gcpEvalCondition rule.denialCondition ctx.requestAttributes = ConditionResult.unevaluable) :
    gcpDenyRuleAppliesToRequest rule ctx = true := by
  unfold gcpDenyRuleAppliesToRequest
  simp [h_principal, h_not_exc_principal, h_permission, h_not_exc_perm, h_cond]

-- ALGEBRAIC: membership preservation over filterMap + List.any
theorem inv5_allow_union
    (path : GcpHierarchyPath) (store : GcpPolicyStore) (ctx : GcpPolicyContext)
    (node : GcpResourceNode) (h_mem : node ∈ path)
    (policies : GcpResourcePolicies) (h_lookup : gcpLookupNodePolicies node store = some policies)
    (binding : GcpBinding) (h_binding : binding ∈ policies.allowPolicy.bindings)
    (h_applies : gcpBindingAppliesToRequest binding ctx = true) :
    (gcpEffectiveAllowPolicies path store).any
      (fun ap => ap.bindings.any (fun b => gcpBindingAppliesToRequest b ctx)) = true := by
  apply List.any_eq_true.mpr
  refine ⟨policies.allowPolicy, ?_, ?_⟩
  · unfold gcpEffectiveAllowPolicies
    exact List.mem_filterMap.mpr ⟨node, h_mem, by simp [h_lookup]⟩
  · apply List.any_eq_true.mpr
    exact ⟨binding, h_binding, h_applies⟩

-- ALGEBRAIC: parent deny appears in effective deny set via gcpCollectAncestorPath
theorem inv6_parent_deny_affects_child
    (ctx : GcpPolicyContext) (store : GcpPolicyStore)
    (path : GcpHierarchyPath)
    (h_path : gcpCollectAncestorPath ctx.resource store = path)
    (h_pab : gcpEvaluatePab ctx.resource (gcpLookupPrincipalPabs ctx.principal store) = true)
    (h_deny : (gcpEffectiveDenyPolicies path store).any
                (fun dp => dp.rules.any (fun rule => gcpDenyRuleAppliesToRequest rule ctx)) = true) :
    gcpEvaluateRequest ctx store = AccessDecision.explicitDeny := by
  rw [← h_path] at h_deny
  exact inv1_deny_before_allow ctx store h_pab h_deny

-- STRUCTURAL: direct unfolding of gcpEvaluateRequest stage 1
theorem inv7_pab_fail_closed
    (ctx : GcpPolicyContext) (store : GcpPolicyStore)
    (h_pab_nonempty : gcpLookupPrincipalPabs ctx.principal store ≠ [])
    (h_not_eligible : (gcpLookupPrincipalPabs ctx.principal store).any
        (fun p => p.eligibleResources.any (· == ctx.resource)) = false) :
    gcpEvaluateRequest ctx store = AccessDecision.explicitDeny := by
  unfold gcpEvaluateRequest
  unfold gcpEvaluatePab
  simp [List.isEmpty_iff, h_pab_nonempty, h_not_eligible]

-- STRUCTURAL: reduces to gcpEvalCondition_none axiom
theorem inv8_unconditional_binding_applies
    (binding : GcpBinding) (ctx : GcpPolicyContext)
    (h_no_cond : binding.condition = none)
    (h_principal : binding.members.any (gcpPrincipalMatches · ctx.principal) = true)
    (h_permission : binding.role.permissions.any (gcpPermissionMatches · ctx.permission) = true) :
    gcpBindingAppliesToRequest binding ctx = true := by
  unfold gcpBindingAppliesToRequest
  simp [h_no_cond, h_principal, h_permission, gcpEvalCondition_none]

-- STRUCTURAL: direct unfolding of gcpEvaluateRequest stage 3 else-branch
theorem inv9_no_allow_means_implicit_deny
    (ctx : GcpPolicyContext) (store : GcpPolicyStore)
    (h_pab_ok : gcpEvaluatePab ctx.resource (gcpLookupPrincipalPabs ctx.principal store) = true)
    (h_no_deny : (gcpEffectiveDenyPolicies (gcpCollectAncestorPath ctx.resource store) store).any
                   (fun dp => dp.rules.any (fun rule => gcpDenyRuleAppliesToRequest rule ctx)) = false)
    (h_no_allow : (gcpEffectiveAllowPolicies (gcpCollectAncestorPath ctx.resource store) store).any
                    (fun ap => ap.bindings.any (fun b => gcpBindingAppliesToRequest b ctx)) = false) :
    gcpEvaluateRequest ctx store = AccessDecision.implicitDeny := by
  unfold gcpEvaluateRequest
  simp [h_pab_ok, h_no_deny, h_no_allow]

/-! ## Concrete examples -/

/-- EX-1: Deny rule applies when principal and permission match with no condition. -/
example : gcpDenyRuleAppliesToRequest
    { deniedPrincipals := [GcpPrincipal.User "alice@example.com"]
      deniedPermissions := ["storage.googleapis.com/objects.delete"]
      exceptionPrincipals := []
      exceptionPermissions := []
      denialCondition := none }
    { principal := GcpPrincipal.User "alice@example.com"
      permission := "storage.googleapis.com/objects.delete"
      resource := GcpResourceNode.Project "my-project"
      requestAttributes := [] } = true := by
  unfold gcpDenyRuleAppliesToRequest
  simp [gcpPrincipalMatches, gcpPermissionMatches]
  rw [gcpEvalCondition_none]
  decide

/-- EX-2: Exception principal blocks a deny rule. -/
example : gcpDenyRuleAppliesToRequest
    { deniedPrincipals := [GcpPrincipal.User "alice@example.com"]
      deniedPermissions := ["storage.googleapis.com/objects.delete"]
      exceptionPrincipals := [GcpPrincipal.User "alice@example.com"]
      exceptionPermissions := []
      denialCondition := none }
    { principal := GcpPrincipal.User "alice@example.com"
      permission := "storage.googleapis.com/objects.delete"
      resource := GcpResourceNode.Project "my-project"
      requestAttributes := [] } = false := by
  unfold gcpDenyRuleAppliesToRequest
  simp [gcpPrincipalMatches]

/-- EX-6: Wildcard permission matching on verb. -/
example : gcpPermissionMatches "storage.googleapis.com/objects.*" "storage.googleapis.com/objects.create" = true := by
  native_decide

end SWELib.Security.Iam.Gcp
