/-
Copyright (c) 2024 SWELib Contributors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: SWELib Contributors
-/

import SWELib.Cloud.K8s.Primitives
import SWELib.Cloud.K8s.Selection.SelectorOperator
import Std.Data.HashMap

namespace SWELib.Cloud.K8s.Selection

open SWELib.Cloud.K8s.Primitives

/-- A single label selector requirement -/
structure MatchExpression where
  key : LabelKey
  operator : SelectorOperator
  values : List LabelValue := []
  deriving DecidableEq

/-- Label selector for matching resources -/
structure LabelSelector where
  matchLabels : Std.HashMap LabelKey LabelValue := ∅
  matchExpressions : List MatchExpression := []

/-- Check if a single expression matches a set of labels -/
def matchExpression (expr : MatchExpression) (labels : Std.HashMap LabelKey LabelValue) : Bool :=
  match expr.operator with
  | .In =>
    match labels.get? expr.key with
    | none => false
    | some v => expr.values.contains v
  | .NotIn =>
    match labels.get? expr.key with
    | none => true
    | some v => !expr.values.contains v
  | .Exists =>
    labels.contains expr.key
  | .DoesNotExist =>
    !labels.contains expr.key

/-- Check if a selector matches a set of labels -/
def LabelSelector.matches (selector : LabelSelector) (labels : Std.HashMap LabelKey LabelValue) : Bool :=
  -- All matchLabels must match exactly
  selector.matchLabels.toList.all (fun (k, v) =>
    labels.get? k = some v) &&
  -- All matchExpressions must be satisfied
  selector.matchExpressions.all (fun expr =>
    matchExpression expr labels)

/-- An empty selector that matches everything -/
def LabelSelector.empty : LabelSelector :=
  ⟨∅, []⟩

-- STRUCTURAL
theorem empty_selector_matches_all (labels : Std.HashMap LabelKey LabelValue) :
    LabelSelector.empty.matches labels = true := by
  simp [LabelSelector.empty, LabelSelector.matches]

-- ALGEBRAIC
axiom selector_conjunction (s1 s2 : LabelSelector) (labels : Std.HashMap LabelKey LabelValue) :
    (s1.matches labels && s2.matches labels) →
    ({ matchLabels := s1.matchLabels.union s2.matchLabels
     , matchExpressions := s1.matchExpressions ++ s2.matchExpressions
     } : LabelSelector).matches labels

end SWELib.Cloud.K8s.Selection
