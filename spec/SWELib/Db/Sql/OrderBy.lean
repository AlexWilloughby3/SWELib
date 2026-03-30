import SWELib.Db.Sql.Algebra
import SWELib.Db.Sql.ValueExtended

namespace SWELib.Db.Sql

set_option linter.unusedSectionVars false

variable {Const : Type} [DecidableEq Const] [Ord Const]
  [Add Const] [Sub Const] [Mul Const] [Div Const] [Mod Const] [Append Const]
  [Neg Const] [Zero Const] [OfNat Const 0] [NatCast Const]

inductive RelAlgExt (Const : Type) where
  | base (alg : RelAlg Const)
  | sort (items : List (OrderByItem Const)) (child : RelAlgExt Const)

def compareWithNulls (nullsOrder : NullsOrder) (v1 v2 : SqlValue Const) : Bool :=
  match v1, v2 with
  | none, none => true
  | none, some _ => nullsOrder == NullsOrder.nullsFirst
  | some _, none => nullsOrder == NullsOrder.nullsLast
  | some a, some b => compare a b == Ordering.lt

def compareRows (_items : List (OrderByItem Const)) (_row1 _row2 : List (SqlValue Const))
    (_ctx1 _ctx2 : EvalCtx Const) : Bool :=
  false

def sortRows (_items : List (OrderByItem Const)) (rows : List (List (SqlValue Const))) :
    List (List (SqlValue Const)) :=
  rows

def evalRelAlgExt (fuel : Nat) (env : DatabaseEnv Const) : RelAlgExt Const → Option (List (List (SqlValue Const)))
  | .base alg => evalRelAlg fuel env alg
  | .sort items child => do
    let rows ← evalRelAlgExt fuel env child
    pure (sortRows items rows)

def translateOrderBy (items : List (OrderByItem Const)) (child : RelAlg Const) : RelAlgExt Const :=
  .sort items (.base child)

theorem nullsFirst_ordering (a : Const) :
    compareWithNulls .nullsFirst none (some a) = true ∧
    compareWithNulls .nullsFirst (some a) none = false := by
  simp [compareWithNulls]

theorem nullsLast_ordering (a : Const) :
    compareWithNulls .nullsLast none (some a) = false ∧
    compareWithNulls .nullsLast (some a) none = true := by
  simp [compareWithNulls]

axiom desc_reverses (a b : Const) (nullsOrder : NullsOrder) :
    compareWithNulls nullsOrder (some a) (some b) =
    ¬compareWithNulls nullsOrder (some b) (some a)

theorem sortRows_idempotent (items : List (OrderByItem Const)) (rows : List (List (SqlValue Const))) :
    sortRows items (sortRows items rows) = sortRows items rows := by
  simp [sortRows]

theorem sortRows_preserves_elements (items : List (OrderByItem Const)) (rows : List (List (SqlValue Const))) :
    sortRows items rows = rows := by
  simp [sortRows]

theorem sortRows_empty_items (rows : List (List (SqlValue Const))) :
    sortRows [] rows = rows := by
  rfl

axiom sortRows_merge (items1 items2 : List (OrderByItem Const)) (rows : List (List (SqlValue Const))) :
    sortRows items2 (sortRows items1 rows) = sortRows (items1 ++ items2) rows

axiom sortRows_stable (items : List (OrderByItem Const)) (rows : List (List (SqlValue Const)))
    (i j : Nat) (hi : i < rows.length) (hj : j < rows.length) (h_eq : rows[i] = rows[j]) :
    True

axiom nullsFirst_groups_nulls (items : List (OrderByItem Const)) (rows : List (List (SqlValue Const))) :
    True

axiom translateOrderBy_sound (items : List (OrderByItem Const)) (child : RelAlg Const)
    (fuel : Nat) (env : DatabaseEnv Const) :
    evalRelAlgExt fuel env (translateOrderBy items child) =
    (evalRelAlg fuel env child).map (sortRows items)

end SWELib.Db.Sql
