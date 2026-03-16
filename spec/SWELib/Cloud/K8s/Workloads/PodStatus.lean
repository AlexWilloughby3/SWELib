/-
Copyright (c) 2024 SWELib Contributors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: SWELib Contributors
-/

import SWELib.Cloud.K8s.Primitives

namespace SWELib.Cloud.K8s.Workloads

open SWELib.Cloud.K8s.Primitives

/-- Pod lifecycle phase -/
inductive PodPhase where
  | Pending   -- Pod accepted but not yet running
  | Running   -- Pod bound to node and containers created
  | Succeeded -- All containers terminated successfully
  | Failed    -- At least one container failed
  | Unknown   -- Pod status cannot be determined
  deriving DecidableEq

instance : ToString PodPhase where
  toString
    | .Pending => "Pending"
    | .Running => "Running"
    | .Succeeded => "Succeeded"
    | .Failed => "Failed"
    | .Unknown => "Unknown"

/-- Status of a condition -/
inductive ConditionStatus where
  | True
  | False
  | Unknown
  deriving DecidableEq

instance : ToString ConditionStatus where
  toString
    | .True => "True"
    | .False => "False"
    | .Unknown => "Unknown"

/-- Pod condition -/
structure PodCondition where
  type : String  -- PodScheduled, Ready, Initialized, ContainersReady
  status : ConditionStatus
  lastProbeTime : Option RFC3339Time := none
  lastTransitionTime : Option RFC3339Time := none
  reason : Option String := none
  message : Option String := none
  deriving DecidableEq

/-- Container state -/
inductive ContainerState where
  | Waiting (reason : Option String := none) (message : Option String := none)
  | Running (startedAt : Option RFC3339Time := none)
  | Terminated (exitCode : Int) (signal : Option Int := none)
               (reason : Option String := none) (message : Option String := none)
               (startedAt : Option RFC3339Time := none)
               (finishedAt : Option RFC3339Time := none)
  deriving DecidableEq

/-- Container status -/
structure ContainerStatus where
  name : String
  state : Option ContainerState := none
  lastState : Option ContainerState := none
  ready : Bool := false
  restartCount : Nat := 0
  image : String
  imageID : String := ""
  containerID : Option String := none
  started : Option Bool := none
  deriving DecidableEq

/-- Pod status -/
structure PodStatus where
  phase : Option PodPhase := none
  conditions : List PodCondition := []
  message : Option String := none
  reason : Option String := none
  hostIP : Option String := none
  podIP : Option String := none
  podIPs : List String := []
  startTime : Option RFC3339Time := none
  containerStatuses : List ContainerStatus := []
  initContainerStatuses : List ContainerStatus := []
  qosClass : String := "BestEffort"
  deriving DecidableEq

end SWELib.Cloud.K8s.Workloads