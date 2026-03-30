/-
Copyright (c) 2024 SWELib Contributors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: SWELib Contributors
-/

import SWELib.Cloud.K8s.Selection
import SWELib.Cloud.K8s.Networking.ServicePort
import Std.Data.HashMap

namespace SWELib.Cloud.K8s.Networking

/-! # Service Specification

Service specification (Kubernetes spec 5.3)
-/

open SWELib.Cloud.K8s.Selection
open SWELib.Cloud.K8s.Primitives

/-- Service type -/
inductive ServiceType where
  | ClusterIP    -- Default, internal cluster IP
  | NodePort     -- Expose on each node's IP at a static port
  | LoadBalancer -- Provision external load balancer
  | ExternalName -- Map to external DNS name
  deriving DecidableEq

instance : ToString ServiceType where
  toString
    | .ClusterIP => "ClusterIP"
    | .NodePort => "NodePort"
    | .LoadBalancer => "LoadBalancer"
    | .ExternalName => "ExternalName"

/-- Session affinity type -/
inductive SessionAffinity where
  | None      -- No session affinity
  | ClientIP  -- Route to same pod based on client IP
  deriving DecidableEq

instance : ToString SessionAffinity where
  toString
    | .None => "None"
    | .ClientIP => "ClientIP"

/-- IP family -/
inductive IPFamily where
  | IPv4
  | IPv6
  deriving DecidableEq

instance : ToString IPFamily where
  toString
    | .IPv4 => "IPv4"
    | .IPv6 => "IPv6"

/-- Service specification -/
structure ServiceSpec where
  ports : List ServicePort := []
  selector : Std.HashMap LabelKey LabelValue := ∅
  clusterIP : Option String := none  -- "None" for headless
  clusterIPs : List String := []
  type : ServiceType := ServiceType.ClusterIP
  externalIPs : List String := []
  sessionAffinity : SessionAffinity := SessionAffinity.None
  loadBalancerIP : Option String := none
  loadBalancerSourceRanges : List String := []
  externalName : Option String := none  -- For ExternalName type
  externalTrafficPolicy : String := "Cluster"
  healthCheckNodePort : Option Nat := none
  publishNotReadyAddresses : Bool := false
  sessionAffinityConfig : Option String := none  -- Simplified
  ipFamilies : List IPFamily := []
  ipFamilyPolicy : Option String := none

/-- Check if a service is headless -/
def ServiceSpec.isHeadless (spec : ServiceSpec) : Bool :=
  spec.clusterIP = some "None"

/-- Check if a service needs external load balancer -/
def ServiceSpec.needsLoadBalancer (spec : ServiceSpec) : Bool :=
  spec.type = ServiceType.LoadBalancer

end SWELib.Cloud.K8s.Networking
