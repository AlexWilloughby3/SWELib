/-
Copyright (c) 2024 SWELib Contributors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: SWELib Contributors
-/

import SWELib.Cloud.K8s.Workloads.Protocol

namespace SWELib.Cloud.K8s.Workloads

/-- A container port with validated range -/
structure ContainerPort where
  name : Option String := none
  containerPort : Nat
  h_port_range : 1 ≤ containerPort ∧ containerPort ≤ 65535
  protocol : Protocol := Protocol.default
  hostPort : Option Nat := none
  hostIP : Option String := none
  deriving DecidableEq

/-- Environment variable for a container -/
structure EnvVar where
  name : String
  value : Option String := none
  -- valueFrom could be added for ConfigMap/Secret references
  deriving DecidableEq

/-- Container specification -/
structure Container where
  name : String
  image : String
  command : List String := []
  args : List String := []
  workingDir : Option String := none
  ports : List ContainerPort := []
  env : List EnvVar := []
  imagePullPolicy : String := "IfNotPresent"
  -- Simplified: omitting resources, volume mounts, probes, etc.
  deriving DecidableEq

/-- Check that container names are unique in a list -/
def uniqueContainerNames (containers : List Container) : Bool :=
  let names := containers.map (·.name)
  names.length = names.eraseDups.length

-- STRUCTURAL
theorem uniqueContainerNames_empty :
    uniqueContainerNames [] = true := by
  sorry

-- STRUCTURAL
theorem uniqueContainerNames_singleton (c : Container) :
    uniqueContainerNames [c] = true := by
  sorry

end SWELib.Cloud.K8s.Workloads