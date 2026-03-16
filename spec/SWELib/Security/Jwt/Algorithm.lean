import SWELib.Security.Hashing

namespace SWELib.Security.Jwt

/-- JWT algorithm identifiers (RFC 7518 Section 3).
    Separate type from HashAlgorithm to maintain JWT-specific semantics. -/
inductive JwtAlgorithm where
  | none  -- Unsecured JWT (RFC 7518 Section 3.6)
  | HS256 | HS384 | HS512  -- HMAC SHA (RFC 7518 Section 3.2)
  | RS256 | RS384 | RS512  -- RSASSA-PKCS1-v1_5 (RFC 7518 Section 3.3)
  | ES256 | ES384 | ES512  -- ECDSA (RFC 7518 Section 3.4)
  | PS256 | PS384 | PS512  -- RSASSA-PSS (RFC 7518 Section 3.5)
  deriving DecidableEq, Repr

/-- Convert JWT algorithm to string representation (RFC 7518 Section 3.1). -/
def JwtAlgorithm.toString : JwtAlgorithm → String
  | .none => "none"
  | .HS256 => "HS256"
  | .HS384 => "HS384"
  | .HS512 => "HS512"
  | .RS256 => "RS256"
  | .RS384 => "RS384"
  | .RS512 => "RS512"
  | .ES256 => "ES256"
  | .ES384 => "ES384"
  | .ES512 => "ES512"
  | .PS256 => "PS256"
  | .PS384 => "PS384"
  | .PS512 => "PS512"

instance : ToString JwtAlgorithm where
  toString := JwtAlgorithm.toString

/-- Parse algorithm from string (inverse of toString). -/
def JwtAlgorithm.fromString (s : String) : Option JwtAlgorithm :=
  match s with
  | "none" => some .none
  | "HS256" => some .HS256
  | "HS384" => some .HS384
  | "HS512" => some .HS512
  | "RS256" => some .RS256
  | "RS384" => some .RS384
  | "RS512" => some .RS512
  | "ES256" => some .ES256
  | "ES384" => some .ES384
  | "ES512" => some .ES512
  | "PS256" => some .PS256
  | "PS384" => some .PS384
  | "PS512" => some .PS512
  | _ => none

/-- Theorem: `toString` and `fromString` form a roundtrip. -/
theorem JwtAlgorithm.toString_fromString (alg : JwtAlgorithm) :
    JwtAlgorithm.fromString (toString alg) = some alg := by
  cases alg <;> rfl

/-- Theorem: `fromString` then `toString` returns original for valid strings. -/
theorem JwtAlgorithm.fromString_toString (s : String) (alg : JwtAlgorithm)
    (h : JwtAlgorithm.fromString s = some alg) :
    toString alg = s := by
  simp only [JwtAlgorithm.fromString] at h
  split at h <;> simp_all [JwtAlgorithm.toString]

/-- Check if algorithm requires a key. -/
def JwtAlgorithm.requiresKey : JwtAlgorithm → Bool
  | .none => false
  | _ => true

/-- Check if algorithm is asymmetric (requires public/private key pair). -/
def JwtAlgorithm.isAsymmetric : JwtAlgorithm → Bool
  | .none => false
  | .HS256 | .HS384 | .HS512 => false
  | _ => true

/-- Check if algorithm is symmetric (uses shared secret). -/
def JwtAlgorithm.isSymmetric : JwtAlgorithm → Bool
  | .HS256 | .HS384 | .HS512 => true
  | _ => false

/-- Map JWT algorithm to corresponding HashAlgorithm for HMAC operations. -/
def JwtAlgorithm.toHashAlgorithm : JwtAlgorithm → Option HashAlgorithm
  | .HS256 => some .sha256
  | .HS384 => some .sha384
  | .HS512 => some .sha512
  | .RS256 => some .sha256
  | .RS384 => some .sha384
  | .RS512 => some .sha512
  | .ES256 => some .sha256
  | .ES384 => some .sha384
  | .ES512 => some .sha512
  | .PS256 => some .sha256
  | .PS384 => some .sha384
  | .PS512 => some .sha512
  | .none => Option.none

/-- Theorem: Symmetric algorithms have corresponding HashAlgorithm. -/
theorem JwtAlgorithm.symmetric_has_hash (alg : JwtAlgorithm) (h : alg.isSymmetric) :
    alg.toHashAlgorithm ≠ Option.none := by
  cases alg <;> simp [JwtAlgorithm.isSymmetric] at h <;> simp [JwtAlgorithm.toHashAlgorithm]

/-- Minimum key size in bits for each algorithm (NIST recommendations). -/
def JwtAlgorithm.minKeySizeBits : JwtAlgorithm → Nat
  | .HS256 => 256
  | .HS384 => 384
  | .HS512 => 512
  | .RS256 => 2048
  | .RS384 => 3072
  | .RS512 => 4096
  | .ES256 => 256
  | .ES384 => 384
  | .ES512 => 521  -- P-521 curve uses 521 bits
  | .PS256 => 2048
  | .PS384 => 3072
  | .PS512 => 4096
  | .none => 0

/-- Check if algorithm is considered secure by current standards. -/
def JwtAlgorithm.isSecure : JwtAlgorithm → Bool
  | .none => false  -- Unsecured JWTs are not secure
  | .HS256 | .HS384 | .HS512 => true
  | .RS256 | .RS384 | .RS512 => true
  | .ES256 | .ES384 | .ES512 => true
  | .PS256 | .PS384 | .PS512 => true

/-- Recommended algorithms in order of preference (most secure first). -/
def recommendedAlgorithms : List JwtAlgorithm :=
  [.ES512, .ES384, .ES256,  -- ECDSA is generally preferred
   .PS512, .PS384, .PS256,  -- RSASSA-PSS is better than PKCS1-v1_5
   .RS512, .RS384, .RS256,
   .HS512, .HS384, .HS256]

end SWELib.Security.Jwt
