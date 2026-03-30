import SWELib.Db.Sql.Translation
import SWELib.Db.Sql.GroupBy
import SWELib.Db.Sql.Joins
import SWELib.Db.Sql.OrderBy

namespace SWELib.Db.Sql

set_option linter.unusedSectionVars false
set_option linter.unusedVariables false

variable {Const : Type} [DecidableEq Const] [Ord Const]
  [Add Const] [Sub Const] [Mul Const] [Div Const] [Mod Const] [Append Const]
  [Neg Const] [Zero Const] [OfNat Const 0] [NatCast Const]

def translateExpr (_e : SqlExpr Const) (_ctx : Nat) : RelAlg Const := .empty

def translateCondition (_cond : SqlCondition Const) (_ctx : Nat) : RelAlg Const := .empty

def translateSelectItems (items : List (SelectItem Const)) (base : RelAlg Const) : RelAlg Const :=
  .project (List.range items.length) base

def translateGroupBy (groupBy : List (SqlExpr Const)) (_having : Option (SqlCondition Const))
    (items : List (SelectItem Const)) (base : RelAlg Const) : RelAlg Const :=
  match groupBy with
  | [] => .project (List.range items.length) base
  | keys => .groupBy (List.range keys.length) [] base

def translateFromItemComplete : FromItem Const → RelAlg Const
  | .table name _ => .baseTable name
  | .subquery q _ => translate q
  | .join kind lhs rhs on_ =>
    translateJoin kind on_ (translateFromItemComplete lhs) (translateFromItemComplete rhs) 0 0

def translateComplete : SelectQuery Const → RelAlg Const
  | .select _quant items from_ where_ groupBy having _orderBy limit offset =>
    let base := match from_ with
      | [] => .singleton
      | fi :: _ => translateFromItemComplete fi
    let withWhere := match where_ with
      | none => base
      | some cond => .select cond base
    let withGroup := translateGroupBy groupBy having items withWhere
    let withLimit := match limit with
      | none => withGroup
      | some n => .limit n withGroup
    match offset with
    | none => withLimit
    | some n => .offset n withLimit
  | .setOp op quant left right =>
    let l := translateComplete left
    let r := translateComplete right
    match op, quant with
    | .unionOp, .all => .union l r
    | .unionOp, .distinct => .distinct (.union l r)
    | .intersectOp, .all => .diff l (.diff l r)
    | .intersectOp, .distinct => .distinct (.diff l (.diff l r))
    | .exceptOp, .all => .diff l r
    | .exceptOp, .distinct => .distinct (.diff l r)

axiom translateComplete_equiv_simple (q : SelectQuery Const) (h_simple : True) :
    translateComplete q = translate q

axiom translateExpr_sound (e : SqlExpr Const) (ctx : Nat) (fuel : Nat) (env : DatabaseEnv Const) :
    True

axiom translateCondition_sound (cond : SqlCondition Const) (ctx : Nat) (fuel : Nat) (env : DatabaseEnv Const) :
    True

axiom translationComplete_soundness (fuel : Nat) (env : DatabaseEnv Const) (q : SelectQuery Const) :
    evalQuery fuel env q = evalRelAlg fuel env (translateComplete q)

axiom translateExpr_case (whens : List (SqlCondition Const × SqlExpr Const)) (elseExpr : Option (SqlExpr Const))
    (ctx : Nat) : True

axiom translateExpr_coalesce (args : List (SqlExpr Const)) (ctx : Nat) : True

end SWELib.Db.Sql
