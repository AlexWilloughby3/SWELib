/-
Copyright (c) 2024 SWELib Contributors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: SWELib Contributors
-/

import SWELib.Cloud.K8s.Metadata
import SWELib.Cloud.K8s.Workloads.PodSpec
import SWELib.Cloud.K8s.Workloads.PodStatus

namespace SWELib.Cloud.K8s.Workloads

/-! # Pod Resource

Pod resource type (Kubernetes spec 4.6)
-/

open SWELib.Cloud.K8s.Metadata

/-- A Kubernetes Pod resource -/
structure Pod where
  typeMeta : TypeMeta := podTypeMeta
  metadata : ObjectMeta
  spec : PodSpec
  status : PodStatus := {}
  deriving DecidableEq

/-- Check if a pod is ready -/
def Pod.isReady (pod : Pod) : Bool :=
  pod.status.conditions.any fun c =>
    c.type = "Ready" && c.status = ConditionStatus.True

/-- Check if a pod is running -/
def Pod.isRunning (pod : Pod) : Bool :=
  pod.status.phase = some PodPhase.Running

/-- Check if a pod has succeeded -/
def Pod.hasSucceeded (pod : Pod) : Bool :=
  pod.status.phase = some PodPhase.Succeeded

/-- Check if a pod has failed -/
def Pod.hasFailed (pod : Pod) : Bool :=
  pod.status.phase = some PodPhase.Failed

/-- Get the pod's IP address -/
def Pod.getIP (pod : Pod) : Option String :=
  pod.status.podIP

end SWELib.Cloud.K8s.Workloads