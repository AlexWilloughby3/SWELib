/-
Copyright (c) 2024 SWELib Contributors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: SWELib Contributors
-/

import SWELib.Cloud.K8s.Primitives
import SWELib.Cloud.K8s.Workloads.Container
import SWELib.Cloud.K8s.Workloads.RestartPolicy

namespace SWELib.Cloud.K8s.Workloads

/-! # Pod Specification

Pod specification (Kubernetes spec 4.4)
-/

open SWELib.Cloud.K8s.Primitives

/-- Pod specification with container requirements -/
structure PodSpec where
  containers : List Container
  h_containers_nonempty : containers ≠ []
  initContainers : List Container := []
  restartPolicy : RestartPolicy := RestartPolicy.default
  terminationGracePeriodSeconds : Nat := 30
  activeDeadlineSeconds : Option Nat := none
  dnsPolicy : String := "ClusterFirst"
  nodeName : Option String := none
  nodeSelector : Std.HashMap String String := Std.HashMap.empty
  hostname : Option DnsLabel := none
  subdomain : Option DnsSubdomain := none
  schedulerName : String := "default-scheduler"
  -- Simplified: omitting volumes, security context, affinity, etc.
  deriving DecidableEq

/-- Validate a pod spec -/
def PodSpec.isValid (spec : PodSpec) : Bool :=
  uniqueContainerNames spec.containers &&
  uniqueContainerNames spec.initContainers &&
  spec.terminationGracePeriodSeconds ≥ 0

/-- Create a minimal pod spec with one container -/
def PodSpec.withContainer (c : Container) : PodSpec :=
  ⟨[c], by simp⟩

/-- Add a container to a pod spec -/
def PodSpec.addContainer (spec : PodSpec) (c : Container) : PodSpec :=
  ⟨spec.containers ++ [c], by simp [spec.h_containers_nonempty],
   spec.initContainers, spec.restartPolicy, spec.terminationGracePeriodSeconds,
   spec.activeDeadlineSeconds, spec.dnsPolicy, spec.nodeName, spec.nodeSelector,
   spec.hostname, spec.subdomain, spec.schedulerName⟩

end SWELib.Cloud.K8s.Workloads