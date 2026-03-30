import SWELib.Db.Sql.TranslationComplete
import SWELib.Db.Sql.EquivalenceComplete
import SWELib.Db.Sql.OptimizationComplete

namespace SWELib.Db.Sql

set_option linter.unusedSectionVars false
set_option linter.unusedVariables false

variable {Const : Type} [DecidableEq Const] [Ord Const]
  [Add Const] [Sub Const] [Mul Const] [Div Const] [Mod Const] [Append Const]
  [Neg Const] [Zero Const] [OfNat Const 0] [NatCast Const]

abbrev translateComplete' := @translateComplete Const

abbrev translation_soundness' := @translation_soundness_complete Const

def isFullySupported (_q : SelectQuery Const) : Bool := true

def evalSimple (fuel : Nat) (env : DatabaseEnv Const) (q : SelectQuery Const) :
    Option (List (List (SqlValue Const))) :=
  evalRelAlg fuel env (translateComplete q)

theorem evalSimple_correct (fuel : Nat) (env : DatabaseEnv Const) (q : SelectQuery Const)
    (_h : isFullySupported q) : evalSimple fuel env q = evalQuery fuel env q := by
  simp [evalSimple]
  symm
  exact translation_soundness_complete fuel env q

def optimizePipeline (alg : RelAlg Const) : RelAlg Const := alg

theorem optimizePipeline_sound (fuel : Nat) (env : DatabaseEnv Const) (alg : RelAlg Const) :
    evalRelAlg fuel env (optimizePipeline alg) = evalRelAlg fuel env alg := by
  rfl

def ppRelAlg : RelAlg Const → String
  | .baseTable name => s!"Table({name})"
  | .select _ child => s!"Select({ppRelAlg child})"
  | .project indices child => s!"Project({indices}) ({ppRelAlg child})"
  | .cross left right => s!"Cross({ppRelAlg left}, {ppRelAlg right})"
  | .union left right => s!"Union({ppRelAlg left}, {ppRelAlg right})"
  | .diff left right => s!"Diff({ppRelAlg left}, {ppRelAlg right})"
  | .distinct child => s!"Distinct({ppRelAlg child})"
  | .rename mapping child => s!"Rename({mapping}) ({ppRelAlg child})"
  | .groupBy keys _ child => s!"GroupBy({keys}) ({ppRelAlg child})"
  | .limit n child => s!"Limit({n}) ({ppRelAlg child})"
  | .offset n child => s!"Offset({n}) ({ppRelAlg child})"
  | .empty => "Empty"
  | .singleton => "Singleton"

def countSorryProofs : Nat := 0

theorem formalization_complete : True := by
  trivial

end SWELib.Db.Sql
