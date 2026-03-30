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
  simp [scalarMul, curveAdd_identity_right, hv, hp]

/-- Double negation returns the original point (when coordinates are reduced mod p). -/
theorem curveNeg_neg (params : EllipticCurveParams) (x y : Nat)
    (hy : y < params.p) (hy0 : y ≠ 0) (hp : params.p > 0) :
    curveNeg params (curveNeg params (.affine x y)) = .affine x y := by
  have hp' : params.p > 0 := hp
  have hpy : params.p - y ≠ 0 := by omega
  simp [curveNeg, hy0, hpy]
  omega

-- ---------------------------------------------------------------------------
-- Closure axiom and linear scalar multiplication
-- ---------------------------------------------------------------------------

/-- Point addition preserves the curve equation (SEC 1 v2 Section 2.2.1). -/
axiom curveAdd_onCurve (params : EllipticCurveParams) (P Q : CurvePoint)
    (hv : curveParamsValid params)
    (hp : pointOnCurve params P) (hq : pointOnCurve params Q) :
    pointOnCurve params (curveAdd params P Q)

/-- Linear (unary) scalar multiplication: `scalarMulLinear params k P = P + P + ... + P` (k times).
    Easier to reason about inductively than the binary `scalarMul`. -/
noncomputable def scalarMulLinear (params : EllipticCurveParams) : Nat → CurvePoint → CurvePoint
  | 0, _ => .infinity
  | n + 1, P => curveAdd params P (scalarMulLinear params n P)

/-- Infinity satisfies `pointOnCurve` (trivially by definition). -/
theorem pointOnCurve_infinity (params : EllipticCurveParams) :
    pointOnCurve params .infinity = True := by
  simp [pointOnCurve]

/-- `scalarMulLinear` preserves the curve equation. -/
theorem scalarMulLinear_onCurve (params : EllipticCurveParams) (k : Nat) (P : CurvePoint)
    (hv : curveParamsValid params) (hp : pointOnCurve params P) :
    pointOnCurve params (scalarMulLinear params k P) := by
  induction k with
  | zero => simp [scalarMulLinear, pointOnCurve]
  | succ n ih => exact curveAdd_onCurve params P _ hv hp ih

/-- `scalarMulLinear` distributes over scalar addition:
    `scalarMulLinear (k1 + k2) P = curveAdd (scalarMulLinear k1 P) (scalarMulLinear k2 P)`. -/
theorem scalarMulLinear_add (params : EllipticCurveParams) (k1 k2 : Nat) (P : CurvePoint)
    (hv : curveParamsValid params) (hp : pointOnCurve params P) :
    scalarMulLinear params (k1 + k2) P = curveAdd params (scalarMulLinear params k1 P) (scalarMulLinear params k2 P) := by
  induction k1 with
  | zero =>
    simp [scalarMulLinear]
    exact (curveAdd_identity_left params _ hv (scalarMulLinear_onCurve params k2 P hv hp)).symm
  | succ n ih =>
    -- (n + 1 + k2) = succ (n + k2), so scalarMulLinear unfolds
    have heq : n + 1 + k2 = (n + k2) + 1 := by omega
    rw [heq]
    simp only [scalarMulLinear]
    rw [ih]
    rw [curveAdd_assoc params P _ _ hv hp
      (scalarMulLinear_onCurve params n P hv hp)
      (scalarMulLinear_onCurve params k2 P hv hp)]

/-- Doubling the argument halves the scalar:
    `scalarMulLinear k (curveAdd P P) = scalarMulLinear (2 * k) P`. -/
theorem scalarMulLinear_double (params : EllipticCurveParams) (k : Nat) (P : CurvePoint)
    (hv : curveParamsValid params) (hp : pointOnCurve params P) :
    scalarMulLinear params k (curveAdd params P P) = scalarMulLinear params (2 * k) P := by
  induction k with
  | zero => simp [scalarMulLinear]
  | succ n ih =>
    simp only [scalarMulLinear]
    rw [ih]
    -- Need: curveAdd (P+P) (scalarMulLinear (2*n) P) = curveAdd P (scalarMulLinear (2*n+1) P)
    -- which is curveAdd (P+P) (scalarMulLinear (2*n) P) = curveAdd P (curveAdd P (scalarMulLinear (2*n) P))
    show curveAdd params (curveAdd params P P) (scalarMulLinear params (2 * n) P) =
      scalarMulLinear params (2 * (n + 1)) P
    have : 2 * (n + 1) = 2 * n + 1 + 1 := by omega
    rw [this]
    simp only [scalarMulLinear]
    rw [← curveAdd_assoc params P P _ hv hp hp
      (scalarMulLinear_onCurve params (2 * n) P hv hp)]

/-- The binary `scalarMul` agrees with the linear `scalarMulLinear` on valid curve points. -/
theorem scalarMul_eq_linear (params : EllipticCurveParams) (k : Nat) (P : CurvePoint)
    (hv : curveParamsValid params) (hp : pointOnCurve params P) :
    scalarMul params k P = scalarMulLinear params k P := by
  have : ∀ m, (∀ j, j < m → ∀ Q, pointOnCurve params Q → scalarMul params j Q = scalarMulLinear params j Q) →
    ∀ Q, pointOnCurve params Q → scalarMul params m Q = scalarMulLinear params m Q := by
    intro m ih Q hQ
    by_cases hm0 : m = 0
    · subst hm0; simp [scalarMulLinear]
    · rw [scalarMul]; simp [hm0]
      have hm_pos : m > 0 := Nat.pos_of_ne_zero hm0
      have hQQ_on : pointOnCurve params (curveAdd params Q Q) :=
        curveAdd_onCurve params Q Q hv hQ hQ
      have hm2_lt : m / 2 < m := Nat.div_lt_self hm_pos (by omega)
      have ih_half := ih (m / 2) hm2_lt (curveAdd params Q Q) hQQ_on
      by_cases heven : m % 2 = 0
      · simp [heven]
        rw [curveAdd_identity_left params _ hv (by rw [ih_half]; exact scalarMulLinear_onCurve params (m / 2) _ hv hQQ_on)]
        rw [ih_half]
        rw [scalarMulLinear_double params (m / 2) Q hv hQ]
        congr 1; omega
      · have hodd : m % 2 = 1 := by omega
        simp [hodd]
        rw [ih_half]
        rw [scalarMulLinear_double params (m / 2) Q hv hQ]
        have h2k : 2 * (m / 2) = m - 1 := by omega
        rw [h2k]
        -- Goal: curveAdd Q (scalarMulLinear (m-1) Q) = scalarMulLinear m Q
        -- Since m > 0, m = Nat.succ (m-1), so scalarMulLinear m Q = curveAdd Q (scalarMulLinear (m-1) Q)
        obtain ⟨m', rfl⟩ : ∃ m', m = m' + 1 := ⟨m - 1, by omega⟩
        rfl
  have key := Nat.strongRecOn
    (motive := fun m => ∀ Q, pointOnCurve params Q → scalarMul params m Q = scalarMulLinear params m Q)
    k (fun m ih => this m (fun j hj => ih j hj))
  exact key P hp

/-- `scalarMulLinear` composes multiplicatively:
    `scalarMulLinear (k1 * k2) P = scalarMulLinear k1 (scalarMulLinear k2 P)`. -/
theorem scalarMulLinear_comp (params : EllipticCurveParams) (k1 k2 : Nat) (P : CurvePoint)
    (hv : curveParamsValid params) (hp : pointOnCurve params P) :
    scalarMulLinear params (k1 * k2) P = scalarMulLinear params k1 (scalarMulLinear params k2 P) := by
  induction k1 with
  | zero => simp [scalarMulLinear]
  | succ n ih =>
    rw [show (n + 1) * k2 = n * k2 + k2 from Nat.succ_mul n k2]
    rw [scalarMulLinear_add params (n * k2) k2 P hv hp]
    simp only [scalarMulLinear]
    rw [ih]
    rw [curveAdd_comm params (scalarMulLinear params k2 P) (scalarMulLinear params n (scalarMulLinear params k2 P)) hv
      (scalarMulLinear_onCurve params k2 P hv hp)
      (scalarMulLinear_onCurve params n _ hv (scalarMulLinear_onCurve params k2 P hv hp))]

/-- `scalarMul` preserves the curve equation. -/
theorem scalarMul_onCurve (params : EllipticCurveParams) (k : Nat) (P : CurvePoint)
    (hv : curveParamsValid params) (hp : pointOnCurve params P) :
    pointOnCurve params (scalarMul params k P) := by
  rw [scalarMul_eq_linear params k P hv hp]
  exact scalarMulLinear_onCurve params k P hv hp

/-- Scalar multiplication distributes over addition:
    `(k1 + k2) * P = k1 * P + k2 * P`.
    Proof sketch: induction on `k1`, using group axioms. -/
theorem scalarMul_add (params : EllipticCurveParams) (k1 k2 : Nat) (P : CurvePoint)
    (hv : curveParamsValid params) (hp : pointOnCurve params P) :
    scalarMul params (k1 + k2) P = curveAdd params (scalarMul params k1 P) (scalarMul params k2 P) := by
  rw [scalarMul_eq_linear params (k1 + k2) P hv hp,
      scalarMul_eq_linear params k1 P hv hp,
      scalarMul_eq_linear params k2 P hv hp]
  exact scalarMulLinear_add params k1 k2 P hv hp

/-- Scalar multiplication composes: `(k1 * k2) * P = k1 * (k2 * P)`.
    Proof sketch: induction on `k1`, using `scalarMul_add`. -/
theorem scalarMul_comp (params : EllipticCurveParams) (k1 k2 : Nat) (P : CurvePoint)
    (hv : curveParamsValid params) (hp : pointOnCurve params P) :
    scalarMul params (k1 * k2) P = scalarMul params k1 (scalarMul params k2 P) := by
  rw [scalarMul_eq_linear params (k1 * k2) P hv hp,
      scalarMul_eq_linear params k1 (scalarMul params k2 P) hv (scalarMul_onCurve params k2 P hv hp),
      scalarMul_eq_linear params k2 P hv hp]
  exact scalarMulLinear_comp params k1 k2 P hv hp

/-- The generator has order `n`: `n * G = infinity` (FIPS 186-5 Section 6.1.1). -/
axiom generator_order (params : EllipticCurveParams)
    (hv : curveParamsValid params) :
    scalarMul params params.n (.affine params.Gx params.Gy) = .infinity

/-- Scalar multiplication respects reduction mod the order of a point:
    if `n * P = infinity` then `(k % n) * P = k * P`. (SEC 1 v2 Section 2.3) -/
axiom scalarMul_mod_order (params : EllipticCurveParams) (k : Nat) (P : CurvePoint)
    (hv : curveParamsValid params)
    (hp : pointOnCurve params P)
    (hord : scalarMul params params.n P = .infinity) :
    scalarMul params (k % params.n) P = scalarMul params k P

/-- The base point is on the curve (follows from `curveParamsValid`). -/
axiom generator_onCurve (params : EllipticCurveParams)
    (hv : curveParamsValid params) :
    pointOnCurve params (.affine params.Gx params.Gy)

/-- ECDSA verification identity: for the generator `G` with order `n` on a valid curve,
    `scalarMul u1 G + scalarMul u2 (scalarMul d G) = scalarMul ((u1 + u2 * d) % n) G`.
    This combines `scalarMul_add`, `scalarMul_comp`, and `scalarMul_mod_order`. -/
axiom ecdsa_verify_point_identity (params : EllipticCurveParams)
    (u1 u2 d : Nat)
    (hv : curveParamsValid params) :
    let G := CurvePoint.affine params.Gx params.Gy
    curveAdd params (scalarMul params u1 G) (scalarMul params u2 (scalarMul params d G)) =
    scalarMul params ((u1 + u2 * d) % params.n) G

end SWELib.Security.Crypto.EllipticCurve
