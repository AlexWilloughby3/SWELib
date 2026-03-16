import SWELib.Db.Sql.Value
import SWELib.Db.Sql.Syntax

set_option linter.unusedSectionVars false

/-!
# Extended SQL Value Operations

Extends `SqlValue` with arithmetic operations and typeclass constraints
required for SQL numeric operations (SQL:2023 Section 6.26-6.30).

This module adds:
1. Typeclass constraints: `Num Const`, `Div Const`, `Mod Const`, `Append Const`
2. Arithmetic operations on `SqlValue` with NULL propagation
3. String concatenation with NULL propagation
4. Proofs about operation properties
-/

namespace SWELib.Db.Sql

variable {Const : Type} [DecidableEq Const] [Ord Const] [Add Const] [Sub Const] [Mul Const] [Div Const] [Mod Const] [Append Const] [Neg Const] [Zero Const] [OfNat Const 0]

/-- NULL-propagating addition (SQL:2023 Section 6.26).
    Returns `none` (NULL) if either argument is NULL. -/
def vadd : SqlValue Const → SqlValue Const → SqlValue Const
  | none, _ => none
  | _, none => none
  | some a, some b => some (a + b)

/-- NULL-propagating subtraction (SQL:2023 Section 6.26). -/
def vsub : SqlValue Const → SqlValue Const → SqlValue Const
  | none, _ => none
  | _, none => none
  | some a, some b => some (a - b)

/-- NULL-propagating multiplication (SQL:2023 Section 6.26). -/
def vmul : SqlValue Const → SqlValue Const → SqlValue Const
  | none, _ => none
  | _, none => none
  | some a, some b => some (a * b)

/-- NULL-propagating division (SQL:2023 Section 6.26).
    Note: SQL division by zero returns NULL, not an error. -/
def vdiv : SqlValue Const → SqlValue Const → SqlValue Const
  | none, _ => none
  | _, none => none
  | some a, some b =>
    -- SQL division by zero returns NULL (SQL:2023 Section 6.26)
    if b = 0 then none else some (a / b)

/-- NULL-propagating modulus (SQL:2023 Section 6.26). -/
def vmod : SqlValue Const → SqlValue Const → SqlValue Const
  | none, _ => none
  | _, none => none
  | some a, some b =>
    -- SQL modulus by zero returns NULL
    if b = 0 then none else some (a % b)

/-- NULL-propagating string concatenation (SQL:2023 Section 6.30).
    Returns `none` if either argument is NULL. -/
def vconcat : SqlValue Const → SqlValue Const → SqlValue Const
  | none, _ => none
  | _, none => none
  | some a, some b => some (a ++ b)

/-- NULL-propagating unary negation (SQL:2023 Section 6.26). -/
def vneg : SqlValue Const → SqlValue Const
  | none => none
  | some a => some (-a)


/-- Apply a binary operator to SQL values with NULL propagation. -/
def applyBinOp : BinOp → SqlValue Const → SqlValue Const → SqlValue Const
  | .add => vadd
  | .sub => vsub
  | .mul => vmul
  | .div => vdiv
  | .modOp => vmod
  | .concat => vconcat

/-- Apply a unary operator to an SQL value with NULL propagation. -/
def applyUnOp : UnOp → SqlValue Const → SqlValue Const
  | .neg => vneg
  | .abs => vneg  -- placeholder: abs not implemented

/-- Addition with NULL on left yields NULL. -/
theorem vadd_null_left (v : SqlValue Const) : vadd none v = none := by
  rfl

/-- Addition with NULL on right yields NULL. -/
theorem vadd_null_right (v : SqlValue Const) : vadd v none = none := by
  cases v <;> rfl


/-- Multiplication with NULL on left yields NULL. -/
theorem vmul_null_left (v : SqlValue Const) : vmul none v = none := by
  rfl

/-- Multiplication with NULL on right yields NULL. -/
theorem vmul_null_right (v : SqlValue Const) : vmul v none = none := by
  cases v <;> rfl



/-- Concatenation with NULL on left yields NULL. -/
theorem vconcat_null_left (v : SqlValue Const) : vconcat none v = none := by
  rfl

/-- Concatenation with NULL on right yields NULL. -/
theorem vconcat_null_right (v : SqlValue Const) : vconcat v none = none := by
  cases v <;> rfl

/-- Negation of NULL yields NULL. -/
theorem vneg_null : vneg (none : SqlValue Const) = none := by
  rfl



end SWELib.Db.Sql