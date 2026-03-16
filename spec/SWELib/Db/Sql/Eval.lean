import SWELib.Db.Sql.WellFormedness
import SWELib.Db.Sql.ValueExtended

set_option linter.unusedSectionVars false

/-!
# SQL Fuel-Based Evaluator

Defines a denotational-style evaluator for SQL queries using a fuel parameter
for termination of mutually recursive evaluation. Returns `none` when fuel is
exhausted. The evaluator works over a `DatabaseEnv` mapping table names to
raw value rows, and an `EvalCtx` providing the current row bindings for
expression evaluation (SQL:2023 Section 4.34).

The evaluator returns raw value lists rather than schema-indexed tuples to
avoid dependent-typing complexity in the mutual recursion. Schema tracking
is handled separately via `WellFormedness`.
-/

namespace SWELib.Db.Sql

variable {Const : Type} [DecidableEq Const] [Ord Const]
  [Add Const] [Sub Const] [Mul Const] [Div Const] [Mod Const]
  [Append Const] [Neg Const] [Zero Const] [OfNat Const 0] [NatCast Const]

/-- A database environment: maps table names to their contents.
    Each table is a list of rows, where each row is a list of SQL values. -/
structure DatabaseEnv (Const : Type) where
  /-- Look up a table by name, returning its rows. -/
  tables : TableName -> Option (List (List (SqlValue Const)))

/-- Evaluation context: provides column bindings for the current row. -/
structure EvalCtx (Const : Type) where
  /-- Current row's column values, keyed by attribute name. -/
  bindings : List (AttrName × SqlValue Const)

/-- Look up a column value in the evaluation context by name. -/
def EvalCtx.lookup (ctx : EvalCtx Const) (name : AttrName) : Option (SqlValue Const) :=
  match ctx.bindings.find? (fun p => p.1 == name) with
  | some (_, v) => some v
  | none => none

/-- Look up a qualified column (table.column) in the evaluation context. -/
def EvalCtx.lookupQual (ctx : EvalCtx Const) (table : TableName) (name : AttrName) : Option (SqlValue Const) :=
  -- Simplified: looks for "table.name" as a combined key
  ctx.lookup (table ++ "." ++ name)

/-- Merge two evaluation contexts (for joins). -/
def EvalCtx.merge (ctx1 ctx2 : EvalCtx Const) : EvalCtx Const :=
  ⟨ctx1.bindings ++ ctx2.bindings⟩

/-- The empty evaluation context. -/
def EvalCtx.empty : EvalCtx Const := ⟨[]⟩

/-- Build an evaluation context from a raw row using positional names ("0", "1", ...).
    This passes row values to condition evaluation so WHERE clauses can access column
    data. For named column access, use `mkCtx` with explicit schema names. -/
def EvalCtx.fromRow (row : List (SqlValue Const)) : EvalCtx Const :=
  ⟨row.mapIdx (fun i v => (toString i, v))⟩

/-- Apply a comparison operator to two SQL values, yielding a Tribool. -/
def applyCmp (op : CmpOp) (v1 v2 : SqlValue Const) : Tribool :=
  match op with
  | .eq => veq v1 v2
  | .ne => (veq v1 v2).not
  | .lt => vlt v1 v2
  | .ge => (vlt v1 v2).not
  | .gt => vlt v2 v1
  | .le => (vlt v2 v1).not

/-- Build an evaluation context from a list of column names and a row of values. -/
def mkCtx (cols : List AttrName) (row : List (SqlValue Const)) : EvalCtx Const :=
  ⟨cols.zip row⟩

mutual

/-- Evaluate a SQL expression in the given context.
    Returns `none` when fuel is exhausted. -/
def evalExpr (fuel : Nat) (env : DatabaseEnv Const) (ctx : EvalCtx Const) :
    SqlExpr Const -> Option (SqlValue Const)
  | .lit v => some (some v)
  | .null => some none
  | .col name => some (ctx.lookup name |>.getD none)
  | .qualCol table name => some (ctx.lookupQual table name |>.getD none)
  | .binOp op l r => match fuel with
    | 0 => none
    | fuel' + 1 => do
      let v1 <- evalExpr fuel' env ctx l
      let v2 <- evalExpr fuel' env ctx r
      pure (applyBinOp op v1 v2)
  | .unOp op e => match fuel with
    | 0 => none
    | fuel' + 1 => do
      let v <- evalExpr fuel' env ctx e
      pure (applyUnOp op v)
  | .agg _ _ _ => none  -- aggregates handled at query level
  | .countStar => none   -- aggregates handled at query level
  | .caseExpr _ _ => match fuel with
    | 0 => none
    | _ + 1 => none  -- simplified: case expressions deferred
  | .scalarSubquery q => match fuel with
    | 0 => none
    | fuel' + 1 => do
      let rows <- evalQuery fuel' env q
      match rows with
      | [row] => match row with
        | [v] => some v
        | _ => none
      | _ => none
  | .coalesce args => match fuel with
    | 0 => none
    | fuel' + 1 => evalCoalesceArgs fuel' env ctx args
  | .cast e _ => match fuel with
    | 0 => none
    | fuel' + 1 => evalExpr fuel' env ctx e  -- simplified: no actual cast

/-- Evaluate a SQL condition in the given context, yielding a Tribool.
    Returns `none` when fuel is exhausted. -/
def evalCond (fuel : Nat) (env : DatabaseEnv Const) (ctx : EvalCtx Const) :
    SqlCondition Const -> Option Tribool
  | .boolLit v => some v
  | .cmp op l r => match fuel with
    | 0 => none
    | fuel' + 1 => do
      let v1 <- evalExpr fuel' env ctx l
      let v2 <- evalExpr fuel' env ctx r
      pure (applyCmp op v1 v2)
  | .andCond l r => match fuel with
    | 0 => none
    | fuel' + 1 => do
      let t1 <- evalCond fuel' env ctx l
      let t2 <- evalCond fuel' env ctx r
      pure (t1.and t2)
  | .orCond l r => match fuel with
    | 0 => none
    | fuel' + 1 => do
      let t1 <- evalCond fuel' env ctx l
      let t2 <- evalCond fuel' env ctx r
      pure (t1.or t2)
  | .notCond c => match fuel with
    | 0 => none
    | fuel' + 1 => do
      let t <- evalCond fuel' env ctx c
      pure t.not
  | .isNull e => match fuel with
    | 0 => none
    | fuel' + 1 => do
      let v <- evalExpr fuel' env ctx e
      pure (if v.isNone then .ttrue else .tfalse)
  | .isNotNull e => match fuel with
    | 0 => none
    | fuel' + 1 => do
      let v <- evalExpr fuel' env ctx e
      pure (if v.isSome then .ttrue else .tfalse)
  | .inSubquery e q => match fuel with
    | 0 => none
    | fuel' + 1 => do
      let v <- evalExpr fuel' env ctx e
      let rows <- evalQuery fuel' env q
      let vals := rows.filterMap (fun r => r.head?)
      pure (if vals.any (fun rv => (veq v rv).isTrue) then .ttrue else .tfalse)
  | .exists_ q => match fuel with
    | 0 => none
    | fuel' + 1 => do
      let rows <- evalQuery fuel' env q
      pure (if rows.isEmpty then .tfalse else .ttrue)
  | .between e lo hi => match fuel with
    | 0 => none
    | fuel' + 1 => do
      let v <- evalExpr fuel' env ctx e
      let vlo <- evalExpr fuel' env ctx lo
      let vhi <- evalExpr fuel' env ctx hi
      let geqLo := (vlt v vlo).not
      let leqHi := (vlt vhi v).not
      pure (geqLo.and leqHi)
  | .like _ _ => some .tunknown  -- simplified: LIKE not fully implemented

/-- Evaluate a COALESCE argument list. -/
def evalCoalesceArgs (fuel : Nat) (env : DatabaseEnv Const) (ctx : EvalCtx Const) :
    List (SqlExpr Const) -> Option (SqlValue Const)
  | [] => some none
  | e :: rest => match fuel with
    | 0 => none
    | fuel' + 1 => do
      let v <- evalExpr fuel' env ctx e
      match v with
      | some c => pure (some c)
      | none => evalCoalesceArgs fuel' env ctx rest

/-- Evaluate a SQL query, returning a list of raw value rows.
    Returns `none` when fuel is exhausted. -/
def evalQuery (fuel : Nat) (env : DatabaseEnv Const) :
    SelectQuery Const -> Option (List (List (SqlValue Const)))
  | .select _quant _items from_ where_ _groupBy _having _orderBy _limit _offset =>
    match fuel with
    | 0 => none
    | fuel' + 1 => do
      -- Step 1: Evaluate FROM clause to get base rows
      let baseRows <- evalFromList fuel' env from_
      -- Step 2: Apply WHERE filter
      let filtered <- filterRows fuel' env baseRows where_
      -- Step 3: Return the filtered rows (projection/grouping simplified)
      pure filtered
  | .setOp op _quant l r => match fuel with
    | 0 => none
    | fuel' + 1 => do
      let lr <- evalQuery fuel' env l
      let rr <- evalQuery fuel' env r
      match op with
      | .unionOp => pure (lr ++ rr)
      | .intersectOp => pure (lr.filter (fun row => rr.any (· == row)))
      | .exceptOp => pure (lr.filter (fun row => !(rr.any (· == row))))

/-- Evaluate a FROM clause item, returning rows with column name context. -/
def evalFrom (fuel : Nat) (env : DatabaseEnv Const) :
    FromItem Const -> Option (List (List (SqlValue Const)))
  | .table name _ => pure (env.tables name |>.getD [])
  | .subquery q _ => match fuel with
    | 0 => none
    | fuel' + 1 => evalQuery fuel' env q
  | .join .cross l r _ => match fuel with
    | 0 => none
    | fuel' + 1 => do
      let lr <- evalFrom fuel' env l
      let rr <- evalFrom fuel' env r
      pure (lr.flatMap (fun lrow => rr.map (fun rrow => lrow ++ rrow)))
  | .join _kind l r on_ => match fuel with
    | 0 => none
    | fuel' + 1 => do
      let lr <- evalFrom fuel' env l
      let rr <- evalFrom fuel' env r
      let crossed := lr.flatMap (fun lrow => rr.map (fun rrow => lrow ++ rrow))
      match on_ with
      | none => pure crossed
      | some cond =>
        pure (crossed.filter (fun row =>
          match evalCond fuel' env (EvalCtx.fromRow row) cond with
          | some t => t.isTrue
          | none => false))

/-- Evaluate a list of FROM items (implicit cross join). -/
def evalFromList (fuel : Nat) (env : DatabaseEnv Const) :
    List (FromItem Const) -> Option (List (List (SqlValue Const)))
  | [] => pure [[]]
  | f :: rest => match fuel with
    | 0 => none
    | fuel' + 1 => do
      let fRows <- evalFrom fuel' env f
      let restRows <- evalFromList fuel' env rest
      pure (fRows.flatMap (fun frow => restRows.map (fun rrow => frow ++ rrow)))

/-- Filter rows by an optional WHERE condition. -/
def filterRows (fuel : Nat) (env : DatabaseEnv Const)
    (rows : List (List (SqlValue Const)))
    (where_ : Option (SqlCondition Const)) :
    Option (List (List (SqlValue Const))) :=
  match where_ with
  | none => pure rows
  | some cond => match fuel with
    | 0 => none
    | fuel' + 1 =>
      pure (rows.filter (fun row =>
        match evalCond fuel' env (EvalCtx.fromRow row) cond with
        | some t => t.isTrue
        | none => false))

end

/-- With sufficient fuel, literal evaluation always succeeds. -/
theorem evalExpr_lit (env : DatabaseEnv Const) (ctx : EvalCtx Const) (v : Const) (fuel : Nat) :
    evalExpr fuel env ctx (.lit v) = some (some v) := by
  simp [evalExpr]

/-- With sufficient fuel, NULL evaluation always succeeds. -/
theorem evalExpr_null (env : DatabaseEnv Const) (ctx : EvalCtx Const) (fuel : Nat) :
    evalExpr fuel env ctx (.null : SqlExpr Const) = some none := by
  simp [evalExpr]

end SWELib.Db.Sql
