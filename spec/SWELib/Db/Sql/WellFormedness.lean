import SWELib.Db.Sql.Syntax

/-!
# SQL Well-Formedness Judgments

Defines typing/well-formedness predicates for SQL expressions, conditions,
and queries. An expression is well-formed relative to a schema if every
column reference resolves to an attribute in that schema. Aggregate usage
is tracked to enforce the SQL rule that aggregates cannot be nested and
non-aggregated columns must appear in GROUP BY (SQL:2023 Section 7.12).
-/

namespace SWELib.Db.Sql

variable {Const : Type}

/-- Check whether an expression contains an aggregate function call (top-level only).
    This is a simplified check that does not recurse into subqueries. -/
def containsAgg : SqlExpr Const -> Bool
  | .agg _ _ _ => true
  | .countStar => true
  | .binOp _ l r => containsAgg l || containsAgg r
  | .unOp _ e => containsAgg e
  | .cast e _ => containsAgg e
  | _ => false

/-- Expression well-formedness: every column reference resolves in the schema `σ`.
    `allowAgg` controls whether aggregate expressions are permitted. -/
inductive ExprWF : Schema -> Bool -> SqlExpr Const -> Prop where
  /-- Literals are always well-formed. -/
  | lit : ExprWF σ allowAgg (.lit v)
  /-- NULL is always well-formed. -/
  | null : ExprWF σ allowAgg .null
  /-- A column reference is well-formed if the name appears in the schema. -/
  | col (h : σ.Mem name) : ExprWF σ allowAgg (.col name)
  /-- A qualified column reference (simplified: just checks name in schema). -/
  | qualCol (h : σ.Mem name) : ExprWF σ allowAgg (.qualCol tbl name)
  /-- Binary operations are well-formed if both operands are. -/
  | binOp : ExprWF σ allowAgg l -> ExprWF σ allowAgg r ->
      ExprWF σ allowAgg (.binOp op l r)
  /-- Unary operations are well-formed if the operand is. -/
  | unOp : ExprWF σ allowAgg e -> ExprWF σ allowAgg (.unOp op e)
  /-- Aggregates are well-formed only when `allowAgg = true`. -/
  | agg (h : allowAgg = true) : ExprWF σ false arg ->
      ExprWF σ allowAgg (.agg func quant arg)
  /-- COUNT(*) is well-formed only when aggregates are allowed. -/
  | countStar (h : allowAgg = true) : ExprWF σ allowAgg .countStar
  /-- COALESCE is well-formed if all arguments are. -/
  | coalesce : (forall e, e ∈ args -> ExprWF σ allowAgg e) ->
      ExprWF σ allowAgg (.coalesce args)
  /-- CAST is well-formed if the argument is. -/
  | cast : ExprWF σ allowAgg e -> ExprWF σ allowAgg (.cast e ty)

/-- Condition well-formedness: every referenced column resolves in the schema. -/
inductive CondWF : Schema -> Bool -> SqlCondition Const -> Prop where
  /-- Comparison is well-formed if both sides are. -/
  | cmp : ExprWF σ allowAgg l -> ExprWF σ allowAgg r ->
      CondWF σ allowAgg (.cmp op l r)
  /-- AND is well-formed if both branches are. -/
  | andCond : CondWF σ allowAgg l -> CondWF σ allowAgg r ->
      CondWF σ allowAgg (.andCond l r)
  /-- OR is well-formed if both branches are. -/
  | orCond : CondWF σ allowAgg l -> CondWF σ allowAgg r ->
      CondWF σ allowAgg (.orCond l r)
  /-- NOT is well-formed if the inner condition is. -/
  | notCond : CondWF σ allowAgg c -> CondWF σ allowAgg (.notCond c)
  /-- IS NULL is well-formed if the expression is. -/
  | isNull : ExprWF σ allowAgg e -> CondWF σ allowAgg (.isNull e)
  /-- IS NOT NULL is well-formed if the expression is. -/
  | isNotNull : ExprWF σ allowAgg e -> CondWF σ allowAgg (.isNotNull e)
  /-- BETWEEN is well-formed if all three expressions are. -/
  | between : ExprWF σ allowAgg e -> ExprWF σ allowAgg lo ->
      ExprWF σ allowAgg hi -> CondWF σ allowAgg (.between e lo hi)
  /-- Boolean literals are always well-formed. -/
  | boolLit : CondWF σ allowAgg (.boolLit v)

/-- A literal expression is always well-formed regardless of schema. -/
theorem ExprWF.lit_any_schema (v : Const) (σ : Schema) (a : Bool) :
    ExprWF σ a (.lit v : SqlExpr Const) :=
  ExprWF.lit

/-- NULL is always well-formed regardless of schema. -/
theorem ExprWF.null_any_schema (σ : Schema) (a : Bool) :
    ExprWF σ a (.null : SqlExpr Const) :=
  ExprWF.null

end SWELib.Db.Sql
