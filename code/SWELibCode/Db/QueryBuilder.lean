import SWELib
import SWELibBridge
import SWELibCode.Db.PgClient

/-!
# QueryBuilder

Fluent API for constructing `SelectQuery` values from the spec layer.
Builds up a `SelectQuery Const` incrementally and then serializes it via
`PgClient.toSql` for execution.

## Usage

```lean
open SWELibCode.Db.QueryBuilder

def q : SelectQuery String :=
  query
    |>.select [.expr (.col "id") none, .expr (.col "name") none]
    |>.from_ [.table "users" none]
    |>.where_ (.cmp .eq (.col "active") (.lit "true"))
    |>.limit 100
    |>.build

#eval PgClient.toSql q
-- "SELECT id, name FROM users WHERE id = active LIMIT 100"
```
-/

namespace SWELibCode.Db.QueryBuilder

open SWELib.Db.Sql

/-- Mutable builder state for a SELECT query. -/
structure Builder (Const : Type) where
  quant    : SetQuantifier            := .all
  items    : List (SelectItem Const)  := [.star]
  from_    : List (FromItem Const)    := []
  where_   : Option (SqlCondition Const) := none
  groupBy  : List (SqlExpr Const)     := []
  having   : Option (SqlCondition Const) := none
  orderBy  : List (OrderByItem Const) := []
  limit_   : Option Nat               := none
  offset_  : Option Nat               := none

/-- Create a fresh builder (SELECT * with no clauses). -/
def query {Const : Type} : Builder Const := {}

/-- Set the SELECT list. -/
def Builder.select {Const : Type} (b : Builder Const) (items : List (SelectItem Const)) :
    Builder Const :=
  { b with items := items }

/-- Set SELECT DISTINCT. -/
def Builder.distinct {Const : Type} (b : Builder Const) : Builder Const :=
  { b with quant := .distinct }

/-- Set the FROM clause. -/
def Builder.from_ {Const : Type} (b : Builder Const) (from_ : List (FromItem Const)) :
    Builder Const :=
  { b with from_ := from_ }

/-- Add an additional FROM item (cross joins the new item). -/
def Builder.addFrom {Const : Type} (b : Builder Const) (item : FromItem Const) :
    Builder Const :=
  { b with from_ := b.from_ ++ [item] }

/-- Set or extend the WHERE condition (ANDs with any existing condition). -/
def Builder.where_ {Const : Type} (b : Builder Const) (cond : SqlCondition Const) :
    Builder Const :=
  let newCond := match b.where_ with
    | none => cond
    | some existing => .andCond existing cond
  { b with where_ := some newCond }

/-- Set the GROUP BY clause. -/
def Builder.groupBy {Const : Type} (b : Builder Const) (keys : List (SqlExpr Const)) :
    Builder Const :=
  { b with groupBy := keys }

/-- Set the HAVING clause. -/
def Builder.having {Const : Type} (b : Builder Const) (cond : SqlCondition Const) :
    Builder Const :=
  { b with having := some cond }

/-- Add an ORDER BY item. -/
def Builder.orderBy {Const : Type} (b : Builder Const) (item : OrderByItem Const) :
    Builder Const :=
  { b with orderBy := b.orderBy ++ [item] }

/-- Set LIMIT. -/
def Builder.limit {Const : Type} (b : Builder Const) (n : Nat) : Builder Const :=
  { b with limit_ := some n }

/-- Set OFFSET. -/
def Builder.offset {Const : Type} (b : Builder Const) (n : Nat) : Builder Const :=
  { b with offset_ := some n }

/-- Finalize the builder into a `SelectQuery`. -/
def Builder.build {Const : Type} (b : Builder Const) : SelectQuery Const :=
  .select b.quant b.items b.from_ b.where_ b.groupBy b.having b.orderBy b.limit_ b.offset_

/-- Build and serialize the query to a SQL string. -/
def Builder.toSql {Const : Type} [ToString Const] (b : Builder Const) : String :=
  PgClient.toSql b.build

/-- Combine two queries with UNION ALL. -/
def unionAll {Const : Type} (l r : SelectQuery Const) : SelectQuery Const :=
  .setOp .unionOp .all l r

/-- Combine two queries with UNION DISTINCT. -/
def union {Const : Type} (l r : SelectQuery Const) : SelectQuery Const :=
  .setOp .unionOp .distinct l r

/-- Combine two queries with INTERSECT. -/
def intersect {Const : Type} (l r : SelectQuery Const) : SelectQuery Const :=
  .setOp .intersectOp .distinct l r

/-- Combine two queries with EXCEPT. -/
def except {Const : Type} (l r : SelectQuery Const) : SelectQuery Const :=
  .setOp .exceptOp .distinct l r

/-- Helper: build a simple equality condition. -/
def eq {Const : Type} (col : String) (val : SqlExpr Const) : SqlCondition Const :=
  .cmp .eq (.col col) val

/-- Helper: build a simple less-than condition. -/
def lt {Const : Type} (col : String) (val : SqlExpr Const) : SqlCondition Const :=
  .cmp .lt (.col col) val

/-- Helper: build a simple greater-than condition. -/
def gt {Const : Type} (col : String) (val : SqlExpr Const) : SqlCondition Const :=
  .cmp .gt (.col col) val

/-- Helper: build an IS NULL condition. -/
def isNull {Const : Type} (col : String) : SqlCondition Const :=
  .isNull (.col col)

/-- Helper: build an IS NOT NULL condition. -/
def isNotNull {Const : Type} (col : String) : SqlCondition Const :=
  .isNotNull (.col col)

/-- Builder roundtrip: `build` then `toSql` is equivalent to `PgClient.toSql ∘ build`. -/
theorem builder_toSql_eq_pgclient {Const : Type} [ToString Const] (b : Builder Const) :
    b.toSql = PgClient.toSql b.build := by
  simp [Builder.toSql]

end SWELibCode.Db.QueryBuilder
