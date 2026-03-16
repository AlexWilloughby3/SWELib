/-
Copyright (c) 2024 SWELib Contributors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: SWELib Contributors
-/

import SWELib.Cloud.K8s.Selection.SelectorOperator
import SWELib.Cloud.K8s.Selection.LabelSelector

/-- Selection types for Kubernetes resources (Kubernetes spec section 3) -/

namespace SWELib.Cloud.K8s

-- Re-export selection types
export Selection (SelectorOperator MatchExpression LabelSelector)

end SWELib.Cloud.K8s