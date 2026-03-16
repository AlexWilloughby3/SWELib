/-!
# GCP IAM Types

Core types for modeling Google Cloud Platform Identity and Access Management (IAM).
Covers resource hierarchy, principals, permissions, roles, bindings, allow/deny policies,
and Principal Access Boundary (PAB) policies.

Reference: https://cloud.google.com/iam/docs/overview
-/

namespace SWELib.Security.Iam.Gcp

/-- Result of evaluating a CEL condition expression. -/
inductive ConditionResult
  | satisfied
  | refuted
  | unevaluable
  deriving DecidableEq, Repr

/-- The access decision returned by GCP IAM policy evaluation. -/
inductive AccessDecision
  | explicitAllow
  | explicitDeny
  | implicitDeny
  deriving DecidableEq, Repr

/-- Policy effect (allow or deny). -/
inductive Effect
  | allow
  | deny
  deriving DecidableEq, Repr

/-- A node in the GCP resource hierarchy. -/
inductive GcpResourceNode
  | Organization (orgId : String)
  | Folder (folderId : String)
  | Project (projectId : String)
  | Resource (resourceName : String)
  deriving DecidableEq, Repr

/-- A path through the GCP resource hierarchy from a resource up to the organization. -/
abbrev GcpHierarchyPath := List GcpResourceNode

/-- A GCP principal (identity). -/
inductive GcpPrincipal
  | User (email : String)
  | ServiceAccount (email : String)
  | Group (email : String)
  | Domain (domain : String)
  | AllUsers
  | AllAuthenticatedUsers
  | Deleted (principalType : String) (identifier : String) (uid : String)
  deriving DecidableEq, Repr

/-- A GCP permission string (e.g., "storage.googleapis.com/objects.create"). -/
abbrev GcpPermission := String

/-- A CEL condition expression string. -/
abbrev ConditionExpression := String

/-- A GCP IAM role with its name and associated permissions. -/
structure GcpRole where
  name : String
  permissions : List GcpPermission
  deriving DecidableEq, Repr

/-- A binding of a role to a set of principals, optionally conditioned. -/
structure GcpBinding where
  role : GcpRole
  members : List GcpPrincipal
  condition : Option ConditionExpression
  deriving DecidableEq, Repr

/-- An allow policy attached to a resource node. -/
structure GcpAllowPolicy where
  bindings : List GcpBinding
  version : Nat
  deriving DecidableEq, Repr

/-- A deny rule within a deny policy. -/
structure GcpDenyRule where
  deniedPrincipals : List GcpPrincipal
  deniedPermissions : List GcpPermission
  exceptionPrincipals : List GcpPrincipal
  exceptionPermissions : List GcpPermission
  denialCondition : Option ConditionExpression
  deriving DecidableEq, Repr

/-- A deny policy attached to a resource node. -/
structure GcpDenyPolicy where
  name : String
  rules : List GcpDenyRule
  deriving DecidableEq, Repr

/-- A Principal Access Boundary (PAB) policy. -/
structure GcpPrincipalAccessBoundaryPolicy where
  eligibleResources : List GcpResourceNode
  deriving DecidableEq, Repr

/-- Context for a single IAM access request. -/
structure GcpPolicyContext where
  principal : GcpPrincipal
  permission : GcpPermission
  resource : GcpResourceNode
  requestAttributes : List (String × String)
  deriving Repr

/-- Allow and deny policies attached to a single resource node. -/
structure GcpResourcePolicies where
  allowPolicy : GcpAllowPolicy
  denyPolicies : List GcpDenyPolicy
  deriving Repr

/-- The full policy store: per-node policies and per-principal PABs. -/
structure GcpPolicyStore where
  nodePolicies : List (GcpResourceNode × GcpResourcePolicies)
  principalPabs : List (GcpPrincipal × List GcpPrincipalAccessBoundaryPolicy)
  deriving Repr

end SWELib.Security.Iam.Gcp
