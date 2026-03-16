/-
Copyright (c) 2024 SWELib Contributors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: SWELib Contributors
-/

import SWELib.Cloud.K8s.Primitives.DnsSubdomain
import SWELib.Cloud.K8s.Primitives.DnsLabel
import SWELib.Cloud.K8s.Primitives.LabelKey
import SWELib.Cloud.K8s.Primitives.LabelValue
import SWELib.Cloud.K8s.Primitives.ResourceVersion
import SWELib.Cloud.K8s.Primitives.ApiVersion
import SWELib.Cloud.K8s.Primitives.RFC3339Time

/-- Primitive types for Kubernetes API (Kubernetes spec section 1) -/

namespace SWELib.Cloud.K8s

-- Re-export all primitive types
export Primitives (DnsSubdomain DnsLabel LabelKey LabelValue
                  ResourceVersion ApiVersion RFC3339Time
                  parseLabelKey parseApiVersion
                  apiVersionV1 apiVersionAppsV1)

end SWELib.Cloud.K8s