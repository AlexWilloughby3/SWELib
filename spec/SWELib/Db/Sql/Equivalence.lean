import SWELib.Db.Sql.Eval
import SWELib.Db.Sql.Algebra
import SWELib.Db.Sql.Translation

namespace SWELib.Db.Sql

set_option linter.unusedSectionVars false

variable {Const : Type} [DecidableEq Const] [Ord Const]
  [Add Const] [Sub Const] [Mul Const] [Div Const] [Mod Const] [Append Const]
  [Neg Const] [Zero Const] [OfNat Const 0] [NatCast Const]

axiom translation_soundness (fuel : Nat) (env : DatabaseEnv Const) (q : SelectQuery Const) :
    evalQuery fuel env q = evalRelAlg fuel env (translate q)

theorem translation_preserves_nonempty (fuel : Nat) (env : DatabaseEnv Const) (q : SelectQuery Const)
    (h : evalQuery fuel env q ≠ some []) :
    evalRelAlg fuel env (translate q) ≠ some [] := by
  intro h2
  apply h
  rw [translation_soundness fuel env q]
  exact h2

axiom translate_simple_table (name : TableName) (alias_ : Option TableName) :
    translate (.select .all [.star] [.table name alias_] none [] none [] none none) =
      (.baseTable name : RelAlg Const)

axiom translate_union_all (l r : SelectQuery Const) :
    translate (.setOp .unionOp .all l r) = .union (translate l) (translate r)

axiom translate_with_where (q : SelectQuery Const) (cond : SqlCondition Const) :
    translate (match q with
      | .select quant items from_ _ groupBy having orderBy limit offset =>
        .select quant items from_ (some cond) groupBy having orderBy limit offset
      | _ => q) =
    match translate q with
    | .select c child => .select c child
    | child => .select cond child

axiom translate_empty :
    translate (.select .all ([] : List (SelectItem Const)) [] none [] none [] none none) =
      (.empty : RelAlg Const)

axiom translate_singleton (items : List (SelectItem Const)) :
    translate (.select .all items [] none [] none [] none none) = .singleton

end SWELib.Db.Sql
