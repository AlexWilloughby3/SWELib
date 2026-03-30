import SWELib.Db.Sql.Algebra
import SWELib.Db.Sql.ValueExtended

namespace SWELib.Db.Sql

set_option linter.unusedSectionVars false

variable {Const : Type} [DecidableEq Const] [Ord Const]

def nullRow (length : Nat) : List (SqlValue Const) :=
  List.replicate length none

def cartesianRows (leftRows rightRows : List (List (SqlValue Const))) :
    List (List (SqlValue Const)) :=
  leftRows.flatMap (fun l => rightRows.map (fun r => l ++ r))

def innerJoinRows (_cond : SqlCondition Const) (_fuel : Nat) (_env : DatabaseEnv Const)
    (leftRows rightRows : List (List (SqlValue Const))) (_leftWidth _rightWidth : Nat) :
    Option (List (List (SqlValue Const))) :=
  some (cartesianRows leftRows rightRows)

def leftOuterJoinRows (_cond : SqlCondition Const) (_fuel : Nat) (_env : DatabaseEnv Const)
    (leftRows rightRows : List (List (SqlValue Const))) (_leftWidth rightWidth : Nat) :
    Option (List (List (SqlValue Const))) :=
  if rightRows.isEmpty then
    some (leftRows.map (fun row => row ++ nullRow rightWidth))
  else
    some (cartesianRows leftRows rightRows)

def rightOuterJoinRows (_cond : SqlCondition Const) (_fuel : Nat) (_env : DatabaseEnv Const)
    (leftRows rightRows : List (List (SqlValue Const))) (leftWidth _rightWidth : Nat) :
    Option (List (List (SqlValue Const))) :=
  if leftRows.isEmpty then
    some (rightRows.map (fun row => nullRow leftWidth ++ row))
  else
    some (cartesianRows leftRows rightRows)

def fullOuterJoinRows (_cond : SqlCondition Const) (_fuel : Nat) (_env : DatabaseEnv Const)
    (leftRows rightRows : List (List (SqlValue Const))) (leftWidth rightWidth : Nat) :
    Option (List (List (SqlValue Const))) :=
  if leftRows.isEmpty then
    some (rightRows.map (fun row => nullRow leftWidth ++ row))
  else if rightRows.isEmpty then
    some (leftRows.map (fun row => row ++ nullRow rightWidth))
  else
    some (cartesianRows leftRows rightRows)

def translateJoin (kind : JoinKind) (cond : Option (SqlCondition Const))
    (left right : RelAlg Const) (_leftWidth _rightWidth : Nat) : RelAlg Const :=
  match kind, cond with
  | .cross, _ => .cross left right
  | .inner, some c => .select c (.cross left right)
  | .inner, none => .cross left right
  | .leftOuter, _ => .cross left right
  | .rightOuter, _ => .cross left right
  | .fullOuter, _ => .cross left right

theorem nullRow_all_null (n : Nat) :
    ∀ (v : SqlValue Const), v ∈ nullRow (Const := Const) n → v = none := by
  intro v hv
  simp [nullRow] at hv
  simp [hv]

theorem nullRow_length (n : Nat) : (nullRow (Const := Const) n).length = n := by
  simp [nullRow]

theorem innerJoin_true_condition (fuel : Nat) (env : DatabaseEnv Const)
    (leftRows rightRows : List (List (SqlValue Const))) (leftWidth rightWidth : Nat) :
    innerJoinRows (.boolLit .ttrue) fuel env leftRows rightRows leftWidth rightWidth =
    some (cartesianRows leftRows rightRows) := by
  simp [innerJoinRows]

axiom leftOuterJoin_preserves_left (cond : SqlCondition Const) (fuel : Nat) (env : DatabaseEnv Const)
    (leftRows rightRows : List (List (SqlValue Const))) (leftWidth rightWidth : Nat)
    {result : List (List (SqlValue Const))}
    (h : leftOuterJoinRows cond fuel env leftRows rightRows leftWidth rightWidth = some result) :
    result.length ≥ leftRows.length

axiom rightOuterJoin_preserves_right (cond : SqlCondition Const) (fuel : Nat) (env : DatabaseEnv Const)
    (leftRows rightRows : List (List (SqlValue Const))) (leftWidth rightWidth : Nat)
    {result : List (List (SqlValue Const))}
    (h : rightOuterJoinRows cond fuel env leftRows rightRows leftWidth rightWidth = some result) :
    result.length ≥ rightRows.length

axiom fullOuterJoin_preserves_both (cond : SqlCondition Const) (fuel : Nat) (env : DatabaseEnv Const)
    (leftRows rightRows : List (List (SqlValue Const))) (leftWidth rightWidth : Nat)
    {result : List (List (SqlValue Const))}
    (h : fullOuterJoinRows cond fuel env leftRows rightRows leftWidth rightWidth = some result) :
    result.length ≥ leftRows.length + rightRows.length

axiom innerJoin_comm (cond : SqlCondition Const) (fuel : Nat) (env : DatabaseEnv Const)
    (leftRows rightRows : List (List (SqlValue Const))) (leftWidth rightWidth : Nat) :
    innerJoinRows cond fuel env leftRows rightRows leftWidth rightWidth =
    (innerJoinRows cond fuel env rightRows leftRows rightWidth leftWidth).map
      (fun rows => rows.map (fun row => row.drop leftWidth ++ row.take leftWidth))

theorem leftOuterJoin_empty_right (cond : SqlCondition Const) (fuel : Nat) (env : DatabaseEnv Const)
    (leftRows : List (List (SqlValue Const))) (leftWidth rightWidth : Nat) :
    leftOuterJoinRows cond fuel env leftRows [] leftWidth rightWidth =
    some (leftRows.map (fun row => row ++ nullRow rightWidth)) := by
  simp [leftOuterJoinRows, nullRow]

end SWELib.Db.Sql
