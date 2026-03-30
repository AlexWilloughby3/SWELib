import SWELib.Security.Crypto.Montgomery

/-!
# ECDH: Elliptic Curve Diffie-Hellman Key Agreement

Specification of X25519 and X448 ECDH key agreement per RFC 7748 Section 6.
ECDH keys carry no subgroup predicate (Decision: pointValid scope).
Key material is `ByteArray` at the ECDH interface level.

References:
- RFC 7748 Section 6
- NIST SP 800-56A Rev 3
-/

namespace SWELib.Security.Crypto.Ecdh

open Montgomery

/-- ECDH shared secret type alias (RFC 7748 Section 6). -/
abbrev EcdhSharedSecret := ByteArray

-- ---------------------------------------------------------------------------
-- Public key generation
-- ---------------------------------------------------------------------------

/-- Generate an X25519 public key from a private key.
    `pub = X25519(priv, basepoint)` where basepoint = 9.
    (RFC 7748 Section 6.1) -/
def generatePublicKey25519 (priv : ByteArray) : ByteArray :=
  x25519 priv (encodeLittleEndian x25519Params.basePoint 32)

/-- Generate an X448 public key from a private key.
    `pub = X448(priv, basepoint)` where basepoint = 5.
    (RFC 7748 Section 6.2) -/
def generatePublicKey448 (priv : ByteArray) : ByteArray :=
  x448 priv (encodeLittleEndian x448Params.basePoint 56)

-- ---------------------------------------------------------------------------
-- Shared secret computation
-- ---------------------------------------------------------------------------

/-- All-zeros check for a byte array (RFC 7748 Section 6.1). -/
private def isAllZeros (bs : ByteArray) : Bool :=
  bs.data.all (· == 0)

/-- Compute an X25519 ECDH shared secret.
    Returns `none` if the result is the all-zeros value (which indicates
    a low-order input point, per RFC 7748 Section 6.1).
    (RFC 7748 Section 6.1) -/
def ecdhSharedSecret25519 (myPriv theirPub : ByteArray) : Option EcdhSharedSecret :=
  let result := x25519 myPriv theirPub
  if isAllZeros result then none else some result

/-- Compute an X448 ECDH shared secret.
    Returns `none` if the result is the all-zeros value.
    (RFC 7748 Section 6.2) -/
def ecdhSharedSecret448 (myPriv theirPub : ByteArray) : Option EcdhSharedSecret :=
  let result := x448 myPriv theirPub
  if isAllZeros result then none else some result

-- ---------------------------------------------------------------------------
-- Theorems
-- ---------------------------------------------------------------------------

/-- ECDH shared secret symmetry for X25519:
    `ecdhSharedSecret25519 a (generatePublicKey25519 b)` and
    `ecdhSharedSecret25519 b (generatePublicKey25519 a)` yield the same raw value
    (before the all-zeros check).
    Proof depends on `x25519_dh_commutativity` axiom.
    (RFC 7748 Section 6.1) -/
theorem ecdhSharedSecret25519_symm (a b : ByteArray) (ha : a.size = 32) (hb : b.size = 32) :
    x25519 a (generatePublicKey25519 b) = x25519 b (generatePublicKey25519 a) := by
  unfold generatePublicKey25519
  exact x25519_dh_commutativity a b ha hb

/-- X25519 public keys are 32 bytes (RFC 7748 Section 6.1). -/
theorem generatePublicKey25519_size (priv : ByteArray) :
    (generatePublicKey25519 priv).size = 32 := by
  unfold generatePublicKey25519 x25519
  change (encodeLittleEndian
      (montgomeryLadder (decodeLittleEndian (clampScalar25519 priv))
        (decodeLittleEndian
          (if (encodeLittleEndian x25519Params.basePoint 32).size = 32 then
            (encodeLittleEndian x25519Params.basePoint 32).set! 31
              ((encodeLittleEndian x25519Params.basePoint 32).get! 31 &&& 127)
          else
            encodeLittleEndian x25519Params.basePoint 32))
        x25519Params) 32).size = 32
  simp [encodeLittleEndian, ByteArray.size]

/-- X448 public keys are 56 bytes (RFC 7748 Section 6.2). -/
theorem generatePublicKey448_size (priv : ByteArray) :
    (generatePublicKey448 priv).size = 56 := by
  unfold generatePublicKey448 x448
  change (encodeLittleEndian
      (montgomeryLadder (decodeLittleEndian (clampScalar448 priv))
        (decodeLittleEndian (encodeLittleEndian x448Params.basePoint 56))
        x448Params) 56).size = 56
  simp [encodeLittleEndian, ByteArray.size]

end SWELib.Security.Crypto.Ecdh
