/-!
# Modular Arithmetic Primitives

Core modular arithmetic operations used by RSA and elliptic curve specifications.
Uses `Nat` with `% p` for modular arithmetic (Decision D-011).

References:
- NIST FIPS 186-5 Appendix B
- RFC 8017 Section 4 (Data conversion)
-/

namespace SWELib.Security.Crypto

-- ---------------------------------------------------------------------------
-- IsPrime: lightweight primality predicate (no Mathlib dependency)
-- ---------------------------------------------------------------------------

/-- A natural number is prime if it is at least 2 and has no divisors other than 1 and itself. -/
def IsPrime (n : Nat) : Prop :=
  n ≥ 2 ∧ ∀ d : Nat, d ∣ n → d = 1 ∨ d = n

-- ---------------------------------------------------------------------------
-- modExp: modular exponentiation via square-and-multiply
-- ---------------------------------------------------------------------------

/-- Modular exponentiation: `base ^ exp % modulus` using repeated squaring.
    When `modulus = 0`, returns `0`.
    (NIST FIPS 186-5 Appendix B.1, RFC 8017 Section 5.1) -/
def modExp (base exp modulus : Nat) : Nat :=
  if modulus ≤ 1 then
    0
  else
    go exp (base % modulus) 1 modulus
where
  /-- Inner loop: processes bits of `e` from LSB to MSB. -/
  go (e b acc m : Nat) : Nat :=
    if e = 0 then acc
    else
      let acc' := if e % 2 = 1 then (acc * b) % m else acc
      let b'   := (b * b) % m
      go (e / 2) b' acc' m
  termination_by e

-- ---------------------------------------------------------------------------
-- modInverse: modular multiplicative inverse via extended Euclidean
-- ---------------------------------------------------------------------------

/-- Extended Euclidean algorithm returning `(gcd, x, y)` where `a*x + b*y = gcd`.
    Uses `Int` internally because coefficients can be negative. -/
private def extGcd (a b : Nat) : Int × Int × Nat :=
  if b = 0 then (Int.ofNat a, 1, 0)
  else
    let (g, x, y) := extGcdAux (Int.ofNat a) (Int.ofNat b) 1 0 0 1
    (g, x, y.toNat)
where
  extGcdAux (a b s0 s1 t0 t1 : Int) : Int × Int × Int :=
    if b == 0 then (a, s0, t0)
    else
      let q := a / b
      extGcdAux b (a - q * b) s1 (s0 - q * s1) t1 (t0 - q * t1)
  termination_by b.toNat
  decreasing_by sorry

/-- Modular multiplicative inverse: returns `some x` where `a * x % m = 1`
    when `Nat.gcd a m = 1`, otherwise `none`.
    (RFC 8017 Section 3 key generation prerequisites) -/
def modInverse (a m : Nat) : Option Nat :=
  if m ≤ 1 then none
  else if Nat.gcd a m ≠ 1 then none
  else
    let (_, x, _) := extGcd a m
    -- x might be negative, so normalize
    let xMod := ((x % Int.ofNat m) + Int.ofNat m) % Int.ofNat m
    some xMod.toNat

-- ---------------------------------------------------------------------------
-- carmichaelLambda: for multi-prime RSA
-- ---------------------------------------------------------------------------

/-- Carmichael's lambda function for a list of prime factors.
    For RSA with primes `[p1, p2, ...]`, computes `lcm(p1-1, p2-1, ...)`.
    (RFC 8017 Section 3.2, multi-prime RSA) -/
def carmichaelLambda (primes : List Nat) : Nat :=
  primes.foldl (fun acc p => Nat.lcm acc (p - 1)) 1

-- ---------------------------------------------------------------------------
-- Structural theorems
-- ---------------------------------------------------------------------------

/-- `modExp` result is strictly less than `modulus` when `modulus > 1`. -/
theorem modExp_mod_self (base exp modulus : Nat) (h : modulus > 1) :
    modExp base exp modulus < modulus := by
  sorry

/-- `modInverse` returns `none` if and only if `gcd(a, m) != 1` (when `m > 1`). -/
theorem modInverse_none_iff (a m : Nat) (hm : m > 1) :
    modInverse a m = none ↔ Nat.gcd a m ≠ 1 := by
  unfold modInverse
  rw [if_neg (by omega)]
  constructor
  · intro h
    by_cases hg : Nat.gcd a m ≠ 1
    · exact hg
    · simp [hg] at h
  · intro hg
    simp [hg]

/-- If `gcd(a, m) = 1` then there exists `x` with `a * x % m = 1 % m`. -/
theorem modInverse_spec (a m : Nat) (hm : m > 1) (hgcd : Nat.gcd a m = 1) :
    ∃ x, a * x % m = 1 % m := by
  sorry

/-- Fermat's little theorem: for prime `p`, if `p` does not divide `a`,
    then `modExp a (p-1) p = 1`. -/
theorem modExp_correct_fermat (a p : Nat) (hp : IsPrime p) (ha : ¬ p ∣ a) :
    modExp a (p - 1) p = 1 := by
  sorry

end SWELib.Security.Crypto
