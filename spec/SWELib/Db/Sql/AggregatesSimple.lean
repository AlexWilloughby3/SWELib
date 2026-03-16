/-!
# SQL Aggregate Function Semantics (Simplified)

Simplified implementation of SQL aggregate functions for compilation.
-/

import SWELib.Db.Sql.ValueExtended

namespace SWELib.Db.Sql

variable {Const : Type} [DecidableEq Const] [Ord Const] [Add Const] [Zero Const]

/-- Compute an aggregate function over a list of SQL values (simplified).
    Returns NULL for empty input. -/
def computeAggSimple : AggFunc → List (SqlValue Const) → SqlValue Const
  | .count, vals =>
    -- COUNT ignores NULLs
    let nonNullCount := vals.filter Option.isSome |>.length
    some (Nat.cast nonNullCount : Const)
  | .sum, vals =>
    -- SUM ignores NULLs
    let nonNulls := vals.filterMap id
    if nonNulls.isEmpty then none else some (nonNulls.foldl (· + ·) 0)
  | .avg, vals =>
    -- AVG ignores NULLs
    let nonNulls := vals.filterMap id
    if nonNulls.isEmpty then none else
      let sum := nonNulls.foldl (· + ·) 0
      let count := nonNulls.length
      some (sum / (Nat.cast count : Const))
  | .min, vals =>
    -- MIN ignores NULLs
    let nonNulls := vals.filterMap id
    if nonNulls.isEmpty then none else
      some (nonNulls.foldl (fun acc x => min acc x) nonNulls.head!)
  | .max, vals =>
    -- MAX ignores NULLs
    let nonNulls := vals.filterMap id
    if nonNulls.isEmpty then none else
      some (nonNulls.foldl (fun acc x => max acc x) nonNulls.head!)

end SWELib.Db.Sql