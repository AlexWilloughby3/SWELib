/-
Copyright (c) 2024 SWELib Contributors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: SWELib Contributors
-/

import SWELib.Cloud.K8s.Metadata.TypeMeta
import SWELib.Cloud.K8s.Metadata.OwnerReference
import SWELib.Cloud.K8s.Metadata.ObjectMeta

/-- Metadata types for Kubernetes resources (Kubernetes spec section 2) -/

namespace SWELib.Cloud.K8s

-- Re-export metadata types
export Metadata (TypeMeta ObjectMeta OwnerReference
                podTypeMeta serviceTypeMeta deploymentTypeMeta
                atMostOneController)

end SWELib.Cloud.K8s