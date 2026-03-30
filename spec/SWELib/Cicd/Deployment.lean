import Std

/-!
# CI/CD Deployment Specification

Models Kubernetes deployment strategies (rolling update, recreate, blue/green, canary),
pod templates, probes, and deployment lifecycle status.
-/

namespace SWELib.Cicd.Deployment

/-- Type of deployment strategy. -/
inductive DeploymentStrategyType
  | rollingUpdate
  | recreate
  deriving DecidableEq, Repr

/-- Configuration for rolling update strategy.
    At least one of maxSurge or maxUnavailable must be positive. -/
structure RollingUpdateConfig where
  /-- Maximum number of pods above desired count during update -/
  maxSurge : Nat
  /-- Maximum number of pods that can be unavailable during update -/
  maxUnavailable : Nat
  /-- At least one must be positive -/
  h_valid : maxSurge + maxUnavailable > 0
  deriving Repr

/-- Deployment strategy configuration. -/
structure DeploymentStrategy where
  /-- Strategy type -/
  type : DeploymentStrategyType
  /-- Rolling update configuration (only used when type = rollingUpdate) -/
  rollingUpdate : Option RollingUpdateConfig
  deriving Repr

/-- Type of health probe. -/
inductive ProbeType
  | httpGet (path : String) (port : Nat)
  | tcpSocket (port : Nat)
  | exec (command : List String)
  deriving DecidableEq, Repr

/-- Health probe configuration with timing parameters. -/
structure Probe where
  /-- Probe mechanism -/
  type : ProbeType
  /-- Seconds to wait before starting probes -/
  initialDelaySeconds : Nat
  /-- Seconds between probe attempts -/
  periodSeconds : Nat
  /-- Seconds before probe times out -/
  timeoutSeconds : Nat
  /-- Consecutive successes required to be considered healthy -/
  successThreshold : Nat
  /-- Consecutive failures required to be considered unhealthy -/
  failureThreshold : Nat
  /-- Period must be positive -/
  h_period : periodSeconds > 0
  /-- Timeout must be positive -/
  h_timeout : timeoutSeconds > 0
  /-- At least one success needed -/
  h_success : successThreshold ≥ 1
  /-- At least one failure needed -/
  h_failure : failureThreshold ≥ 1
  deriving Repr

/-- Container specification within a pod template. -/
structure ContainerSpec where
  /-- Container name -/
  name : String
  /-- Container image reference -/
  image : String
  /-- Readiness probe configuration -/
  readinessProbe : Option Probe
  /-- Liveness probe configuration -/
  livenessProbe : Option Probe
  /-- Exposed ports -/
  ports : List Nat
  deriving Repr

/-- Pod template specification.
    Must contain at least one container. -/
structure PodTemplateSpec where
  /-- Labels for pod selection -/
  labels : List (String × String)
  /-- Container specifications -/
  containers : List ContainerSpec
  /-- At least one container required -/
  h_containers_nonempty : containers ≠ []
  deriving Repr

/-- Full deployment specification. -/
structure DeploymentSpec where
  /-- Desired number of replicas -/
  replicas : Nat
  /-- Label selector for pods -/
  selector : List (String × String)
  /-- Pod template -/
  template : PodTemplateSpec
  /-- Deployment strategy -/
  strategy : DeploymentStrategy
  /-- Minimum seconds a pod must be ready before considered available -/
  minReadySeconds : Nat
  /-- Seconds before a deployment is considered failed -/
  progressDeadlineSeconds : Nat
  /-- Number of old ReplicaSets to retain -/
  revisionHistoryLimit : Nat
  /-- Whether the deployment is paused -/
  paused : Bool
  deriving Repr

/-- Phase of a deployment. -/
inductive DeploymentPhase
  | progressing
  | complete
  | failed
  | paused
  deriving DecidableEq, Repr

/-- Type of deployment condition. -/
inductive DeploymentConditionType
  | progressing_
  | available
  | replicaFailure
  deriving DecidableEq, Repr

/-- Reason for a deployment condition. -/
inductive DeploymentConditionReason
  | newReplicaSetCreated
  | foundNewReplicaSet
  | replicaSetUpdated
  | deploymentCompleted
  | progressDeadlineExceeded
  | newPodsAvailable
  | minimumReplicasAvailable
  | minimumReplicasUnavailable
  deriving DecidableEq, Repr

/-- A deployment condition entry. -/
structure DeploymentCondition where
  /-- Condition type -/
  type : DeploymentConditionType
  /-- Whether the condition is true -/
  status : Bool
  /-- Reason for the condition -/
  reason : DeploymentConditionReason
  /-- Optional human-readable message -/
  message : Option String
  deriving DecidableEq, Repr

/-- Current status of a deployment. -/
structure DeploymentStatus where
  /-- Last observed generation -/
  observedGeneration : Nat
  /-- Total number of replicas -/
  replicas : Nat
  /-- Number of replicas updated to the latest spec -/
  updatedReplicas : Nat
  /-- Number of ready replicas -/
  readyReplicas : Nat
  /-- Number of available replicas -/
  availableReplicas : Nat
  /-- Deployment conditions -/
  conditions : List DeploymentCondition
  /-- Current phase -/
  phase : DeploymentPhase
  deriving Repr

/-- Reference to a ReplicaSet. -/
structure ReplicaSetRef where
  /-- Revision number -/
  revision : Nat
  /-- Hash of the pod template -/
  podTemplateHash : String
  /-- Desired replicas -/
  replicas : Nat
  /-- Ready replicas -/
  readyReplicas : Nat
  /-- Available replicas -/
  availableReplicas : Nat
  deriving DecidableEq, Repr

/-- Slot identifier for blue/green deployments. -/
inductive SlotId
  | blue
  | green
  deriving DecidableEq, Repr

/-- Blue/green deployment configuration. -/
structure BlueGreenConfig where
  /-- Currently active slot -/
  activeSlot : SlotId
  /-- Spec for the inactive slot -/
  inactiveSpec : DeploymentSpec
  /-- Service selector labels -/
  serviceSelector : List (String × String)
  deriving Repr

/-- Canary deployment configuration. -/
structure CanaryConfig where
  /-- Number of stable replicas -/
  stableReplicas : Nat
  /-- Number of canary replicas -/
  canaryReplicas : Nat
  /-- Percentage of traffic to route to canary (0-100) -/
  trafficWeight : Nat
  /-- Whether analysis is required before promotion -/
  analysisRequired : Bool
  /-- Traffic weight must be at most 100 -/
  h_weight : trafficWeight ≤ 100
  deriving Repr

/-- Check if all selector labels are present in the pod template labels. -/
def selectorMatchesTemplate (spec : DeploymentSpec) : Bool :=
  spec.selector.all (fun kv => spec.template.labels.contains kv)

/-- Upper bound on total pods during a rolling update. -/
def scaleUpBound (desired : Nat) (cfg : RollingUpdateConfig) : Nat :=
  desired + cfg.maxSurge

/-- Maximum number of unavailable pods during a rolling update. -/
def unavailableBound (cfg : RollingUpdateConfig) : Nat :=
  cfg.maxUnavailable

/-- Check if a deployment has completed (all replicas updated, available, and ready). -/
def markComplete (spec : DeploymentSpec) (status : DeploymentStatus) : Bool :=
  status.updatedReplicas == spec.replicas &&
  status.availableReplicas == spec.replicas &&
  status.readyReplicas == spec.replicas

/-- Determine the deployment phase given spec, status, and elapsed time. -/
def checkProgress (spec : DeploymentSpec) (status : DeploymentStatus) (elapsed : Nat) : DeploymentPhase :=
  if spec.paused then .paused
  else if elapsed >= spec.progressDeadlineSeconds && status.updatedReplicas < spec.replicas then .failed
  else if markComplete spec status then .complete
  else .progressing

/-- Switch the active slot in a blue/green deployment. -/
def switchBlueGreen (cfg : BlueGreenConfig) : BlueGreenConfig :=
  { cfg with activeSlot := match cfg.activeSlot with
    | .blue => .green
    | .green => .blue }

/-- Selector matches template iff all selector pairs are in the template labels. -/
theorem selectorTemplateAgreement :
    selectorMatchesTemplate spec = true ↔
    ∀ kv ∈ spec.selector, kv ∈ spec.template.labels := by
  simp [selectorMatchesTemplate, List.all_eq_true]

/-- Scale up bound equals desired plus maxSurge. -/
theorem scaleUpBound_eq : scaleUpBound d cfg = d + cfg.maxSurge := by
  rfl

/-- If markComplete is true, then all replica counts match desired. -/
theorem completeImpliesAllUpdated :
    markComplete spec status = true →
    status.updatedReplicas = spec.replicas ∧ status.availableReplicas = spec.replicas := by
  intro h
  simp [markComplete, Bool.and_eq_true, beq_iff_eq] at h
  exact ⟨h.1.1, h.1.2⟩

/-- A paused deployment always reports paused phase. -/
theorem pausedNoRollout :
    spec.paused = true →
    checkProgress spec status elapsed = .paused := by
  intro h; simp [checkProgress, h]

/-- Switching blue/green twice returns to original configuration. -/
theorem switchBlueGreen_involution :
    switchBlueGreen (switchBlueGreen cfg) = cfg := by
  cases cfg with
  | mk activeSlot inactiveSpec serviceSelector =>
      cases activeSlot <;> rfl

/-- RollingUpdateConfig always has maxSurge + maxUnavailable > 0. -/
theorem h_valid_positive : ∀ cfg : RollingUpdateConfig, cfg.maxSurge + cfg.maxUnavailable > 0 :=
  fun cfg => cfg.h_valid

/-- Failed phase requires deadline exceeded and incomplete update. -/
theorem failedRequiresDeadline :
    checkProgress spec status elapsed = .failed →
    elapsed ≥ spec.progressDeadlineSeconds ∧ status.updatedReplicas < spec.replicas := by
  intro h
  by_cases hPaused : spec.paused
  · simp [checkProgress, hPaused] at h
  · by_cases hDeadline :
      elapsed ≥ spec.progressDeadlineSeconds ∧ status.updatedReplicas < spec.replicas
    · exact hDeadline
    · by_cases hComplete : markComplete spec status = true
      · simp [checkProgress, hPaused, hDeadline, hComplete] at h
      · simp [checkProgress, hPaused, hDeadline, hComplete] at h

end SWELib.Cicd.Deployment
