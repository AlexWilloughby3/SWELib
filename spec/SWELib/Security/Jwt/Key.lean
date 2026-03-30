import SWELib.Security.Jwt.Algorithm

namespace SWELib.Security.Jwt

/-- Key type identifiers (RFC 7517 Section 4.1). -/
inductive KeyType where
  | ec   -- Elliptic Curve
  | rsa  -- RSA
  | oct  -- Octet sequence (symmetric)
  deriving DecidableEq, Repr

/-- JSON Web Key (JWK) structure (RFC 7517 Section 4).
    Minimal representation for HS256, RS256, and ES256 support. -/
inductive Jwk where
  /-- Octet sequence key for symmetric algorithms (RFC 7518 Section 6.4) -/
  | oct (k : ByteArray)
  /-- RSA key (RFC 7518 Section 6.3)
      - `n`: RSA modulus
      - `e`: RSA public exponent
      - `d`: Optional RSA private exponent -/
  | rsa (n e : ByteArray) (d : Option ByteArray := none)
  /-- Elliptic Curve key (RFC 7518 Section 6.2)
      - `x`: x-coordinate
      - `y`: y-coordinate
      - `d`: Optional private key -/
  | ec (x y : ByteArray) (d : Option ByteArray := none)
  deriving DecidableEq

/-- Get the key type of a JWK. -/
def Jwk.keyType : Jwk → KeyType
  | .oct _ => .oct
  | .rsa .. => .rsa
  | .ec .. => .ec

/-- Check if a JWK contains a private key. -/
def Jwk.hasPrivateKey : Jwk → Bool
  | .oct _ => true  -- Symmetric keys are always "private"
  | .rsa _ _ d => d.isSome
  | .ec _ _ d => d.isSome

/-- Get the public key portion of a JWK (for verification). -/
def Jwk.publicKey : Jwk → Option Jwk
  | .oct k => some (.oct k)  -- Symmetric keys are the same for verification
  | .rsa n e _ => some (.rsa n e none)
  | .ec x y _ => some (.ec x y none)

/-- Minimum key size requirements (in bytes) for security.
    Based on NIST recommendations and RFC 7518. -/
def minKeySize : KeyType → Nat
  | .oct => 32   -- 256 bits for HS256
  | .rsa => 256  -- 2048 bits for RS256
  | .ec => 32    -- 256 bits for ES256 (P-256 curve)

/-- Check if a JWK meets minimum size requirements. -/
def Jwk.hasMinimumSize : Jwk → Bool
  | .oct k => k.size ≥ minKeySize .oct
  | .rsa n _ _ => n.size ≥ minKeySize .rsa
  | .ec x _ _ => x.size ≥ minKeySize .ec

/-- Supported algorithms for each key type (RFC 7518). -/
def supportedAlgorithms : KeyType → List JwtAlgorithm
  | .oct => [.HS256, .HS384, .HS512]
  | .rsa => [.RS256, .RS384, .RS512, .PS256, .PS384, .PS512]
  | .ec  => [.ES256, .ES384, .ES512]

/-- Check if a key supports a given algorithm. -/
def Jwk.supportsAlgorithm (key : Jwk) (alg : JwtAlgorithm) : Bool :=
  (supportedAlgorithms key.keyType).contains alg

/-- Theorem: Public key derivation preserves key type. -/
theorem Jwk.publicKey_keyType (key : Jwk) :
    ∀ pk, key.publicKey = some pk → pk.keyType = key.keyType := by
  cases key <;> simp [Jwk.publicKey, Jwk.keyType]

-- NOTE: Symmetric keys (oct) have hasPrivateKey = true even as "public" keys,
-- since symmetric keys don't have a public/private distinction.
-- This theorem only holds for asymmetric key types.
/-- Theorem: Public key (for asymmetric keys) has no private component. -/
theorem Jwk.publicKey_no_private (key : Jwk) (h : key.keyType ≠ .oct) :
    ∀ pk, key.publicKey = some pk → ¬pk.hasPrivateKey := by
  cases key <;> simp_all [Jwk.publicKey, Jwk.hasPrivateKey, Jwk.keyType]

/-- Create a symmetric key from a byte array. -/
def Jwk.symmetric (key : ByteArray) : Jwk :=
  .oct key

/-- Create an RSA public key. -/
def Jwk.rsaPublic (modulus exponent : ByteArray) : Jwk :=
  .rsa modulus exponent none

/-- Create an RSA private key. -/
def Jwk.rsaPrivate (modulus exponent privateExponent : ByteArray) : Jwk :=
  .rsa modulus exponent (some privateExponent)

/-- Create an EC public key. -/
def Jwk.ecPublic (x y : ByteArray) : Jwk :=
  .ec x y none

/-- Create an EC private key. -/
def Jwk.ecPrivate (x y privateKey : ByteArray) : Jwk :=
  .ec x y (some privateKey)

end SWELib.Security.Jwt
