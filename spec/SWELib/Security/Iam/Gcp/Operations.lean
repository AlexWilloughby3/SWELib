import SWELib.Security.Iam.Gcp.Types

/-!
# GCP IAM Operations

Policy evaluation functions for Google Cloud Platform IAM.
Implements the three-stage evaluation: PAB check, deny evaluation, allow evaluation.

Reference: https://cloud.google.com/iam/docs/policy-evaluation
-/

namespace SWELib.Security.Iam.Gcp

/-! ## CEL condition abstraction -/

/-- Axiom: evaluate a CEL condition expression against request attributes. -/
axiom gcpEvalCondition : Option ConditionExpression → List (String × String) → ConditionResult

/-- When no condition is present, evaluation is always satisfied. -/
axiom gcpEvalCondition_none : ∀ (attrs : List (String × String)),
    gcpEvalCondition none attrs = ConditionResult.satisfied

/-! ## Permission matching -/

/-- Split a string on the first occurrence of a separator string, returning none if not found. -/
private def splitOnFirst (s : String) (sep : String) : Option (String × String) :=
  match s.splitOn sep with
  | [_] => none
  | first :: rest => some (first, sep.intercalate rest)
  | [] => none

/-- Concrete glob matching for GCP permissions.
A pattern `p` matches a concrete permission `q` using service/resource.verb structure. -/
def gcpPermissionMatches (p q : GcpPermission) : Bool :=
  if p == q then true
  else
    match splitOnFirst p "/", splitOnFirst q "/" with
    | some (pService, pRest), some (qService, qRest) =>
      if pService != qService then false
      else if pRest == "*.*" then true
      else
        match splitOnFirst pRest ".", splitOnFirst qRest "." with
        | some (pResource, pVerb), some (qResource, qVerb) =>
          (pResource == "*" && pVerb == qVerb) ||
          (pVerb == "*" && pResource == qResource)
        | _, _ => false
    | _, _ => false

/-- Pattern matching for GCP principals.
`AllUsers` matches any principal; `AllAuthenticatedUsers` matches any except `AllUsers`. -/
def gcpPrincipalMatches (policyPrincipal requestPrincipal : GcpPrincipal) : Bool :=
  match policyPrincipal with
  | .AllUsers => true
  | .AllAuthenticatedUsers =>
    match requestPrincipal with
    | .AllUsers => false
    | _ => true
  | other => other == requestPrincipal

/-! ## Binding and deny rule evaluation -/

/-- True if a binding applies to the given request context. -/
noncomputable def gcpBindingAppliesToRequest (binding : GcpBinding) (ctx : GcpPolicyContext) : Bool :=
  binding.members.any (gcpPrincipalMatches · ctx.principal) &&
  binding.role.permissions.any (gcpPermissionMatches · ctx.permission) &&
  (gcpEvalCondition binding.condition ctx.requestAttributes == ConditionResult.satisfied)

/-- True if a deny rule applies to the given request context. -/
noncomputable def gcpDenyRuleAppliesToRequest (rule : GcpDenyRule) (ctx : GcpPolicyContext) : Bool :=
  rule.deniedPrincipals.any (gcpPrincipalMatches · ctx.principal) &&
  !(rule.exceptionPrincipals.any (gcpPrincipalMatches · ctx.principal)) &&
  rule.deniedPermissions.any (gcpPermissionMatches · ctx.permission) &&
  !(rule.exceptionPermissions.any (gcpPermissionMatches · ctx.permission)) &&
  (let cr := gcpEvalCondition rule.denialCondition ctx.requestAttributes
   cr == ConditionResult.satisfied || cr == ConditionResult.unevaluable)

/-! ## Policy lookup and collection -/

/-- Linear lookup of policies for a resource node in the policy store. -/
def gcpLookupNodePolicies (node : GcpResourceNode) (store : GcpPolicyStore) : Option GcpResourcePolicies :=
  match store.nodePolicies.find? (fun pair => pair.1 == node) with
  | some (_, policies) => some policies
  | none => none

/-- Axiom: collect the ancestor path for a resource node from the policy store. -/
axiom gcpCollectAncestorPath : GcpResourceNode → GcpPolicyStore → GcpHierarchyPath

/-- Collect all allow policies along a hierarchy path. -/
def gcpEffectiveAllowPolicies (path : GcpHierarchyPath) (store : GcpPolicyStore) : List GcpAllowPolicy :=
  path.filterMap (fun node => (gcpLookupNodePolicies node store).map (·.allowPolicy))

/-- Collect all deny policies along a hierarchy path. -/
def gcpEffectiveDenyPolicies (path : GcpHierarchyPath) (store : GcpPolicyStore) : List GcpDenyPolicy :=
  (path.filterMap (fun node => (gcpLookupNodePolicies node store).map (·.denyPolicies))).flatten

/-! ## Principal Access Boundary -/

/-- Look up PAB policies bound to a principal in the store. Returns [] if none are registered. -/
def gcpLookupPrincipalPabs (principal : GcpPrincipal) (store : GcpPolicyStore) :
    List GcpPrincipalAccessBoundaryPolicy :=
  match store.principalPabs.find? (fun pair => pair.1 == principal) with
  | some (_, pabs) => pabs
  | none           => []

/-- Evaluate whether a resource is within the principal's PAB-restricted scope.
If no PABs are bound to the principal, access is unrestricted. Otherwise, at least one PAB
must list the resource as eligible. -/
def gcpEvaluatePab (resource : GcpResourceNode)
    (pabs : List GcpPrincipalAccessBoundaryPolicy) : Bool :=
  if pabs.isEmpty then true
  else pabs.any (fun pab => pab.eligibleResources.any (· == resource))

/-! ## Top-level request evaluation -/

/-- Three-stage GCP IAM policy evaluation:
1. PAB check (PABs looked up from store by ctx.principal)
2. Deny policy evaluation
3. Allow policy evaluation
Default: implicit deny. -/
noncomputable def gcpEvaluateRequest (ctx : GcpPolicyContext) (store : GcpPolicyStore) : AccessDecision :=
  let pabs := gcpLookupPrincipalPabs ctx.principal store
  if gcpEvaluatePab ctx.resource pabs == false then
    AccessDecision.explicitDeny
  else
    let path := gcpCollectAncestorPath ctx.resource store
    if (gcpEffectiveDenyPolicies path store).any (fun dp => dp.rules.any (fun rule => gcpDenyRuleAppliesToRequest rule ctx)) then
      AccessDecision.explicitDeny
    else if (gcpEffectiveAllowPolicies path store).any (fun ap => ap.bindings.any (fun b => gcpBindingAppliesToRequest b ctx)) then
      AccessDecision.explicitAllow
    else
      AccessDecision.implicitDeny

end SWELib.Security.Iam.Gcp
