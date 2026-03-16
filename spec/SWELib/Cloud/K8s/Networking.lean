/-
Copyright (c) 2024 SWELib Contributors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: SWELib Contributors
-/

import SWELib.Cloud.K8s.Networking.IntOrString
import SWELib.Cloud.K8s.Networking.ServicePort
import SWELib.Cloud.K8s.Networking.ServiceSpec
import SWELib.Cloud.K8s.Networking.Service

/-- Networking types for Kubernetes (Kubernetes spec section 5) -/

namespace SWELib.Cloud.K8s

-- Re-export networking types
export Networking (IntOrString ServicePort ServiceSpec ServiceType
                  SessionAffinity IPFamily LoadBalancerIngress
                  LoadBalancerStatus ServiceStatus Service)

end SWELib.Cloud.K8s