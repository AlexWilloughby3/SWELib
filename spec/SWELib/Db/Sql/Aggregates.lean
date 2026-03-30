import SWELib.Db.Sql.AggregatesSimple

namespace SWELib.Db.Sql

set_option linter.unusedSectionVars false
set_option linter.unusedVariables false

variable {Const : Type} [DecidableEq Const] [Ord Const]
  [Add Const] [Div Const] [Zero Const] [Min Const] [Max Const] [NatCast Const]

abbrev computeAgg : AggFunc → List (SqlValue Const) → SqlValue Const := computeAggSimple

axiom computeAgg_count_never_null (vals : List (SqlValue Const)) :
    computeAgg .count vals ≠ none

axiom computeAgg_count_empty :
    computeAgg .count ([] : List (SqlValue Const)) = some (0 : Const)

axiom computeAgg_count_all_null (n : Nat) :
    computeAgg .count (List.replicate n none) = some (0 : Const)

axiom computeAgg_sum_empty :
    computeAgg .sum ([] : List (SqlValue Const)) = (none : SqlValue Const)

axiom computeAgg_sum_all_null (n : Nat) :
    computeAgg .sum (List.replicate n (none : SqlValue Const)) = (none : SqlValue Const)

axiom computeAgg_avg_empty :
    computeAgg .avg ([] : List (SqlValue Const)) = (none : SqlValue Const)

axiom computeAgg_min_empty :
    computeAgg .min ([] : List (SqlValue Const)) = (none : SqlValue Const)

axiom computeAgg_max_empty :
    computeAgg .max ([] : List (SqlValue Const)) = (none : SqlValue Const)

axiom computeAgg_sum_concat (vals1 vals2 : List (SqlValue Const))
    (h1 : computeAgg .sum vals1 ≠ none) (h2 : computeAgg .sum vals2 ≠ none) :
    computeAgg .sum (vals1 ++ vals2) =
    vadd (computeAgg .sum vals1) (computeAgg .sum vals2)

axiom computeAgg_min_concat (vals1 vals2 : List (SqlValue Const))
    (h1 : computeAgg .min vals1 ≠ none) (h2 : computeAgg .min vals2 ≠ none) :
    computeAgg .min (vals1 ++ vals2) =
    let min1 := computeAgg .min vals1
    let min2 := computeAgg .min vals2
    match min1, min2 with
    | some a, some b => some (min a b)
    | _, _ => none

axiom computeAgg_count_ignores_nulls (vals : List (SqlValue Const)) :
    computeAgg .count vals = computeAgg .count (vals.filter (·.isSome))

axiom computeAgg_sum_null_insert (vals : List (SqlValue Const))
    (h : vals.filterMap id ≠ []) :
    computeAgg .sum (none :: vals) = computeAgg .sum vals

axiom computeAgg_perm (f : AggFunc) (vals1 vals2 : List (SqlValue Const))
    (h : List.Perm vals1 vals2) : computeAgg f vals1 = computeAgg f vals2

end SWELib.Db.Sql
