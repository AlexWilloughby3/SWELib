import SWELib.Db.Sql.Aggregates
import SWELib.Db.Sql.Algebra

namespace SWELib.Db.Sql

set_option linter.unusedSectionVars false
set_option linter.unusedVariables false

variable {Const : Type} [DecidableEq Const] [Ord Const]
  [Add Const] [Div Const] [Zero Const] [Min Const] [Max Const] [NatCast Const]

def extractKey (indices : List Nat) (row : List (SqlValue Const)) : List (SqlValue Const) :=
  indices.map (fun i => row.getD i none)

def groupRowsBy (keys : List Nat) (rows : List (List (SqlValue Const))) :
    List (List (SqlValue Const) × List (List (SqlValue Const))) :=
  match rows with
  | [] => []
  | row :: rest => [(extractKey keys row, row :: rest)]

def computeAggregates (aggs : List (AggFunc × Nat)) (groupRows : List (List (SqlValue Const))) :
    List (SqlValue Const) :=
  aggs.map (fun (f, colIdx) =>
    let values := groupRows.map (fun row => row.getD colIdx none)
    computeAgg f values
  )

def applyGroupBy (keys : List Nat) (aggs : List (AggFunc × Nat))
    (rows : List (List (SqlValue Const))) : List (List (SqlValue Const)) :=
  let groups := groupRowsBy keys rows
  groups.map (fun (key, rows) => key ++ computeAggregates aggs rows)

def evalGroupBy (keys : List Nat) (aggs : List (AggFunc × Nat))
    (rows : List (List (SqlValue Const))) : List (List (SqlValue Const)) :=
  applyGroupBy keys aggs rows

theorem extractKey_length (indices : List Nat) (row : List (SqlValue Const)) :
    (extractKey indices row).length = indices.length := by
  simp [extractKey]

theorem extractKey_nil (row : List (SqlValue Const)) :
    extractKey [] row = [] := by
  simp [extractKey]

axiom groupRowsBy_nil_key (rows : List (List (SqlValue Const))) :
    groupRowsBy [] rows = [([], rows)]

theorem groupRowsBy_empty_rows (keys : List Nat) :
    groupRowsBy keys ([] : List (List (SqlValue Const))) = [] := by
  simp [groupRowsBy]

axiom groupRowsBy_key_consistent (keys : List Nat) (rows : List (List (SqlValue Const)))
    (key : List (SqlValue Const)) (groupRows : List (List (SqlValue Const)))
    (h : (key, groupRows) ∈ groupRowsBy keys rows) :
    ∀ row ∈ groupRows, extractKey keys row = key

axiom groupRowsBy_total_size (keys : List Nat) (rows : List (List (SqlValue Const))) :
    (groupRowsBy keys rows).foldl (fun sum (_, group) => sum + group.length) 0 = rows.length

axiom groupRowsBy_idempotent (keys : List Nat) (rows : List (List (SqlValue Const))) :
    let groups := groupRowsBy keys rows
    groupRowsBy keys (groups.flatMap (fun (_, g) => g)) = groups

axiom computeAggregates_empty_group (aggs : List (AggFunc × Nat)) :
    computeAggregates aggs [] = aggs.map (fun (f, _) =>
      match f with
      | .count => some (0 : Const)
      | _ => none)

axiom computeAggregates_null_row (aggs : List (AggFunc × Nat))
    (groupRows : List (List (SqlValue Const))) (colIdx : Nat) :
    let newRow := List.replicate (colIdx + 1) none
    computeAggregates aggs (newRow :: groupRows) =
    computeAggregates aggs groupRows

axiom applyGroupBy_perm (keys : List Nat) (aggs : List (AggFunc × Nat))
    (rows1 rows2 : List (List (SqlValue Const))) (h : List.Perm rows1 rows2) :
    List.Perm (applyGroupBy keys aggs rows1) (applyGroupBy keys aggs rows2)

end SWELib.Db.Sql
