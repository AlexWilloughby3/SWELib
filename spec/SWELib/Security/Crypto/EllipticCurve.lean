import SWELib.Security.Crypto.ModularArith

/-!
# Elliptic Curve Primitives

Specification of short Weierstrass elliptic curves over prime fields,
with group operations and scalar multiplication.

`CurvePoint` is `inductive | infinity | affine (x y : Nat)` (Decision D-012).
Group law axioms are conditioned on `curveParamsValid` (Decision D-013).

References:
- SEC 1 v2 Sections 2.2-2.3
- NIST FIPS 186-5 Section 6
-/

namespace SWELib.Security.Crypto.EllipticCurve

-- ---------------------------------------------------------------------------
-- Types
-- ---------------------------------------------------------------------------

/-- Parameters for a short Weierstrass elliptic curve `y^2 = x^3 + ax + b` over `F_p`.
    (SEC 1 v2 Section 2.2, FIPS 186-5 Section 6.1.1)
    - `p`: prime field modulus
    - `a`, `b`: curve coefficients
    - `n`: group order
    - `h`: cofactor
    - `Gx`, `Gy`: base point coordinates -/
structure EllipticCurveParams where
  p : Nat
  a : Nat
  b : Nat
  n : Nat
  h : Nat
  Gx : Nat
  Gy : Nat
  deriving DecidableEq, Repr

/-- A point on an elliptic curve: either the point at infinity or an affine point (Decision D-012).
    (SEC 1 v2 Section 2.2.1) -/
inductive CurvePoint where
  | infinity : CurvePoint
  | affine (x y : Nat) : CurvePoint
  deriving DecidableEq, Repr

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

/-- Extract the x-coordinate of a curve point, if it is affine.
    Used in ECDSA sign/verify (FIPS 186-5 Section 6.4). -/
def CurvePoint.xCoord : CurvePoint → Option Nat
  | .infinity => none
  | .affine x _ => some x

/-- Extract the y-coordinate of a curve point, if it is affine. -/
def CurvePoint.yCoord : CurvePoint → Option Nat
  | .infinity => none
  | .affine _ y => some y

-- ---------------------------------------------------------------------------
-- Predicates
-- ---------------------------------------------------------------------------

/-- The discriminant `4a^3 + 27b^2` is non-zero mod `p`.
    Ensures the curve is non-singular (SEC 1 v2 Section 2.2.1). -/
def discriminantNonzero (params : EllipticCurveParams) : Prop :=
  (4 * params.a ^ 3 + 27 * params.b ^ 2) % params.p ≠ 0

/-- A point lies on the curve `y^2 = x^3 + ax + b (mod p)`.
    (SEC 1 v2 Section 2.2.1) -/
def pointOnCurve (params : EllipticCurveParams) : CurvePoint → Prop
  | .infinity => True
  | .affine x y =>
    (y * y) % params.p = (x * x * x + params.a * x + params.b) % params.p

/-- Full validity of curve parameters: prime field, non-singular, base point on curve,
    generator order correct. (FIPS 186-5 Section 6.1.1) -/
def curveParamsValid (params : EllipticCurveParams) : Prop :=
  IsPrime params.p ∧
  params.p > 3 ∧
  discriminantNonzero params ∧
  IsPrime params.n ∧
  params.n > 0 ∧
  params.h ≥ 1 ∧
  pointOnCurve params (.affine params.Gx params.Gy)

-- ---------------------------------------------------------------------------
-- Operations
-- ---------------------------------------------------------------------------

/-- Elliptic curve point negation: negate the y-coordinate mod `p`.
    (SEC 1 v2 Section 2.2.1) -/
def curveNeg (params : EllipticCurveParams) : CurvePoint → CurvePoint
  | .infinity => .infinity
  | .affine x y => if y = 0 then .affine x 0 else .affine x (params.p - y)

/-- Elliptic curve point addition using the chord-and-tangent rule.
    Uses `modInverse` for the slope computation; when the inverse does not exist
    (which cannot happen for valid curve points), falls back to infinity.
    (SEC 1 v2 Section 2.2.1, FIPS 186-5 Appendix B.3) -/
noncomputable def curveAdd (params : EllipticCurveParams) (P Q : CurvePoint) : CurvePoint :=
  match P, Q with
  | .infinity, q => q
  | p, .infinity => p
  | .affine x1 y1, .affine x2 y2 =>
    if x1 = x2 then
      if y1 = y2 ∧ y1 ≠ 0 then
        -- Point doubling: lambda = (3*x1^2 + a) / (2*y1)
        let num := (3 * x1 * x1 + params.a) % params.p
        let den := (2 * y1) % params.p
        match modInverse den params.p with
        | none => .infinity
        | some inv =>
          let lam := (num * inv) % params.p
          let x3 := (lam * lam + params.p * 2 - x1 - x2) % params.p
          let y3 := (lam * (x1 + params.p - x3) + params.p - y1) % params.p
          .affine x3 y3
      else
        -- x1 = x2 but y1 != y2 (or y1 = 0): points are inverses
        .infinity
    else
      -- General addition: lambda = (y2 - y1) / (x2 - x1)
      let num := (y2 + params.p - y1) % params.p
      let den := (x2 + params.p - x1) % params.p
      match modInverse den params.p with
      | none => .infinity
      | some inv =>
        let lam := (num * inv) % params.p
        let x3 := (lam * lam + params.p * 2 - x1 - x2) % params.p
        let y3 := (lam * (x1 + params.p - x3) + params.p - y1) % params.p
        .affine x3 y3

/-- Scalar multiplication by double-and-add, processing bits from LSB.
    (SEC 1 v2 Section 2.2.1, FIPS 186-5 Appendix B.3) -/
noncomputable def scalarMul (params : EllipticCurveParams) (k : Nat) (P : CurvePoint) : CurvePoint :=
  if k = 0 then .infinity
  else
    let acc := if k % 2 = 1 then P else .infinity
    curveAdd params acc (scalarMul params (k / 2) (curveAdd params P P))
  termination_by k

-- ---------------------------------------------------------------------------
-- Group law axioms (Decision D-013)
-- Conditioned on curveParamsValid; points assumed to be on the curve.
-- ---------------------------------------------------------------------------

/-- Point addition is commutative (SEC 1 v2 Section 2.2.1). -/
axiom curveAdd_comm (params : EllipticCurveParams) (P Q : CurvePoint)
    (hv : curveParamsValid params)
    (hp : pointOnCurve params P) (hq : pointOnCurve params Q) :
    curveAdd params P Q = curveAdd params Q P

/-- Point addition is associative (SEC 1 v2 Section 2.2.1). -/
axiom curveAdd_assoc (params : EllipticCurveParams) (P Q R : CurvePoint)
    (hv : curveParamsValid params)
    (hp : pointOnCurve params P) (hq : pointOnCurve params Q) (hr : pointOnCurve params R) :
    curveAdd params (curveAdd params P Q) R = curveAdd params P (curveAdd params Q R)

/-- Infinity is a left identity for point addition (SEC 1 v2 Section 2.2.1). -/
axiom curveAdd_identity_left (params : EllipticCurveParams) (P : CurvePoint)
    (hv : curveParamsValid params) (hp : pointOnCurve params P) :
    curveAdd params .infinity P = P

/-- Infinity is a right identity for point addition (SEC 1 v2 Section 2.2.1). -/
axiom curveAdd_identity_right (params : EllipticCurveParams) (P : CurvePoint)
    (hv : curveParamsValid params) (hp : pointOnCurve params P) :
    curveAdd params P .infinity = P

/-- Every point has an additive inverse via `curveNeg` (SEC 1 v2 Section 2.2.1). -/
axiom curveAdd_inverse (params : EllipticCurveParams) (P : CurvePoint)
    (hv : curveParamsValid params) (hp : pointOnCurve params P) :
    curveAdd params P (curveNeg params P) = .infinity

-- ---------------------------------------------------------------------------
-- Proved / structural theorems
-- ---------------------------------------------------------------------------

/-- Scalar multiplication by zero yields infinity. -/
@[simp]
theorem scalarMul_zero (params : EllipticCurveParams) (P : CurvePoint) :
    scalarMul params 0 P = .infinity := by
  simp [scalarMul]

/-- Scalar multiplication by one yields the point itself (uses identity axiom). -/
theorem scalarMul_one (params : EllipticCurveParams) (P : CurvePoint)
    (hv : curveParamsValid params) (hp : pointOnCurve params P) :
    scalarMul params 1 P = P := by
  sorry

/-- Double negation returns the original point (when coordinates are reduced mod p). -/
theorem curveNeg_neg (params : EllipticCurveParams) (x y : Nat)
    (hy : y < params.p) (hy0 : y ≠ 0) (hp : params.p > 0) :
    curveNeg params (curveNeg params (.affine x y)) = .affine x y := by
  sorry

/-- Scalar multiplication distributes over addition:
    `(k1 + k2) * P = k1 * P + k2 * P`.
    Proof sketch: induction on `k1`, using group axioms. -/
theorem scalarMul_add (params : EllipticCurveParams) (k1 k2 : Nat) (P : CurvePoint)
    (hv : curveParamsValid params) (hp : pointOnCurve params P) :
    scalarMul params (k1 + k2) P = curveAdd params (scalarMul params k1 P) (scalarMul params k2 P) := by
  sorry

/-- Scalar multiplication composes: `(k1 * k2) * P = k1 * (k2 * P)`.
    Proof sketch: induction on `k1`, using `scalarMul_add`. -/
theorem scalarMul_comp (params : EllipticCurveParams) (k1 k2 : Nat) (P : CurvePoint)
    (hv : curveParamsValid params) (hp : pointOnCurve params P) :
    scalarMul params (k1 * k2) P = scalarMul params k1 (scalarMul params k2 P) := by
  sorry

end SWELib.Security.Crypto.EllipticCurve
