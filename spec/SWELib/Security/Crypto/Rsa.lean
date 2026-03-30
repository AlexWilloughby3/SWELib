import SWELib.Security.Crypto.ModularArith

/-!
# RSA Cryptographic Primitives

Specification of RSA key types and core operations per PKCS #1 v2.2 (RFC 8017).
Key material uses `Nat` in this spec layer; the JWT layer uses `ByteArray`
(see `SWELib.Security.Jwt` for the boundary -- Decision D-016).

References:
- RFC 8017 Sections 3-5
- FIPS 186-5 Section 5
-/

namespace SWELib.Security.Crypto.Rsa

-- ---------------------------------------------------------------------------
-- Types
-- ---------------------------------------------------------------------------

/-- RSA public key (RFC 8017 Section 3.1).
    - `n`: RSA modulus
    - `e`: public exponent -/
structure RsaPublicKey where
  n : Nat
  e : Nat
  deriving DecidableEq, Repr

/-- RSA private key in simple (d, n) form (RFC 8017 Section 3.2, representation 1). -/
structure RsaPrivateKeySimple where
  n : Nat
  d : Nat
  deriving DecidableEq, Repr

/-- RSA private key in CRT (Chinese Remainder Theorem) form (RFC 8017 Section 3.2, representation 2).
    For multi-prime RSA, `extra` contains `(r_i, d_i, t_i)` triplets for primes beyond p and q. -/
structure RsaPrivateKeyCrt where
  p : Nat
  q : Nat
  dP : Nat
  dQ : Nat
  qInv : Nat
  extra : List (Nat × Nat × Nat) := []
  deriving DecidableEq, Repr

/-- RSA private key: either simple or CRT representation (RFC 8017 Section 3.2). -/
inductive RsaPrivateKey where
  | simple : RsaPrivateKeySimple → RsaPrivateKey
  | crt : RsaPrivateKeyCrt → RsaPrivateKey
  deriving Repr

/-- RSA key pair bundling public and private keys (RFC 8017 Section 3). -/
structure RsaKeyPair where
  pub : RsaPublicKey
  priv : RsaPrivateKey
  deriving Repr

/-- An integer representative of a message (RFC 8017 Section 4). -/
abbrev MessageRepresentative := Nat

/-- An integer representative of a ciphertext (RFC 8017 Section 5.1). -/
abbrev CiphertextRepresentative := Nat

/-- An integer representative of a signature (RFC 8017 Section 5.2). -/
abbrev SignatureRepresentative := Nat

-- ---------------------------------------------------------------------------
-- Predicates
-- ---------------------------------------------------------------------------

/-- Validity predicate for an RSA public key (RFC 8017 Section 3.1).
    Requires `n` be a product of at least two primes, `e` in range, and
    `gcd(e, lambda(n)) = 1`. The `primes` parameter is a witness list of factors. -/
def rsaPublicKeyValid (pub : RsaPublicKey) (primes : List Nat) : Prop :=
  primes.length ≥ 2 ∧
  (∀ p ∈ primes, IsPrime p) ∧
  pub.n = primes.foldl (· * ·) 1 ∧
  pub.e ≥ 3 ∧
  pub.e < carmichaelLambda primes ∧
  Nat.gcd pub.e (carmichaelLambda primes) = 1

/-- Validity predicate for a simple RSA private key (RFC 8017 Section 3.2). -/
def rsaPrivateKeySimpleValid (priv : RsaPrivateKeySimple) (pub : RsaPublicKey) (primes : List Nat) : Prop :=
  priv.n = pub.n ∧
  (pub.e * priv.d) % carmichaelLambda primes = 1

/-- Validity of a single multi-prime extra triplet `(r, d, t)` relative to the
    accumulated preceding-prime product `R` (RFC 8017 Section 3.2). -/
def rsaCrtTripletValid (pub : RsaPublicKey) (R : Nat) (triplet : Nat × Nat × Nat) : Prop :=
  let (r, d, t) := triplet
  IsPrime r ∧
  (pub.e * d) % (r - 1) = 1 ∧  -- e*d_i ≡ 1 (mod r_i - 1)
  (R * t) % r = 1 ∧            -- R_i * t_i ≡ 1 (mod r_i)
  t < r                          -- t_i < r_i

/-- Validity predicate for a CRT RSA private key (RFC 8017 Section 3.2). -/
def rsaPrivateKeyCrtValid (priv : RsaPrivateKeyCrt) (pub : RsaPublicKey) : Prop :=
  IsPrime priv.p ∧
  IsPrime priv.q ∧
  priv.p ≠ priv.q ∧
  pub.n = priv.p * priv.q * priv.extra.foldl (fun acc (r, _, _) => acc * r) 1 ∧
  -- RFC 8017 §3.2: e*dP ≡ 1 (mod p-1), e*dQ ≡ 1 (mod q-1)
  (pub.e * priv.dP) % (priv.p - 1) = 1 ∧
  (pub.e * priv.dQ) % (priv.q - 1) = 1 ∧
  -- RFC 8017 §3.2: q*qInv ≡ 1 (mod p); qInv < p
  (priv.q * priv.qInv) % priv.p = 1 ∧
  priv.qInv < priv.p ∧
  -- Validate each extra prime triplet (multi-prime RSA, RFC 8017 §3.2)
  (priv.extra.foldl (fun (acc : Prop × Nat) (triplet : Nat × Nat × Nat) =>
    let (r, _, _) := triplet
    (acc.1 ∧ rsaCrtTripletValid pub acc.2 triplet, acc.2 * r))
    (True, priv.p * priv.q)).1

/-- A key pair is valid when the public key is valid and the private key is
    consistent with it (RFC 8017 Section 3). -/
def rsaKeyPairValid (kp : RsaKeyPair) (primes : List Nat) : Prop :=
  rsaPublicKeyValid kp.pub primes ∧
  match kp.priv with
  | .simple s => rsaPrivateKeySimpleValid s kp.pub primes
  | .crt c => rsaPrivateKeyCrtValid c kp.pub

-- ---------------------------------------------------------------------------
-- Data Conversion (RFC 8017 Section 4)
-- ---------------------------------------------------------------------------

/-- Octet string to integer: big-endian conversion (RFC 8017 Section 4.2).
    `OS2IP(X) = sum_{i=0}^{xLen-1} x_i * 256^(xLen-1-i)` -/
def os2ip (X : ByteArray) : Nat :=
  X.foldl (fun acc b => acc * 256 + b.toNat) 0

/-- Integer to octet string: big-endian conversion (RFC 8017 Section 4.1).
    Returns `none` if `x >= 256^xLen` (overflow). -/
def i2osp (x xLen : Nat) : Option ByteArray :=
  if x ≥ 256 ^ xLen then none
  else
    let bytes := Array.ofFn (fun (i : Fin xLen) =>
      ((x / 256 ^ (xLen - 1 - i.val)) % 256).toUInt8)
    some ⟨bytes⟩

-- ---------------------------------------------------------------------------
-- Core RSA Operations (RFC 8017 Section 5)
-- ---------------------------------------------------------------------------

/-- RSAEP: RSA encryption primitive (RFC 8017 Section 5.1.1).
    Computes `m^e mod n`. -/
def rsaep (pub : RsaPublicKey) (m : MessageRepresentative) : CiphertextRepresentative :=
  modExp m pub.e pub.n

/-- RSAVP1: RSA verification primitive (RFC 8017 Section 5.2.2).
    Identical to RSAEP: `s^e mod n`. -/
def rsavp1 (pub : RsaPublicKey) (s : SignatureRepresentative) : MessageRepresentative :=
  rsaep pub s

/-- RSADP: RSA decryption primitive (RFC 8017 Section 5.1.2).
    Pattern matches on simple vs CRT representation. CRT uses Garner's algorithm. -/
noncomputable def rsadp (priv : RsaPrivateKey) (c : CiphertextRepresentative) : MessageRepresentative :=
  match priv with
  | .simple s => modExp c s.d s.n
  | .crt crt =>
    let m1 := modExp c crt.dP crt.p
    let m2 := modExp c crt.dQ crt.q
    -- Use (m1 + p - m2 % p) % p to avoid Nat underflow (I8 fix: m2 may be >= m1)
    let h := (crt.qInv * ((m1 + crt.p - m2 % crt.p) % crt.p)) % crt.p
    m2 + crt.q * h

/-- RSASP1: RSA signature primitive (RFC 8017 Section 5.2.1).
    Identical to RSADP. -/
noncomputable def rsasp1 (priv : RsaPrivateKey) (m : MessageRepresentative) : SignatureRepresentative :=
  rsadp priv m

-- ---------------------------------------------------------------------------
-- Theorems
-- ---------------------------------------------------------------------------

/-- RSAEP and RSAVP1 are the same operation (RFC 8017 Section 5.2.2 Note). -/
theorem rsaep_eq_rsavp1 (pub : RsaPublicKey) (s : SignatureRepresentative) :
    rsaep pub s = rsavp1 pub s := by rfl

/-- RSASP1 and RSADP are the same operation (RFC 8017 Section 5.2.1 Note). -/
theorem rsasp1_eq_rsadp (priv : RsaPrivateKey) (m : MessageRepresentative) :
    rsasp1 priv m = rsadp priv m := by rfl

/-- `i2osp` output has length `xLen` when it succeeds (RFC 8017 Section 4.1). -/
theorem i2osp_length (x xLen : Nat) (out : ByteArray)
    (h : i2osp x xLen = some out) :
    out.size = xLen := by
  unfold i2osp at h
  split at h
  · simp at h
  · cases h
    simp [ByteArray.size]

/-- Roundtrip: `os2ip (i2osp x xLen) = x` when `i2osp` succeeds.
    Proof sketch: each byte extracts exactly the corresponding 8 bits
    from the big-endian representation of `x`. -/
axiom os2ip_i2osp_roundtrip (x xLen : Nat) (out : ByteArray)
    (h : i2osp x xLen = some out) :
    os2ip out = x

/-- RSAEP/RSADP roundtrip for simple keys: `rsaep pub (rsadp (simple priv) c) = c`
    when the key pair is valid and `c < n`.
    Proof sketch: follows from `m^(e*d) = m (mod n)` by Euler's theorem. -/
axiom rsaep_rsadp_roundtrip (pub : RsaPublicKey) (priv : RsaPrivateKeySimple)
    (primes : List Nat)
    (hpub : rsaPublicKeyValid pub primes)
    (hpriv : rsaPrivateKeySimpleValid priv pub primes)
    (c : CiphertextRepresentative) (hc : c < pub.n) :
    rsaep pub (rsadp (.simple priv) c) = c

/-- RSASP1/RSAVP1 roundtrip: `rsavp1 pub (rsasp1 (simple priv) m) = m`
    when the key pair is valid and `m < n`.
    Proof sketch: same as RSAEP/RSADP roundtrip since they are the same operations. -/
theorem rsasp1_rsavp1_roundtrip (pub : RsaPublicKey) (priv : RsaPrivateKeySimple)
    (primes : List Nat)
    (hpub : rsaPublicKeyValid pub primes)
    (hpriv : rsaPrivateKeySimpleValid priv pub primes)
    (m : MessageRepresentative) (hm : m < pub.n) :
    rsavp1 pub (rsasp1 (.simple priv) m) = m := by
  unfold rsavp1 rsasp1
  simpa [rsaep, rsadp] using rsaep_rsadp_roundtrip pub priv primes hpub hpriv m hm

/-- CRT computation yields the same result as simple exponentiation.
    Proof sketch: CRT reconstruction via Garner's algorithm is equivalent
    to `c^d mod n` by the Chinese Remainder Theorem. -/
axiom rsadp_crt_eq_simple (simple : RsaPrivateKeySimple) (crt : RsaPrivateKeyCrt)
    (pub : RsaPublicKey) (primes : List Nat)
    (hpub : rsaPublicKeyValid pub primes)
    (hs : rsaPrivateKeySimpleValid simple pub primes)
    (hc : rsaPrivateKeyCrtValid crt pub)
    (c : CiphertextRepresentative) (hlt : c < pub.n) :
    rsadp (.simple simple) c = rsadp (.crt crt) c

end SWELib.Security.Crypto.Rsa
