import SWELib.Security.Crypto.ModularArith

/-!
# Montgomery Curve Operations (X25519 / X448)

Specification of the Montgomery ladder for Curve25519 and Curve448 key exchange,
per RFC 7748.

`montgomeryLadder` is `opaque` with axiom `montgomeryLadder_correct` (Decision D-015).
ECDH keys carry no subgroup predicate (Decision: pointValid scope).

References:
- RFC 7748 Sections 5 and 6
- RFC 8032 (Ed25519, referenced for constants)
-/

namespace SWELib.Security.Crypto.Montgomery

-- ---------------------------------------------------------------------------
-- Types
-- ---------------------------------------------------------------------------

/-- Parameters for a Montgomery curve `B*y^2 = x^3 + A*x^2 + x` over `F_p`.
    (RFC 7748 Section 4.1)
    - `p`: prime field modulus
    - `A`: Montgomery coefficient
    - `a24`: `(A - 2) / 4`, used in the ladder
    - `cofactor`: curve cofactor
    - `basePoint`: u-coordinate of the generator
    - `scalarBits`: bit length of scalars
    - `scalarBytes`: byte length of scalars -/
structure MontgomeryCurveParams where
  p : Nat
  A : Nat
  a24 : Nat
  cofactor : Nat
  basePoint : Nat
  scalarBits : Nat
  scalarBytes : Nat
  deriving DecidableEq, Repr

/-- Curve25519 parameters (RFC 7748 Section 4.1). -/
def x25519Params : MontgomeryCurveParams where
  p := 2 ^ 255 - 19
  A := 486662
  a24 := 121665
  cofactor := 8
  basePoint := 9
  scalarBits := 255
  scalarBytes := 32

/-- Curve448 parameters (RFC 7748 Section 4.2). -/
def x448Params : MontgomeryCurveParams where
  p := 2 ^ 448 - 2 ^ 224 - 1
  A := 156326
  a24 := 39081
  cofactor := 4
  basePoint := 5
  scalarBits := 448
  scalarBytes := 56

-- ---------------------------------------------------------------------------
-- Byte encoding helpers
-- ---------------------------------------------------------------------------

/-- Decode a little-endian byte array to a natural number.
    (RFC 7748 Section 5) -/
def decodeLittleEndian (bs : ByteArray) : Nat :=
  bs.data.foldl (fun (i, acc) b => (i + 1, acc + b.toNat * 256 ^ i)) (0, 0) |>.2

/-- Encode a natural number as a little-endian byte array of given length.
    (RFC 7748 Section 5) -/
def encodeLittleEndian (n : Nat) (len : Nat) : ByteArray :=
  ⟨Array.ofFn (fun (i : Fin len) => ((n >>> (i.val * 8)) &&& 0xFF).toUInt8)⟩

-- ---------------------------------------------------------------------------
-- Scalar clamping (RFC 7748 Section 5)
-- ---------------------------------------------------------------------------

/-- Clamp a 32-byte scalar for X25519 (RFC 7748 Section 5):
    `k[0] &= 248; k[31] &= 127; k[31] |= 64` -/
def clampScalar25519 (k : ByteArray) : ByteArray :=
  if k.size < 32 then k
  else
    let k0 := k.set! 0 (k.get! 0 &&& 248)
    let k1 := k0.set! 31 (k0.get! 31 &&& 127)
    k1.set! 31 (k1.get! 31 ||| 64)

/-- Clamp a 56-byte scalar for X448 (RFC 7748 Section 5):
    `k[0] &= 252; k[55] |= 128` -/
def clampScalar448 (k : ByteArray) : ByteArray :=
  if k.size < 56 then k
  else
    let k0 := k.set! 0 (k.get! 0 &&& 252)
    k0.set! 55 (k0.get! 55 ||| 128)

-- ---------------------------------------------------------------------------
-- Montgomery ladder (Decision D-015)
-- ---------------------------------------------------------------------------

/-- The Montgomery ladder: scalar multiplication on a Montgomery curve using
    only the x-coordinate. Declared `opaque` because the full implementation
    is complex and lives in the bridge layer.
    (RFC 7748 Section 5) -/
opaque montgomeryLadder (k u : Nat) (params : MontgomeryCurveParams) : Nat

/-- The Montgomery ladder output is always in `[0, p)`.
    (RFC 7748 Section 5) -/
axiom montgomeryLadder_correct (k u : Nat) (params : MontgomeryCurveParams) :
    montgomeryLadder k u params < params.p

-- ---------------------------------------------------------------------------
-- X25519 and X448 (RFC 7748 Sections 5-6)
-- ---------------------------------------------------------------------------

/-- X25519 scalar multiplication (RFC 7748 Section 5).
    Clamps the scalar, decodes inputs as little-endian, runs the Montgomery ladder,
    and encodes the result as little-endian.
    NOTE: RFC 7748 §5 REQUIRES masking the MSB of u[31] (bit 255) before decoding.
    This is NOT the same as reducing mod p; masking clears bit 255 while mod p
    subtracts (2^255 - 19), differing by 19 for inputs with bit 255 set. -/
def x25519 (k u : ByteArray) : ByteArray :=
  let kClamped := clampScalar25519 k
  let kScalar := decodeLittleEndian kClamped
  -- Mask MSB of last byte per RFC 7748 §5 (X25519-specific; X448 does NOT do this)
  let uMasked := if u.size = 32 then u.set! 31 (u.get! 31 &&& 127) else u
  let uScalar := decodeLittleEndian uMasked
  let result := montgomeryLadder kScalar uScalar x25519Params
  encodeLittleEndian result 32

/-- X448 scalar multiplication (RFC 7748 Section 5).
    Note: X448 does NOT mask the MSB of the u-coordinate (unlike X25519). -/
def x448 (k u : ByteArray) : ByteArray :=
  let kClamped := clampScalar448 k
  let kScalar := decodeLittleEndian kClamped
  -- No MSB masking for X448 (RFC 7748 §5)
  let uScalar := decodeLittleEndian u
  let result := montgomeryLadder kScalar uScalar x448Params
  encodeLittleEndian result 56

-- ---------------------------------------------------------------------------
-- Diffie-Hellman commutativity axiom (Decision D-015)
-- ---------------------------------------------------------------------------

/-- X25519 Diffie-Hellman commutativity: `x25519 a (x25519 b basepoint) = x25519 b (x25519 a basepoint)`.
    This is the fundamental property that makes ECDH work.
    Proof would require showing that montgomeryLadder implements scalar multiplication
    on the Montgomery curve group, and that the group is abelian: a*(b*G) = b*(a*G).
    (RFC 7748 Section 6.1, Decision D-015) -/
axiom x25519_dh_commutativity (a b : ByteArray) (ha : a.size = 32) (hb : b.size = 32) :
    x25519 a (x25519 b (encodeLittleEndian x25519Params.basePoint 32)) =
    x25519 b (x25519 a (encodeLittleEndian x25519Params.basePoint 32))

-- ---------------------------------------------------------------------------
-- Theorems
-- ---------------------------------------------------------------------------

/-- Clamping X25519 scalars is idempotent:
    `clampScalar25519 (clampScalar25519 k) = clampScalar25519 k`.
    Proof: bit masking and setting operations are idempotent. -/
theorem clampScalar25519_idempotent (k : ByteArray) (hk : k.size ≥ 32) :
    clampScalar25519 (clampScalar25519 k) = clampScalar25519 k := by
  sorry

/-- Clamping X448 scalars is idempotent. -/
theorem clampScalar448_idempotent (k : ByteArray) (hk : k.size ≥ 56) :
    clampScalar448 (clampScalar448 k) = clampScalar448 k := by
  sorry

/-- The X25519 base point encodes as the byte 9 followed by 31 zero bytes (little-endian).
    (RFC 7748 Section 6.1) -/
theorem x25519_basePoint_encoding :
    encodeLittleEndian x25519Params.basePoint 32 =
    ⟨#[9, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
       0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]⟩ := by native_decide

end SWELib.Security.Crypto.Montgomery
