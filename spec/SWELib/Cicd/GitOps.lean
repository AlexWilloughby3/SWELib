import Std
import SWELib.Cicd.Deployment
import SWELib.Cicd.Rollback

/-!
# CI/CD GitOps Specification

Models GitOps reconciliation: desired vs actual state, drift detection,
sync status, and reconciliation state machine. Based on Argo CD / Flux concepts.
-/

namespace SWELib.Cicd.GitOps

/-- A declarative resource manifest. -/
structure DeclarativeResource where
  /-- API version (e.g., "apps/v1") -/
  apiVersion : String
  /-- Resource kind (e.g., "Deployment") -/
  kind : String
  /-- Optional namespace -/
  ns : Option String
  /-- Resource name -/
  name : String
  /-- Serialized spec content -/
  content : String
  deriving DecidableEq, Repr

/-- Git repository source configuration. -/
structure GitSource where
  /-- Repository URL -/
  repoUrl : String
  /-- Git revision (branch, tag, or commit SHA) -/
  revision : String
  /-- Path within the repository -/
  path : String
  /-- Sync interval in seconds -/
  interval : Nat
  deriving DecidableEq, Repr

/-- Desired state from a Git source. -/
structure DesiredState where
  /-- Git source configuration -/
  source : GitSource
  /-- Desired resources -/
  resources : List DeclarativeResource
  /-- Git revision hash -/
  revision : String
  deriving DecidableEq, Repr

/-- Actual state observed in the cluster. -/
structure ActualState where
  /-- Currently deployed resources -/
  resources : List DeclarativeResource
  deriving DecidableEq, Repr

/-- Sync status of an application. -/
inductive SyncStatus
  | synced
  | outOfSync
  | unknown
  deriving DecidableEq, Repr

/-- Health status of an application. -/
inductive HealthStatus
  | healthy
  | progressing
  | degraded
  | suspended
  | missing
  | unknown_
  deriving DecidableEq, Repr

/-- Sync policy configuration. -/
structure SyncPolicy where
  /-- Whether to automatically sync -/
  automated : Bool
  /-- Whether to prune resources not in Git -/
  prune : Bool
  /-- Whether to self-heal drifted resources -/
  selfHeal : Bool
  /-- Whether to apply only out-of-sync resources -/
  applyOutOfSyncOnly : Bool
  /-- Whether to prune as the last step -/
  pruneLast : Bool
  /-- Whether to create namespaces that don't exist -/
  createNamespace : Bool
  deriving DecidableEq, Repr

/-- Kind of drift detected between desired and actual state. -/
inductive DriftKind
  | added
  | removed
  | modified (diff : String)
  deriving DecidableEq, Repr

/-- A single drift item identifying a resource and the kind of drift. -/
structure DriftItem where
  /-- The resource that drifted -/
  resource : DeclarativeResource
  /-- Kind of drift -/
  kind : DriftKind
  deriving DecidableEq, Repr

/-- Target cluster destination. -/
structure ClusterDestination where
  /-- Cluster API server URL -/
  server : String
  /-- Target namespace -/
  ns : String
  deriving DecidableEq, Repr

/-- A GitOps application definition. -/
structure Application where
  /-- Application name -/
  name : String
  /-- Project name -/
  project : String
  /-- Git source -/
  source : GitSource
  /-- Cluster destination -/
  destination : ClusterDestination
  /-- Sync policy -/
  syncPolicy : SyncPolicy
  /-- Current sync status -/
  syncStatus : SyncStatus
  /-- Current health status -/
  healthStatus : HealthStatus
  deriving Repr

/-- State of the reconciliation loop. -/
inductive ReconciliationState
  | idle
  | fetching
  | planning
  | applying
  | healthChecking
  | succeeded
  | failed
  deriving DecidableEq, Repr

/-- A health check target. -/
structure HealthCheck where
  /-- API version -/
  apiVersion : String
  /-- Resource kind -/
  kind : String
  /-- Resource name -/
  name : String
  /-- Optional namespace -/
  ns : Option String
  deriving DecidableEq, Repr

/-- Compute a unique identifier for a declarative resource. -/
def resourceId (r : DeclarativeResource) : String × String × Option String × String :=
  (r.apiVersion, r.kind, r.ns, r.name)

/-- Compute the drift between desired and actual state.
    Items in actual not in desired = added.
    Items in desired not in actual = removed.
    Items in both with different content = modified. -/
def computeDrift (desired : DesiredState) (actual : ActualState) : List DriftItem :=
  let desiredIds := desired.resources.map resourceId
  let actualIds := actual.resources.map resourceId
  -- Resources in actual but not in desired (added to cluster, not in git)
  let added := actual.resources.filter (fun r => !desiredIds.contains (resourceId r))
  let addedItems := added.map (fun r => { resource := r, kind := .added })
  -- Resources in desired but not in actual (removed from cluster)
  let removed := desired.resources.filter (fun r => !actualIds.contains (resourceId r))
  let removedItems := removed.map (fun r => { resource := r, kind := .removed })
  -- Resources in both but with different content
  let modified := desired.resources.filterMap (fun dr =>
    match actual.resources.find? (fun ar => resourceId ar == resourceId dr) with
    | some ar =>
      if ar.content != dr.content then
        some { resource := dr, kind := .modified (ar.content ++ " -> " ++ dr.content) }
      else none
    | none => none)
  addedItems ++ removedItems ++ modified

/-- Check if desired and actual state are in sync (no drift). -/
def isSynced (desired : DesiredState) (actual : ActualState) : Bool :=
  (computeDrift desired actual).isEmpty

/-- Detect drift between desired state and an optional actual state.
    Returns `.unknown` when actual is none, `.synced` when no drift,
    `.outOfSync` otherwise. -/
def detectDrift (desired : DesiredState) (actual : Option ActualState) : SyncStatus :=
  match actual with
  | none => .unknown
  | some a => if isSynced desired a then .synced else .outOfSync

/-- Advance the reconciliation state machine.
    Each state transitions to the next on success, or to failed on failure.
    Terminal states (succeeded, failed) return to idle. -/
def advanceReconciliation (s : ReconciliationState) (success : Bool) : ReconciliationState :=
  match s, success with
  | .idle, true => .fetching
  | .idle, false => .idle
  | .fetching, true => .planning
  | .fetching, false => .failed
  | .planning, true => .applying
  | .planning, false => .failed
  | .applying, true => .healthChecking
  | .applying, false => .failed
  | .healthChecking, true => .succeeded
  | .healthChecking, false => .failed
  | .succeeded, _ => .idle
  | .failed, _ => .idle

/-- isSynced is true iff computeDrift returns an empty list. -/
theorem isSynced_iff_noDrift :
    isSynced d a = true ↔ computeDrift d a = [] := by
  simp [isSynced, List.isEmpty_iff]

/-- When actual state is none, drift detection returns unknown. -/
theorem detectDrift_none : detectDrift d none = .unknown := by
  simp [detectDrift]

/-- When there is no drift, detection returns synced. -/
theorem detectDrift_synced :
    computeDrift d a = [] → detectDrift d (some a) = .synced := by
  intro h
  simp [detectDrift, isSynced, h]

/-- When there is drift, detection returns outOfSync. -/
theorem detectDrift_outOfSync :
    computeDrift d a ≠ [] → detectDrift d (some a) = .outOfSync := by
  sorry

/-- Succeeded state always transitions to idle. -/
theorem advanceReconciliation_succeeded_to_idle :
    ∀ b, advanceReconciliation .succeeded b = .idle := by
  intro b; cases b <;> rfl

/-- Failed state always transitions to idle. -/
theorem advanceReconciliation_failed_to_idle :
    ∀ b, advanceReconciliation .failed b = .idle := by
  intro b; cases b <;> rfl

/-- If state is synced, then drift is empty. -/
theorem reconcile_idempotent :
    isSynced d a = true → computeDrift d a = [] := by
  exact isSynced_iff_noDrift.mp

/-- Resource identity is determined by apiVersion, kind, ns, and name. -/
theorem resourceId_determines_equality :
    resourceId r1 = resourceId r2 ↔
    r1.apiVersion = r2.apiVersion ∧ r1.kind = r2.kind ∧
    r1.ns = r2.ns ∧ r1.name = r2.name := by
  simp [resourceId, Prod.mk.injEq]

end SWELib.Cicd.GitOps
