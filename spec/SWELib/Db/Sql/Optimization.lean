import SWELib.Db.Sql.Algebra
import SWELib.Db.Sql.Equivalence

namespace SWELib.Db.Sql

set_option linter.unusedSectionVars false
set_option linter.unusedVariables false

variable {Const : Type} [DecidableEq Const] [Ord Const]

axiom select_pushdown_cross_left (cond : SqlCondition Const)
    (left right : RelAlg Const) (h : True) :
    RelAlg.select cond (RelAlg.cross left right) = RelAlg.cross (RelAlg.select cond left) right

axiom select_pushdown_cross_right (cond : SqlCondition Const)
    (left right : RelAlg Const) (h : True) :
    RelAlg.select cond (RelAlg.cross left right) = RelAlg.cross left (RelAlg.select cond right)

axiom select_idempotent (cond : SqlCondition Const) (child : RelAlg Const) :
    RelAlg.select cond (RelAlg.select cond child) = RelAlg.select cond child

axiom select_over_union (cond : SqlCondition Const) (left right : RelAlg Const) :
    RelAlg.select cond (RelAlg.union left right) =
      RelAlg.union (RelAlg.select cond left) (RelAlg.select cond right)

axiom project_merge (indices1 indices2 : List Nat) (child : RelAlg Const) :
    RelAlg.project indices2 (RelAlg.project indices1 child) =
      RelAlg.project (indices1.map (fun i => indices2.getD i i)) child

axiom project_over_cross (indices : List Nat) (left right : RelAlg Const) :
    True

axiom distinct_idempotent (child : RelAlg Const) :
    RelAlg.distinct (RelAlg.distinct child) = RelAlg.distinct child

axiom distinct_commutes_select (cond : SqlCondition Const) (child : RelAlg Const) :
    RelAlg.distinct (RelAlg.select cond child) = RelAlg.select cond (RelAlg.distinct child)

axiom cross_empty_left (right : RelAlg Const) :
    RelAlg.cross RelAlg.empty right = RelAlg.empty

axiom cross_empty_right (left : RelAlg Const) :
    RelAlg.cross left RelAlg.empty = RelAlg.empty

axiom union_empty_left (r : RelAlg Const) :
    RelAlg.union RelAlg.empty r = r

axiom union_empty_right (r : RelAlg Const) :
    RelAlg.union r RelAlg.empty = r

axiom limit_zero (child : RelAlg Const) :
    RelAlg.limit 0 child = RelAlg.empty

axiom offset_zero (child : RelAlg Const) :
    RelAlg.offset 0 child = child

axiom limit_offset_combine (n m : Nat) (child : RelAlg Const) :
    RelAlg.limit n (RelAlg.offset m child) = RelAlg.offset m (RelAlg.limit (n + m) child)

axiom select_on_singleton (cond : SqlCondition Const) :
    RelAlg.select cond RelAlg.singleton = RelAlg.singleton ∨
      RelAlg.select cond RelAlg.singleton = RelAlg.empty

axiom optimizer_rule_chain (cond : SqlCondition Const) (indices : List Nat)
    (child : RelAlg Const) :
    RelAlg.distinct (RelAlg.project indices (RelAlg.select cond (RelAlg.cross child RelAlg.singleton))) =
      RelAlg.project indices (RelAlg.select cond child)

end SWELib.Db.Sql
