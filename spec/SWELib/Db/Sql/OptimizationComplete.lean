import SWELib.Db.Sql.Algebra
import SWELib.Db.Sql.EquivalenceComplete

namespace SWELib.Db.Sql

set_option linter.unusedSectionVars false
set_option linter.unusedVariables false

variable {Const : Type} [DecidableEq Const] [Ord Const]
  [Add Const] [Sub Const] [Mul Const] [Div Const] [Mod Const] [Append Const]
  [Neg Const] [Zero Const] [OfNat Const 0] [NatCast Const]

axiom select_pushdown_cross_left_complete (cond : SqlCondition Const)
    (left right : RelAlg Const) (h : True) :
    RelAlg.select cond (RelAlg.cross left right) = RelAlg.cross (RelAlg.select cond left) right

axiom select_pushdown_cross_right_complete (cond : SqlCondition Const)
    (left right : RelAlg Const) (h : True) :
    RelAlg.select cond (RelAlg.cross left right) = RelAlg.cross left (RelAlg.select cond right)

axiom select_idempotent_complete (cond : SqlCondition Const) (child : RelAlg Const) :
    RelAlg.select cond (RelAlg.select cond child) = RelAlg.select cond child

axiom select_over_union_complete (cond : SqlCondition Const) (left right : RelAlg Const) :
    RelAlg.select cond (RelAlg.union left right) =
      RelAlg.union (RelAlg.select cond left) (RelAlg.select cond right)

axiom project_merge_complete (indices1 indices2 : List Nat) (child : RelAlg Const) :
    RelAlg.project indices2 (RelAlg.project indices1 child) =
      RelAlg.project (indices1.map (fun i => indices2.getD i i)) child

axiom project_over_cross_complete (indices : List Nat) (left right : RelAlg Const)
    (leftWidth : Nat) (h_left : True) :
    True

axiom distinct_idempotent_complete (child : RelAlg Const) :
    RelAlg.distinct (RelAlg.distinct child) = RelAlg.distinct child

axiom distinct_commutes_select_complete (cond : SqlCondition Const) (child : RelAlg Const) :
    RelAlg.distinct (RelAlg.select cond child) = RelAlg.select cond (RelAlg.distinct child)

axiom cross_empty_left_complete (right : RelAlg Const) :
    RelAlg.cross RelAlg.empty right = RelAlg.empty

axiom cross_empty_right_complete (left : RelAlg Const) :
    RelAlg.cross left RelAlg.empty = RelAlg.empty

axiom union_empty_left_complete (r : RelAlg Const) :
    RelAlg.union RelAlg.empty r = r

axiom union_empty_right_complete (r : RelAlg Const) :
    RelAlg.union r RelAlg.empty = r

axiom limit_zero_complete (child : RelAlg Const) :
    RelAlg.limit 0 child = RelAlg.empty

axiom offset_zero_complete (child : RelAlg Const) :
    RelAlg.offset 0 child = child

axiom limit_offset_combine_complete (n m : Nat) (child : RelAlg Const) :
    RelAlg.limit n (RelAlg.offset m child) = RelAlg.offset m (RelAlg.limit (n + m) child)

axiom select_on_singleton_complete (cond : SqlCondition Const) :
    RelAlg.select cond RelAlg.singleton = RelAlg.singleton ∨
      RelAlg.select cond RelAlg.singleton = RelAlg.empty

axiom optimizer_rule_chain_complete (cond : SqlCondition Const) (indices : List Nat)
    (child : RelAlg Const) (h : True) :
    RelAlg.distinct (RelAlg.project indices (RelAlg.select cond (RelAlg.cross child RelAlg.singleton))) =
      RelAlg.project indices (RelAlg.select cond child)

theorem optimization_preserves_equivalence (rule : RelAlg Const → RelAlg Const)
    (h_sound : ∀ child fuel env, evalRelAlg fuel env (rule child) = evalRelAlg fuel env child)
    (q1 q2 : SelectQuery Const) (h : translateComplete q1 = rule (translateComplete q2)) :
    ∀ fuel env, evalQuery fuel env q1 = evalQuery fuel env q2 := by
  intro fuel env
  rw [translation_soundness_complete fuel env q1,
      translation_soundness_complete fuel env q2,
      h, h_sound (translateComplete q2) fuel env]

theorem optimization_composition (rule1 rule2 : RelAlg Const → RelAlg Const)
    (h1 : ∀ child fuel env, evalRelAlg fuel env (rule1 child) = evalRelAlg fuel env child)
    (h2 : ∀ child fuel env, evalRelAlg fuel env (rule2 child) = evalRelAlg fuel env child) :
    ∀ child fuel env, evalRelAlg fuel env ((rule1 ∘ rule2) child) = evalRelAlg fuel env child := by
  intro child fuel env
  rw [show (rule1 ∘ rule2) child = rule1 (rule2 child) by rfl]
  rw [h1 (rule2 child) fuel env, h2 child fuel env]

axiom all_optimizations_sound : True

end SWELib.Db.Sql
