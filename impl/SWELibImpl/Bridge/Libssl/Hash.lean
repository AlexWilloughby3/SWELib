import SWELib

/-!
# Hash Function Bridge Axioms

Behavioral axioms for SHA-2 hash functions and HMAC, asserting that
the FFI implementations satisfy the properties specified in
FIPS 180-4 and RFC 2104.
-/

namespace SWELib.Security

-- TRUST: behavioral axiom, verified against FFI implementation

/-- SHA-256 always produces a 32-byte digest (FIPS 180-4 Section 6.2). -/
axiom sha256Hash_digest_size : ∀ msg, (sha256Hash msg).digest.size = 32

/-- SHA-384 always produces a 48-byte digest (FIPS 180-4 Section 6.5). -/
axiom sha384Hash_digest_size : ∀ msg, (sha384Hash msg).digest.size = 48

/-- SHA-512 always produces a 64-byte digest (FIPS 180-4 Section 6.4). -/
axiom sha512Hash_digest_size : ∀ msg, (sha512Hash msg).digest.size = 64

-- TRUST: behavioral axiom, verified against FFI implementation

/-- SHA-256 output is tagged with the sha256 algorithm. -/
axiom sha256Hash_tag : ∀ msg, (sha256Hash msg).algorithm = .sha256

/-- SHA-384 output is tagged with the sha384 algorithm. -/
axiom sha384Hash_tag : ∀ msg, (sha384Hash msg).algorithm = .sha384

/-- SHA-512 output is tagged with the sha512 algorithm. -/
axiom sha512Hash_tag : ∀ msg, (sha512Hash msg).algorithm = .sha512

-- TRUST: behavioral axiom, verified against FFI implementation

/-- The conditioned key has length equal to the block size (RFC 2104 Section 2). -/
axiom conditionKey_length :
  ∀ alg key, (conditionKey alg key).size = (hashParams alg).blockBytes

/-- HMAC output length equals the digest size of the algorithm (RFC 2104 Section 2). -/
axiom hmac_output_length :
  ∀ alg key msg, (hmac alg key msg).size = (hashParams alg).digestBytes

-- ---------------------------------------------------------------------------
-- Helper for the HMAC construction identity
-- ---------------------------------------------------------------------------

/-- Dispatch to the appropriate hash function for a given algorithm. -/
noncomputable def hashOf (alg : HashAlgorithm) (data : ByteArray) : ByteArray :=
  match alg with
  | .sha1   => (sha1Hash data).digest
  | .sha256 => (sha256Hash data).digest
  | .sha384 => (sha384Hash data).digest
  | .sha512 => (sha512Hash data).digest

-- TRUST: behavioral axiom, verified against FFI implementation

/-- HMAC follows the RFC 2104 construction:
    `HMAC(K, m) = H((K' XOR opad) ++ H((K' XOR ipad) ++ m))`
    where `K'` is the conditioned key. -/
axiom hmac_construction :
  ∀ alg key msg,
    hmac alg key msg =
      hashOf alg
        ((conditionKey alg key).xorWithByte opadByte ++
         hashOf alg
           ((conditionKey alg key).xorWithByte ipadByte ++ msg))

-- ---------------------------------------------------------------------------
-- JWT-specific signature verification axioms
-- ---------------------------------------------------------------------------

/-- RSA signature verification with SHA-256 (RS256).
    Verifies that `signature` is a valid RSASSA-PKCS1-v1_5 signature
    of `message` using RSA public key with modulus `n` and exponent `e`. -/
axiom rsa_sha256_verify : ByteArray → ByteArray → ByteArray → ByteArray → Bool

/-- RSA signature verification with SHA-384 (RS384). -/
axiom rsa_sha384_verify : ByteArray → ByteArray → ByteArray → ByteArray → Bool

/-- RSA signature verification with SHA-512 (RS512). -/
axiom rsa_sha512_verify : ByteArray → ByteArray → ByteArray → ByteArray → Bool

/-- ECDSA signature verification with SHA-256 (ES256).
    Verifies that `signature` is a valid ECDSA signature of `message`
    using EC public key with coordinates `x` and `y` on P-256 curve. -/
axiom ecdsa_sha256_verify : ByteArray → ByteArray → ByteArray → ByteArray → Bool

/-- ECDSA signature verification with SHA-384 (ES384) on P-384 curve. -/
axiom ecdsa_sha384_verify : ByteArray → ByteArray → ByteArray → ByteArray → Bool

/-- ECDSA signature verification with SHA-512 (ES512) on P-521 curve. -/
axiom ecdsa_sha512_verify : ByteArray → ByteArray → ByteArray → ByteArray → Bool

/-- Predicate axiom: formal model of a valid RSASSA-PKCS1-v1_5 signature
    of `message` under RSA public key with modulus `n` and exponent `e`
    (RFC 8017 §8.2.2). This opaque predicate represents the mathematical
    truth condition that `rsa_sha256_verify` must decide. -/
axiom ValidRSASignature (n e message signature : ByteArray) : Prop

/-- Consistency: `rsa_sha256_verify` is sound and complete with respect to
    `ValidRSASignature` — it returns `true` iff the signature is mathematically
    valid under RSASSA-PKCS1-v1_5 with SHA-256.
    TRUST: verified against OpenSSL's EVP_DigestVerify implementation. -/
axiom rsa_verify_consistent :
    ∀ (n e message signature : ByteArray),
      rsa_sha256_verify n e message signature = true ↔ ValidRSASignature n e message signature

/-- Predicate axiom: formal model of a valid ECDSA signature of `message`
    under EC public key with coordinates `(x, y)` on the NIST P-256 curve
    (SEC 1 v2.0 §4.1.4, FIPS 186-4). -/
axiom ValidECDSASignature (x y message signature : ByteArray) : Prop

/-- Consistency: `ecdsa_sha256_verify` is sound and complete with respect to
    `ValidECDSASignature` — it returns `true` iff the signature is a valid
    ECDSA signature under the P-256 curve with SHA-256.
    TRUST: verified against OpenSSL's ECDSA_verify implementation. -/
axiom ecdsa_verify_consistent :
    ∀ (x y message signature : ByteArray),
      ecdsa_sha256_verify x y message signature = true ↔ ValidECDSASignature x y message signature

/-- Theorem: RSA verification fails on modified messages. -/
axiom rsa_verify_fails_on_tampered : ∀ n e message signature modifiedMessage,
    message ≠ modifiedMessage →
    rsa_sha256_verify n e message signature = true →
    rsa_sha256_verify n e modifiedMessage signature = false

/-- Theorem: ECDSA verification fails on modified messages. -/
axiom ecdsa_verify_fails_on_tampered : ∀ x y message signature modifiedMessage,
    message ≠ modifiedMessage →
    ecdsa_sha256_verify x y message signature = true →
    ecdsa_sha256_verify x y modifiedMessage signature = false

end SWELib.Security
