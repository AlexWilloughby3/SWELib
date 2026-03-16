import SWELib.Db.Sql.Value
import SWELib.Db.Sql.Schema
import SWELib.Db.Sql.Relation
import SWELib.Db.Sql.Syntax
import SWELib.Db.Sql.WellFormedness
import SWELib.Db.Sql.Eval
import SWELib.Db.Sql.Algebra
import SWELib.Db.Sql.Translation
import SWELib.Db.Sql.Equivalence
import SWELib.Db.Sql.Optimization
import SWELib.Db.Sql.ValueExtended
import SWELib.Db.Sql.Aggregates
import SWELib.Db.Sql.GroupBy
import SWELib.Db.Sql.Joins
import SWELib.Db.Sql.OrderBy
import SWELib.Db.Sql.TranslationComplete
import SWELib.Db.Sql.EquivalenceComplete
import SWELib.Db.Sql.OptimizationComplete
import SWELib.Db.Sql.Refactor

/-!
# SQL Formal Semantics

Complete formalization of SQL query semantics in Lean 4, based on the
Coq mechanization by Benzaken & Contejean (CPP '19). This module provides:

1. **Three‑valued logic and NULL handling** (`Sql/Value.lean`)
2. **Schemas and tuples** (`Sql/Schema.lean`)
3. **Bag‑semantic relations** (`Sql/Relation.lean`)
4. **SQL abstract syntax** (`Sql/Syntax.lean`)
5. **Well‑formedness/typing judgments** (`Sql/WellFormedness.lean`)
6. **Executable SQL evaluator** (`Sql/Eval.lean`)
7. **Relational algebra** (`Sql/Algebra.lean`)
8. **SQL → algebra translation** (`Sql/Translation.lean`)
9. **Translation soundness proof** (`Sql/Equivalence.lean`)
10. **Algebraic optimization rules** (`Sql/Optimization.lean`)

## Key Features

- **Bag semantics** (multisets) as in real SQL implementations
- **Kleene three‑valued logic** for NULL‑aware comparisons
- **Correlated subqueries** via evaluation contexts
- **Aggregates** (COUNT, SUM, AVG, MIN, MAX) with GROUP BY
- **Set operations** (UNION, INTERSECT, EXCEPT) with ALL/DISTINCT
- **Provably correct translation** to relational algebra
- **Optimization rules** with soundness proofs

## Usage Example

```lean
open SWELib.Db.Sql

-- Define a concrete constant type
abbrev MyConst := Int
instance : DecidableEq MyConst := inferInstance
instance : Ord MyConst := inferInstance

-- Create a simple SELECT query
def myQuery : SelectQuery MyConst :=
  .select .all [.col "x", .col "y"] [.table "t" none] none [] none [] none none

-- Translate to relational algebra
#eval translate myQuery  -- .baseTable "t" with projection
```

## Design Decisions

- **Abstract `Const` type** – parameterized over concrete value types
- **Fuel‑based termination** – handles mutual recursion in evaluator
- **List‑based bags** – simple representation without Mathlib dependency
- **Length‑indexed tuples** – schema‑aware at type level
- **First‑draft proofs** – many theorems marked `sorry` for initial prototype

## References

- Benzaken & Contejean, *A Coq Mechanised Formal Semantics for Realistic SQL Queries* (CPP 2019)
- Guagliardo & Libkin, *A Formal Semantics of SQL Queries* (VLDB 2017)
- Burel et al., *A Formalization of SQL with Nulls* (JAR 2022)
- ISO/IEC 9075:2023 (SQL:2023) standard
- PostgreSQL 17 documentation
-/

namespace SWELib.Db.Sql

namespace SWELib.Db.Sql

-- From Value.lean
export Value (SqlValue Tribool veq vlt)
-- From ValueExtended.lean
export ValueExtended (
  vadd vsub vmul vdiv vmod vconcat vneg
  applyBinOp applyUnOp
)
-- From Schema.lean
export Schema (AttrName Schema TableName Tuple)
-- From Relation.lean
export Relation (Relation)
-- From Syntax.lean
export Syntax (
  BinOp UnOp CmpOp AggFunc SetOp SetQuantifier JoinKind SortDir NullsOrder
  SqlExpr SqlCondition SelectItem FromItem OrderByItem SelectQuery
)
-- From WellFormedness.lean
export WellFormedness (containsAgg ExprWF CondWF)
-- From Eval.lean
export Eval (DatabaseEnv EvalCtx evalExpr evalCond evalQuery)
-- From Algebra.lean
export Algebra (RelAlg evalRelAlg)
-- From Aggregates.lean
export Aggregates (computeAgg)
-- From GroupBy.lean
export GroupBy (extractKey groupRowsBy computeAggregates applyGroupBy)
-- From Joins.lean
export Joins (innerJoinRows leftOuterJoinRows rightOuterJoinRows fullOuterJoinRows)
-- From OrderBy.lean
export OrderBy (RelAlgExt compareWithNulls sortRows evalRelAlgExt)
-- From Translation.lean
export Translation (translate)
-- From TranslationComplete.lean
export TranslationComplete (translateComplete)
-- From Equivalence.lean
export Equivalence (translation_soundness)
-- From EquivalenceComplete.lean
export EquivalenceComplete (translation_soundness_complete)
-- From Optimization.lean
export Optimization (
  select_pushdown_cross_left select_pushdown_cross_right
  select_idempotent select_over_union project_merge project_over_cross
  distinct_idempotent distinct_commutes_select cross_empty_left cross_empty_right
  union_empty_left union_empty_right limit_zero offset_zero limit_offset_combine
  select_on_singleton optimizer_rule_chain
)
-- From OptimizationComplete.lean
export OptimizationComplete (
  select_pushdown_cross_left_complete select_pushdown_cross_right_complete
  select_idempotent_complete select_over_union_complete
  project_merge_complete distinct_idempotent_complete
  limit_zero_complete offset_zero_complete
)
-- From Refactor.lean
export Refactor (isFullySupported evalSimple optimizePipeline ppRelAlg)

end SWELib.Db.Sql
