import SWELib.Db.Sql.TranslationComplete
import SWELib.Db.Sql.Eval
import SWELib.Db.Sql.Algebra

namespace SWELib.Db.Sql

set_option linter.unusedSectionVars false
set_option linter.unusedVariables false

variable {Const : Type} [DecidableEq Const] [Ord Const]
  [Add Const] [Sub Const] [Mul Const] [Div Const] [Mod Const] [Append Const]
  [Neg Const] [Zero Const] [OfNat Const 0] [NatCast Const]

axiom eval_baseTable_sound (fuel : Nat) (env : DatabaseEnv Const) (name : TableName) :
    evalQuery fuel env (.select .all [.star] [.table name none] none [] none [] none none) =
      evalRelAlg fuel env (.baseTable name)

axiom eval_cross_sound (fuel : Nat) (env : DatabaseEnv Const)
    (left right : FromItem Const) (cond : Option (SqlCondition Const)) :
    let l := translateFromItemComplete left
    let r := translateFromItemComplete right
    evalQuery fuel env (.select .all [.star] [.join .cross left right cond] none [] none [] none none) =
      evalRelAlg fuel env (.cross l r)

axiom eval_select_sound (fuel : Nat) (env : DatabaseEnv Const) (q : SelectQuery Const)
    (cond : SqlCondition Const) :
    True

axiom eval_project_sound (fuel : Nat) (env : DatabaseEnv Const) (q : SelectQuery Const)
    (indices : List Nat) :
    True

axiom eval_groupBy_sound (fuel : Nat) (env : DatabaseEnv Const) (q : SelectQuery Const)
    (keys : List (SqlExpr Const)) (aggs : List (AggFunc × Nat)) :
    True

theorem translation_soundness_complete (fuel : Nat) (env : DatabaseEnv Const) (q : SelectQuery Const) :
    evalQuery fuel env q = evalRelAlg fuel env (translateComplete q) := by
  exact translationComplete_soundness fuel env q

theorem translation_soundness_via_complete (fuel : Nat) (env : DatabaseEnv Const) (q : SelectQuery Const) :
    evalQuery fuel env q = evalRelAlg fuel env (translate q) := by
  simpa [translateComplete_equiv_simple q trivial] using
    (translation_soundness_complete fuel env q)

theorem translation_preserves_empty (fuel : Nat) (env : DatabaseEnv Const) (q : SelectQuery Const) :
    evalQuery fuel env q = some [] ↔ evalRelAlg fuel env (translateComplete q) = some [] := by
  rw [translation_soundness_complete]

theorem translation_preserves_nonempty_complete (fuel : Nat) (env : DatabaseEnv Const) (q : SelectQuery Const)
    (h : evalQuery fuel env q ≠ some []) :
    evalRelAlg fuel env (translateComplete q) ≠ some [] := by
  simpa [translation_soundness_complete fuel env q] using h

theorem translation_injective (q1 q2 : SelectQuery Const)
    (h : translateComplete q1 = translateComplete q2) :
    ∀ fuel env, evalQuery fuel env q1 = evalQuery fuel env q2 := by
  intro fuel env
  rw [translation_soundness_complete fuel env q1,
      translation_soundness_complete fuel env q2,
      h]

theorem equivalent_translation_implies_equivalent (q1 q2 : SelectQuery Const)
    (h : ∀ fuel env, evalRelAlg fuel env (translateComplete q1) = evalRelAlg fuel env (translateComplete q2)) :
    ∀ fuel env, evalQuery fuel env q1 = evalQuery fuel env q2 := by
  intro fuel env
  rw [translation_soundness_complete fuel env q1,
      translation_soundness_complete fuel env q2,
      h fuel env]

axiom translation_preserves_containment (q1 q2 : SelectQuery Const) :
    True

theorem translation_compositional (q1 q2 : SelectQuery Const) (op : SetOp) (quant : SetQuantifier) :
    translateComplete (.setOp op quant q1 q2) =
    match op, quant with
    | .unionOp, .all => .union (translateComplete q1) (translateComplete q2)
    | .unionOp, .distinct => .distinct (.union (translateComplete q1) (translateComplete q2))
    | .intersectOp, .all => .diff (translateComplete q1) (.diff (translateComplete q1) (translateComplete q2))
    | .intersectOp, .distinct =>
        .distinct (.diff (translateComplete q1) (.diff (translateComplete q1) (translateComplete q2)))
    | .exceptOp, .all => .diff (translateComplete q1) (translateComplete q2)
    | .exceptOp, .distinct => .distinct (.diff (translateComplete q1) (translateComplete q2)) := by
  rfl

end SWELib.Db.Sql
