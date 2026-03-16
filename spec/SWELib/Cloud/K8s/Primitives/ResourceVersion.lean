/-
Copyright (c) 2024 SWELib Contributors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: SWELib Contributors
-/

namespace SWELib.Cloud.K8s.Primitives

/-- An opaque resource version string used for optimistic concurrency control -/
structure ResourceVersion where
  val : String
  deriving DecidableEq, Hashable

instance : ToString ResourceVersion where
  toString v := v.val

/-- Lexicographic ordering for resource versions -/
instance : Ord ResourceVersion where
  compare v1 v2 := compare v1.val v2.val

instance : LT ResourceVersion where
  lt v1 v2 := v1.val < v2.val

instance : LE ResourceVersion where
  le v1 v2 := v1.val ≤ v2.val

-- ALGEBRAIC
theorem ResourceVersion.compare_trans :
    ∀ (v1 v2 v3 : ResourceVersion), v1 < v2 → v2 < v3 → v1 < v3 := by
  sorry

-- ALGEBRAIC
theorem ResourceVersion.compare_antisym :
    ∀ (v1 v2 : ResourceVersion), v1 ≤ v2 → v2 ≤ v1 → v1 = v2 := by
  sorry

end SWELib.Cloud.K8s.Primitives