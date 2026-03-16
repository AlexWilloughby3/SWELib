/-
Copyright (c) 2024 SWELib Contributors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: SWELib Contributors
-/

namespace SWELib.Cloud.K8s.Selection

/-- Operators for label selector expressions -/
inductive SelectorOperator where
  | In           -- Key must have value in the set
  | NotIn        -- Key must not have value in the set
  | Exists       -- Key must exist (regardless of value)
  | DoesNotExist -- Key must not exist
  deriving DecidableEq

instance : ToString SelectorOperator where
  toString
    | .In => "In"
    | .NotIn => "NotIn"
    | .Exists => "Exists"
    | .DoesNotExist => "DoesNotExist"

end SWELib.Cloud.K8s.Selection