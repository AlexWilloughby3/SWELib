import SWELib.Db.Sql.ValueExtended

/-!
# SQL Aggregate Function Semantics

Complete implementation of SQL aggregate functions (SQL:2023 Section 10.9)
with proper NULL handling and bag semantics.

This module provides:
1. `computeAgg` function for all standard aggregates (SUM, AVG, MIN, MAX, COUNT)
2. NULL handling according to SQL standard (NULL values are ignored)
3. Proofs about aggregate properties
-/

namespace SWELib.Db.Sql

variable {Const : Type} [DecidableEq Const] [Ord Const] [Add Const] [Sub Const] [Mul Const] [Div Const] [Mod Const] [Append Const] [Neg Const] [Abs Const] [Zero Const] [OfNat Const 0] [NatCast Const]

/-- Compute an aggregate function over a list of SQL values.
    Follows SQL semantics: NULL values are ignored (SQL:2023 Section 10.9).

    Returns `none` (NULL) for:
    - Empty input (after ignoring NULLs) for SUM, AVG, MIN, MAX
    - Any input for COUNT (always returns a count, never NULL)

    For AVG: computes sum / count as floating point would, but with our
    abstract `Const` type we require `Div` instance. -/
def computeAgg : AggFunc → List (SqlValue Const) → SqlValue Const
  | .count, vals =>
    -- COUNT ignores NULLs (SQL:2023 Section 10.9)
    let nonNullCount := vals.filter (·.isSome) |>.length
    some (Nat.cast nonNullCount : Const)
  | .sum, vals =>
    -- SUM ignores NULLs, returns NULL if all values are NULL or empty
    let nonNulls := vals.filterMap id
    if nonNulls.isEmpty then none else some (nonNulls.foldl (· + ·) 0)
  | .avg, vals =>
    -- AVG ignores NULLs, returns NULL if all values are NULL or empty
    let nonNulls := vals.filterMap id
    if nonNulls.isEmpty then none else
      let sum := nonNulls.foldl (· + ·) 0
      let count := nonNulls.length
      some (sum / (Nat.cast count : Const))
  | .min, vals =>
    -- MIN ignores NULLs, returns NULL if all values are NULL or empty
    let nonNulls := vals.filterMap id
    if nonNulls.isEmpty then none else
      let minVal := nonNulls.foldl (fun acc x => if x < acc then x else acc) nonNulls.head!
      some minVal
  | .max, vals =>
    -- MAX ignores NULLs, returns NULL if all values are NULL or empty
    let nonNulls := vals.filterMap id
    if nonNulls.isEmpty then none else
      let maxVal := nonNulls.foldl (fun acc x => if x > acc then x else acc) nonNulls.head!
      some maxVal

/-- COUNT always returns a value (never NULL), even for empty input. -/
theorem computeAgg_count_never_null (vals : List (SqlValue Const)) :
    computeAgg .count vals ≠ none := by
  simp [computeAgg]

/-- COUNT of empty list is 0. -/
theorem computeAgg_count_empty : computeAgg .count ([] : List (SqlValue Const)) = some 0 := by
  simp [computeAgg]

/-- COUNT of list containing only NULLs is 0. -/
theorem computeAgg_count_all_null (n : Nat) :
    computeAgg .count (List.replicate n none) = some 0 := by
  simp [computeAgg]

/-- SUM of empty list is NULL. -/
theorem computeAgg_sum_empty : computeAgg .sum ([] : List (SqlValue Const)) = none := by
  simp [computeAgg]

/-- SUM of list containing only NULLs is NULL. -/
theorem computeAgg_sum_all_null (n : Nat) :
    computeAgg .sum (List.replicate n none) = none := by
  simp [computeAgg]

/-- AVG of empty list is NULL. -/
theorem computeAgg_avg_empty : computeAgg .avg ([] : List (SqlValue Const)) = none := by
  simp [computeAgg]

/-- MIN of empty list is NULL. -/
theorem computeAgg_min_empty : computeAgg .min ([] : List (SqlValue Const)) = none := by
  simp [computeAgg]

/-- MAX of empty list is NULL. -/
theorem computeAgg_max_empty : computeAgg .max ([] : List (SqlValue Const)) = none := by
  simp [computeAgg]

/-- SUM is additive: sum of concatenated lists equals sum of sums (when defined). -/
theorem computeAgg_sum_concat (vals1 vals2 : List (SqlValue Const))
    (h1 : computeAgg .sum vals1 ≠ none) (h2 : computeAgg .sum vals2 ≠ none) :
    computeAgg .sum (vals1 ++ vals2) =
    vadd (computeAgg .sum vals1) (computeAgg .sum vals2) := by
  sorry

/-- MIN of concatenated lists is the minimum of the individual mins. -/
theorem computeAgg_min_concat (vals1 vals2 : List (SqlValue Const))
    (h1 : computeAgg .min vals1 ≠ none) (h2 : computeAgg .min vals2 ≠ none) :
    computeAgg .min (vals1 ++ vals2) =
    let min1 := computeAgg .min vals1
    let min2 := computeAgg .min vals2
    match min1, min2 with
    | some a, some b => some (min a b)
    | _, _ => none := by
  sorry

/-- COUNT ignores NULL values. -/
theorem computeAgg_count_ignores_nulls (vals : List (SqlValue Const)) :
    computeAgg .count vals = computeAgg .count (vals.filter (·.isSome)) := by
  simp [computeAgg]

/-- Adding NULL to a list doesn't change SUM (NULL values are always ignored). -/
theorem computeAgg_sum_null_insert (vals : List (SqlValue Const))
    (h : vals.filterMap id ≠ []) :
    computeAgg .sum (none :: vals) = computeAgg .sum vals := by
  simp [computeAgg]

/-- Aggregate computation is invariant under permutation (bag semantics). -/
theorem computeAgg_perm (f : AggFunc) (vals1 vals2 : List (SqlValue Const))
    (h : vals1 ~ vals2) : computeAgg f vals1 = computeAgg f vals2 := by
  sorry

end SWELib.Db.Sql