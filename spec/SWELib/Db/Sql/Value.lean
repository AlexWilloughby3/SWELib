/-!
# SQL Values and Three-Valued Logic

Defines `SqlValue` as `Option Const` (where `none` represents SQL NULL)
and `Tribool` implementing Kleene's three-valued logic for SQL's
ternary truth semantics (SQL:2023 Section 8.12).
-/

namespace SWELib.Db.Sql

/-- An SQL value is either NULL (`none`) or a concrete constant (`some c`). -/
abbrev SqlValue (Const : Type) := Option Const

/-- Kleene three-valued logic truth value (SQL:2023 Section 8.12).
    SQL conditions evaluate to `ttrue`, `tfalse`, or `tunknown` (when NULLs are involved). -/
inductive Tribool where
  | ttrue
  | tfalse
  | tunknown
  deriving DecidableEq, Repr

namespace Tribool

/-- Kleene conjunction: `tfalse` dominates `tunknown` (SQL:2023 Section 6.42). -/
def and : Tribool -> Tribool -> Tribool
  | ttrue, t => t
  | tfalse, _ => tfalse
  | tunknown, tfalse => tfalse
  | tunknown, _ => tunknown

/-- Kleene disjunction: `ttrue` dominates `tunknown` (SQL:2023 Section 6.42). -/
def or : Tribool -> Tribool -> Tribool
  | tfalse, t => t
  | ttrue, _ => ttrue
  | tunknown, ttrue => ttrue
  | tunknown, _ => tunknown

/-- Kleene negation (SQL:2023 Section 6.42). -/
def not : Tribool -> Tribool
  | ttrue => tfalse
  | tfalse => ttrue
  | tunknown => tunknown

/-- Check whether a tribool is definitely true. Used for WHERE clause filtering. -/
def isTrue : Tribool -> Bool
  | ttrue => true
  | _ => false

/-- Check whether a tribool is definitely false. -/
def isFalse : Tribool -> Bool
  | tfalse => true
  | _ => false

end Tribool

/-- NULL-propagating equality comparison (SQL:2023 Section 8.2).
    Returns `tunknown` if either argument is NULL. -/
def veq [DecidableEq Const] : SqlValue Const -> SqlValue Const -> Tribool
  | none, _ => .tunknown
  | _, none => .tunknown
  | some a, some b => if a == b then .ttrue else .tfalse

/-- NULL-propagating less-than comparison (SQL:2023 Section 8.2).
    Returns `tunknown` if either argument is NULL. -/
def vlt [Ord Const] : SqlValue Const -> SqlValue Const -> Tribool
  | none, _ => .tunknown
  | _, none => .tunknown
  | some a, some b => match compare a b with
    | .lt => .ttrue
    | _ => .tfalse

/-- Kleene AND is commutative. -/
theorem Tribool.and_comm (a b : Tribool) : a.and b = b.and a := by
  cases a <;> cases b <;> rfl

/-- Kleene OR is commutative. -/
theorem Tribool.or_comm (a b : Tribool) : a.or b = b.or a := by
  cases a <;> cases b <;> rfl

/-- Double negation is identity in Kleene logic. -/
theorem Tribool.not_not (t : Tribool) : t.not.not = t := by
  cases t <;> rfl

/-- Comparing NULL on the left always yields `tunknown`. -/
theorem veq_null_left [DecidableEq Const] (v : SqlValue Const) :
    veq none v = .tunknown := by
  rfl

/-- Comparing NULL on the right always yields `tunknown`. -/
theorem veq_null_right [DecidableEq Const] (v : SqlValue Const) :
    veq v none = .tunknown := by
  cases v <;> rfl

end SWELib.Db.Sql
