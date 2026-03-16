/-
Copyright (c) 2024 SWELib Contributors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: SWELib Contributors
-/

import SWELib.Cloud.K8s.Metadata
import SWELib.Cloud.K8s.Networking.ServiceSpec
import SWELib.Cloud.K8s.Primitives

namespace SWELib.Cloud.K8s.Networking

/-! # Service Resource

Service resource type (Kubernetes spec 5.4)
-/

open SWELib.Cloud.K8s.Metadata
open SWELib.Cloud.K8s.Primitives

/-- Load balancer ingress status -/
structure LoadBalancerIngress where
  ip : Option String := none
  hostname : Option String := none
  ports : List ServicePort := []
  deriving DecidableEq

/-- Load balancer status -/
structure LoadBalancerStatus where
  ingress : List LoadBalancerIngress := []
  deriving DecidableEq

/-- Service status -/
structure ServiceStatus where
  loadBalancer : Option LoadBalancerStatus := none
  conditions : List String := []  -- Simplified
  deriving DecidableEq

/-- A Kubernetes Service resource -/
structure Service where
  typeMeta : TypeMeta := serviceTypeMeta
  metadata : ObjectMeta
  spec : ServiceSpec
  status : ServiceStatus := {}
  deriving DecidableEq

/-- Get the cluster IP of a service -/
def Service.getClusterIP (svc : Service) : Option String :=
  svc.spec.clusterIP

/-- Check if a service has endpoints -/
def Service.hasSelector (svc : Service) : Bool :=
  !svc.spec.selector.isEmpty

/-- Get external IPs for a service -/
def Service.getExternalIPs (svc : Service) : List String :=
  svc.spec.externalIPs

end SWELib.Cloud.K8s.Networking