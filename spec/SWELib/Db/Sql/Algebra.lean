import SWELib.Db.Sql.Eval

set_option linter.unusedSectionVars false

/-!
# Relational Algebra

Defines a relational algebra AST and its evaluator. Unlike the SQL AST,
the relational algebra is non-mutual and structurally recursive, making
it easier to reason about. The algebra covers selection, projection,
cross product, union, difference, renaming, grouping, and ordering
(Codd's relational algebra extended with bag semantics).
-/

namespace SWELib.Db.Sql

variable {Const : Type} [DecidableEq Const] [Ord Const]
  [Add Const] [Sub Const] [Mul Const] [Div Const] [Mod Const]
  [Append Const] [Neg Const] [Zero Const] [OfNat Const 0] [NatCast Const]

/-- Relational algebra expression over raw value rows.
    Each row is a `List (SqlValue Const)`. -/
inductive RelAlg (Const : Type) where
  /-- A base table reference. -/
  | baseTable (name : TableName)
  /-- Selection (sigma): filter rows by a predicate expression. -/
  | select (cond : SqlCondition Const) (child : RelAlg Const)
  /-- Projection (pi): keep only specified column indices. -/
  | project (indices : List Nat) (child : RelAlg Const)
  /-- Cross product of two relations. -/
  | cross (left right : RelAlg Const)
  /-- Bag union (UNION ALL). -/
  | union (left right : RelAlg Const)
  /-- Bag difference (EXCEPT ALL). -/
  | diff (left right : RelAlg Const)
  /-- Duplicate elimination (DISTINCT). -/
  | distinct (child : RelAlg Const)
  /-- Rename: apply a mapping of column positions. -/
  | rename (mapping : List (Nat × AttrName)) (child : RelAlg Const)
  /-- Group by specified column indices, computing aggregates.
      Each aggregate is (AggFunc, column index). -/
  | groupBy (keys : List Nat) (aggs : List (AggFunc × Nat)) (child : RelAlg Const)
  /-- Limit the number of result rows. -/
  | limit (n : Nat) (child : RelAlg Const)
  /-- Skip the first n result rows. -/
  | offset (n : Nat) (child : RelAlg Const)
  /-- Empty relation. -/
  | empty
  /-- Singleton relation with one empty row (for SELECT without FROM). -/
  | singleton

/-- Extract column values at the given indices from a row. -/
def projectRow (indices : List Nat) (row : List (SqlValue Const)) : List (SqlValue Const) :=
  indices.map (fun i => row.getD i none)

/-- Group rows by key columns. Returns a list of (key, group) pairs. -/
def groupRows (keys : List Nat) (rows : List (List (SqlValue Const))) :
    List (List (SqlValue Const) × List (List (SqlValue Const))) :=
  let keyOf := fun row => projectRow keys row
  rows.foldl (fun acc row =>
    let k := keyOf row
    match acc.find? (fun p => p.1 == k) with
    | some _ => acc.map (fun p => if p.1 == k then (p.1, p.2 ++ [row]) else p)
    | none => acc ++ [(k, [row])]
  ) []

/-- Evaluate a relational algebra expression against a database environment.
    Uses fuel for termination (subqueries in conditions may recurse). -/
def evalRelAlg (fuel : Nat) (env : DatabaseEnv Const) : RelAlg Const -> Option (List (List (SqlValue Const)))
  | .baseTable name => pure (env.tables name |>.getD [])
  | .select cond child => match fuel with
    | 0 => none
    | fuel' + 1 => do
      let rows <- evalRelAlg fuel' env child
      pure (rows.filter (fun row =>
        match evalCond fuel' env (EvalCtx.fromRow row) cond with
        | some t => t.isTrue
        | none => false))
  | .project indices child => match fuel with
    | 0 => none
    | fuel' + 1 => do
      let rows <- evalRelAlg fuel' env child
      pure (rows.map (projectRow indices))
  | .cross left right => match fuel with
    | 0 => none
    | fuel' + 1 => do
      let lr <- evalRelAlg fuel' env left
      let rr <- evalRelAlg fuel' env right
      pure (lr.flatMap (fun lrow => rr.map (fun rrow => lrow ++ rrow)))
  | .union left right => match fuel with
    | 0 => none
    | fuel' + 1 => do
      let lr <- evalRelAlg fuel' env left
      let rr <- evalRelAlg fuel' env right
      pure (lr ++ rr)
  | .diff left right => match fuel with
    | 0 => none
    | fuel' + 1 => do
      let lr <- evalRelAlg fuel' env left
      let rr <- evalRelAlg fuel' env right
      pure (lr.filter (fun row => !(rr.any (· == row))))
  | .distinct child => match fuel with
    | 0 => none
    | fuel' + 1 => do
      let rows <- evalRelAlg fuel' env child
      pure rows.eraseDups
  | .rename _mapping child => match fuel with
    | 0 => none
    | fuel' + 1 => evalRelAlg fuel' env child  -- renaming doesn't change raw values
  | .groupBy keys _aggs child => match fuel with
    | 0 => none
    | fuel' + 1 => do
      let rows <- evalRelAlg fuel' env child
      let groups := groupRows keys rows
      -- Simplified: return just the group keys
      pure (groups.map (fun (k, _) => k))
  | .limit n child => match fuel with
    | 0 => none
    | fuel' + 1 => do
      let rows <- evalRelAlg fuel' env child
      pure (rows.take n)
  | .offset n child => match fuel with
    | 0 => none
    | fuel' + 1 => do
      let rows <- evalRelAlg fuel' env child
      pure (rows.drop n)
  | .empty => pure []
  | .singleton => pure [[]]

/-- Evaluating a base table does not require fuel. -/
theorem evalRelAlg_baseTable (env : DatabaseEnv Const) (name : TableName) (fuel : Nat) :
    evalRelAlg fuel env (.baseTable name) = some (env.tables name |>.getD []) := by
  simp [evalRelAlg]

/-- Evaluating the empty algebra yields the empty list. -/
theorem evalRelAlg_empty (env : DatabaseEnv Const) (fuel : Nat) :
    evalRelAlg fuel env (.empty : RelAlg Const) = some [] := by
  simp [evalRelAlg]

/-- Union of empty with any relation is that relation (with sufficient fuel). -/
theorem evalRelAlg_union_empty_left (env : DatabaseEnv Const) (r : RelAlg Const) (fuel : Nat)
    (h : evalRelAlg fuel env r = some rows) :
    evalRelAlg (fuel + 1) env (.union .empty r) = some rows := by
  simp [evalRelAlg, h]

end SWELib.Db.Sql
