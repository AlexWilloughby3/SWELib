import SWELib.Security.Crypto.EllipticCurve

/-!
# ECDSA: Elliptic Curve Digital Signature Algorithm

Specification of ECDSA signing and verification per FIPS 186-5 Section 6.4.
Uses deterministic `k` generation per RFC 6979 (Decision D-014).

References:
- FIPS 186-5 Sections 6.4.1 (sign) and 6.4.2 (verify)
- SEC 1 v2 Section 4.1
- RFC 6979 (deterministic k)
-/

namespace SWELib.Security.Crypto.Ecdsa

open EllipticCurve

-- ---------------------------------------------------------------------------
-- Types
-- ---------------------------------------------------------------------------

/-- ECDSA public key: a curve point `Q` on a specific curve (FIPS 186-5 Section 6.2). -/
structure EcPublicKey where
  curve : EllipticCurveParams
  Q : CurvePoint
  deriving Repr

/-- ECDSA private key: a scalar `d` on a specific curve (FIPS 186-5 Section 6.2). -/
structure EcPrivateKey where
  curve : EllipticCurveParams
  d : Nat
  deriving Repr

/-- ECDSA key pair (FIPS 186-5 Section 6.2). -/
structure EcKeyPair where
  priv : EcPrivateKey
  pub : EcPublicKey
  deriving Repr

/-- ECDSA signature: pair `(r, s)` (FIPS 186-5 Section 6.4.1). -/
structure EcdsaSignature where
  r : Nat
  s : Nat
  deriving DecidableEq, Repr

-- ---------------------------------------------------------------------------
-- Predicates
-- ---------------------------------------------------------------------------

/-- A point is valid for ECDSA: it is on the curve, not infinity, and has order `n`
    (i.e., `n * P = infinity`). (FIPS 186-5 Section 6.2) -/
def pointValid (params : EllipticCurveParams) (P : CurvePoint) : Prop :=
  P ≠ .infinity ∧
  pointOnCurve params P ∧
  scalarMul params params.n P = .infinity

/-- Private key validity: `d` is in `[1, n-1]` (FIPS 186-5 Section 6.2). -/
def ecPrivKeyValid (priv : EcPrivateKey) : Prop :=
  priv.d ≥ 1 ∧ priv.d ≤ priv.curve.n - 1

/-- Public key validity: the point is valid and equals `d * G`
    (FIPS 186-5 Section 6.2). -/
def ecPubKeyValid (pub : EcPublicKey) (priv : EcPrivateKey) : Prop :=
  pub.curve = priv.curve ∧
  pointValid pub.curve pub.Q ∧
  pub.Q = scalarMul pub.curve priv.d (.affine pub.curve.Gx pub.curve.Gy)

/-- Signature validity: both `r` and `s` are in `[1, n-1]` (FIPS 186-5 Section 6.4.2). -/
def ecdsaSigValid (sig : EcdsaSignature) (n : Nat) : Prop :=
  sig.r ≥ 1 ∧ sig.r ≤ n - 1 ∧
  sig.s ≥ 1 ∧ sig.s ≤ n - 1

-- ---------------------------------------------------------------------------
-- Bit/byte conversion helpers (RFC 6979 Section 2.3)
-- ---------------------------------------------------------------------------

/-- Convert a byte string to an integer, truncating to `qlen` bits if the input
    is longer. (RFC 6979 Section 2.3.2) -/
def bits2int (bs : ByteArray) (qlen : Nat) : Nat :=
  let raw := bs.foldl (fun acc b => acc * 256 + b.toNat) 0
  if bs.size * 8 > qlen then raw >>> (bs.size * 8 - qlen) else raw

/-- Convert an integer to a byte string of length `ceil(qlen/8)`.
    (RFC 6979 Section 2.3.3) -/
def int2octets (x n : Nat) : ByteArray :=
  let rlen := (n + 7) / 8  -- byte length
  let bytes := Array.ofFn (fun (i : Fin rlen) =>
    ((x / 256 ^ (rlen - 1 - i.val)) % 256).toUInt8)
  ⟨bytes⟩

/-- Convert a bit string to an octet string via bits2int, reduced mod n.
    (RFC 6979 Section 2.3.4) -/
def bits2octets (bs : ByteArray) (n : Nat) : ByteArray :=
  let z := bits2int bs n
  int2octets (z % n) n

-- ---------------------------------------------------------------------------
-- Deterministic k (RFC 6979) — Decision D-014
-- ---------------------------------------------------------------------------

/-- Deterministic nonce generation per RFC 6979. Declared `opaque` because the
    full HMAC-DRBG construction is complex and implemented in the bridge layer. -/
opaque deterministicK (priv : EcPrivateKey) (hash : ByteArray) : Nat

/-- The deterministic nonce is always in `[1, n-1]` (RFC 6979 Section 3.2 step h.3). -/
axiom deterministicK_range (priv : EcPrivateKey) (hash : ByteArray)
    (hvalid : ecPrivKeyValid priv) :
    deterministicK priv hash ≥ 1 ∧ deterministicK priv hash ≤ priv.curve.n - 1

-- ---------------------------------------------------------------------------
-- ECDSA Sign and Verify (FIPS 186-5 Section 6.4)
-- ---------------------------------------------------------------------------

/-- ECDSA signing (FIPS 186-5 Section 6.4.1).
    Returns `none` if `r = 0` or `s = 0` (requires retry with new `k`). -/
noncomputable def ecdsaSign (priv : EcPrivateKey) (hashValue : ByteArray) : Option EcdsaSignature :=
  let params := priv.curve
  let k := deterministicK priv hashValue
  let kG := scalarMul params k (.affine params.Gx params.Gy)
  match kG.xCoord with
  | none => none
  | some xR =>
    let r := xR % params.n
    if r = 0 then none
    else
      let z := bits2int hashValue (Nat.log2 params.n + 1)
      match modInverse k params.n with
      | none => none
      | some kInv =>
        let s := (kInv * (z + r * priv.d)) % params.n
        if s = 0 then none
        else some ⟨r, s⟩

/-- ECDSA verification (FIPS 186-5 Section 6.4.2).
    Returns `true` if the signature is valid. -/
noncomputable def ecdsaVerify (pub : EcPublicKey) (hashValue : ByteArray) (sig : EcdsaSignature) : Bool :=
  let params := pub.curve
  if sig.r = 0 || sig.r ≥ params.n || sig.s = 0 || sig.s ≥ params.n then false
  else
    let z := bits2int hashValue (Nat.log2 params.n + 1)
    match modInverse sig.s params.n with
    | none => false
    | some sInv =>
      let u1 := (z * sInv) % params.n
      let u2 := (sig.r * sInv) % params.n
      let G := CurvePoint.affine params.Gx params.Gy
      let R := curveAdd params (scalarMul params u1 G) (scalarMul params u2 pub.Q)
      match R.xCoord with
      | none => false
      | some xR => xR % params.n == sig.r

-- ---------------------------------------------------------------------------
-- Theorems
-- ---------------------------------------------------------------------------

/-- A successful `ecdsaSign` produces a valid signature (r, s in [1, n-1]).
    (FIPS 186-5 Section 6.4.1) -/
theorem ecdsaSign_sig_valid (priv : EcPrivateKey) (hash : ByteArray)
    (sig : EcdsaSignature)
    (hvalid : ecPrivKeyValid priv)
    (hsign : ecdsaSign priv hash = some sig) :
    ecdsaSigValid sig priv.curve.n := by
  rcases hvalid with ⟨hd1, hd2⟩
  have hn : priv.curve.n > 0 := by omega
  unfold ecdsaSign at hsign
  cases hx : (scalarMul priv.curve (deterministicK priv hash)
      (.affine priv.curve.Gx priv.curve.Gy)).xCoord with
  | none =>
      simp [hx] at hsign
  | some xR =>
      by_cases hr0 : xR % priv.curve.n = 0
      · simp [hx, hr0] at hsign
      · cases hk : SWELib.Security.Crypto.modInverse (deterministicK priv hash) priv.curve.n with
        | none =>
            simp [hx, hr0, hk] at hsign
        | some kInv =>
            by_cases hs0 :
                (kInv * (bits2int hash (Nat.log2 priv.curve.n + 1) + (xR % priv.curve.n) * priv.d)) %
                  priv.curve.n = 0
            · simp [hx, hr0, hk, hs0] at hsign
            · simp [hx, hr0, hk, hs0] at hsign
              cases hsign
              have hrlt : xR % priv.curve.n < priv.curve.n := Nat.mod_lt _ hn
              have hslt :
                  (kInv * (bits2int hash (Nat.log2 priv.curve.n + 1) + (xR % priv.curve.n) * priv.d)) %
                    priv.curve.n < priv.curve.n := Nat.mod_lt _ hn
              simp [ecdsaSigValid]
              omega

/-- Core ECDSA algebraic identity: if `s = (kInv * (z + r * d)) % n` where
    `kInv` is the modular inverse of `k`, and `sInv` is the modular inverse of `s`,
    and `r = xCoord(k*G) % n`, then the verification point equals `k*G`:
    ```
    curveAdd (scalarMul ((z * sInv) % n) G) (scalarMul ((r * sInv) % n) (scalarMul d G))
      = scalarMul k G
    ```
    This is the central algebraic identity of ECDSA (FIPS 186-5 Section 6.4).
    Proof: s = kInv*(z+r*d) mod n, so sInv*(z+r*d) = sInv*s*k = k mod n.
    Then u1*G + u2*(d*G) = (u1+u2*d)*G = sInv*(z+r*d)*G = k*G (mod order). -/
axiom ecdsa_algebraic_identity
    (params : EllipticCurveParams) (k kInv d z r sInv : Nat)
    (hv : curveParamsValid params)
    (hk_range : k ≥ 1 ∧ k ≤ params.n - 1)
    (hkInv : modInverse k params.n = some kInv)
    (hs_nonzero : (kInv * (z + r * d)) % params.n ≠ 0)
    (hsInv : modInverse ((kInv * (z + r * d)) % params.n) params.n = some sInv) :
    let G := CurvePoint.affine params.Gx params.Gy
    curveAdd params
      (scalarMul params ((z * sInv) % params.n) G)
      (scalarMul params ((r * sInv) % params.n) (scalarMul params d G)) =
    scalarMul params k G

/-- ECDSA correctness: a signature produced by `ecdsaSign` is accepted by `ecdsaVerify`.
    Proof sketch:
    1. `ecdsaSign` computes `r = (k*G).x mod n`, `s = k^{-1}(z + r*d) mod n`
    2. `ecdsaVerify` computes `u1 = z*s^{-1}`, `u2 = r*s^{-1}`
    3. `u1*G + u2*Q = (z*s^{-1})*G + (r*s^{-1})*(d*G) = s^{-1}*(z + r*d)*G = k*G`
    4. So the x-coordinate matches `r`. -/
theorem ecdsa_correctness (priv : EcPrivateKey) (pub : EcPublicKey)
    (hash : ByteArray) (sig : EcdsaSignature)
    (hprivValid : ecPrivKeyValid priv)
    (hpubValid : ecPubKeyValid pub priv)
    (hparams : curveParamsValid priv.curve)
    (hsign : ecdsaSign priv hash = some sig) :
    ecdsaVerify pub hash sig = true := by
  -- Extract key validity
  rcases hpubValid with ⟨hcurve_eq, hpubPt, hQ_eq⟩
  -- Sig validity
  have hsigv := ecdsaSign_sig_valid priv hash sig hprivValid hsign
  rcases hsigv with ⟨hr1, hr2, hs1, hs2⟩
  -- Params
  have hn_prime : IsPrime priv.curve.n := hparams.2.2.2.1
  have hn_gt1 : priv.curve.n > 1 := by rcases hn_prime with ⟨h2, _⟩; omega
  -- k range
  have hk_range := deterministicK_range priv hash hprivValid
  -- Deconstruct ecdsaSign to extract intermediate values
  unfold ecdsaSign at hsign
  cases hxR : (scalarMul priv.curve (deterministicK priv hash)
      (.affine priv.curve.Gx priv.curve.Gy)).xCoord with
  | none => simp [hxR] at hsign
  | some xR =>
    by_cases hr0 : xR % priv.curve.n = 0
    · simp [hxR, hr0] at hsign
    · cases hkInv : SWELib.Security.Crypto.modInverse (deterministicK priv hash) priv.curve.n with
      | none => simp [hxR, hr0, hkInv] at hsign
      | some kInv =>
        by_cases hs0 :
            (kInv * (bits2int hash (Nat.log2 priv.curve.n + 1) +
              (xR % priv.curve.n) * priv.d)) % priv.curve.n = 0
        · simp [hxR, hr0, hkInv, hs0] at hsign
        · simp [hxR, hr0, hkInv, hs0] at hsign
          -- hsign now gives us the concrete sig values
          have hsig_r : sig.r = xR % priv.curve.n := by cases hsign; rfl
          have hsig_s : sig.s = (kInv * (bits2int hash (Nat.log2 priv.curve.n + 1) +
              (xR % priv.curve.n) * priv.d)) % priv.curve.n := by cases hsign; rfl
          -- s is coprime to n
          have hs_coprime : Nat.gcd sig.s priv.curve.n = 1 :=
            gcd_prime_coprime sig.s priv.curve.n hn_prime hs1 hs2
          obtain ⟨sInv, hsInv⟩ := modInverse_some_exists sig.s priv.curve.n hs_coprime hn_gt1
          -- Apply the algebraic identity
          have halg := ecdsa_algebraic_identity priv.curve
            (deterministicK priv hash) kInv priv.d
            (bits2int hash (Nat.log2 priv.curve.n + 1))
            (xR % priv.curve.n) sInv
            hparams hk_range hkInv hs0 (by rw [← hsig_s]; exact hsInv)
          -- Unfold ecdsaVerify and simplify
          unfold ecdsaVerify
          -- Simplify pub.curve → priv.curve, and handle the range check
          simp only [hcurve_eq]
          -- The if condition: sig.r = 0 || sig.r >= n || sig.s = 0 || sig.s >= n
          have hif_cond : ¬ ((decide (sig.r = 0) || decide (sig.r ≥ priv.curve.n) ||
            decide (sig.s = 0) || decide (sig.s ≥ priv.curve.n)) = true) := by
            simp; omega
          rw [if_neg hif_cond]
          -- modInverse sig.s n = some sInv
          simp only [hsInv]
          -- Rewrite Q = d * G
          rw [hQ_eq, hcurve_eq]
          -- Rewrite sig.r to the concrete value
          rw [hsig_r]
          -- Now use the algebraic identity
          rw [halg]
          -- Now goal: match (scalarMul k G).xCoord with ...
          simp only [hxR]
          -- Goal: (xR % n == xR % n) = true
          simp

end SWELib.Security.Crypto.Ecdsa
