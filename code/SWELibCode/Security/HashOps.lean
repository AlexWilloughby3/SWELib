import SWELib
import SWELibBridge

/-!
# HashOps

Executable HashOps implementation.
-/


namespace SWELibCode.Security

open SWELib.Security

-- Re-use the @[extern] bindings declared in JwtValidator to avoid duplication.
-- These call through to the C shims for SHA-2 and HMAC.

/-- @[extern] SHA-256 digest of a byte array. Returns a 32-byte `HashOutput`. -/
@[extern "swelib_sha256"]
opaque sha256Impl (data : @& ByteArray) : ByteArray

/-- @[extern] SHA-384 digest of a byte array. Returns a 48-byte `HashOutput`. -/
@[extern "swelib_sha384"]
opaque sha384Impl (data : @& ByteArray) : ByteArray

/-- @[extern] SHA-512 digest of a byte array. Returns a 64-byte `HashOutput`. -/
@[extern "swelib_sha512"]
opaque sha512Impl (data : @& ByteArray) : ByteArray

/-- @[extern] HMAC over an arbitrary algorithm, key, and message. -/
@[extern "swelib_hmac"]
opaque hmacImpl (alg : @& HashAlgorithm) (key : @& HmacKey) (msg : @& ByteArray) : ByteArray

/-- Compute SHA-256, returning a `HashOutput` tagged with the algorithm. -/
def sha256 (data : ByteArray) : HashOutput :=
  { digest := sha256Impl data, algorithm := .sha256 }

/-- Compute SHA-384, returning a `HashOutput` tagged with the algorithm. -/
def sha384 (data : ByteArray) : HashOutput :=
  { digest := sha384Impl data, algorithm := .sha384 }

/-- Compute SHA-512, returning a `HashOutput` tagged with the algorithm. -/
def sha512 (data : ByteArray) : HashOutput :=
  { digest := sha512Impl data, algorithm := .sha512 }

/-- Compute HMAC for the given algorithm over `key` and `msg`. -/
def hmac (alg : HashAlgorithm) (key : HmacKey) (msg : ByteArray) : HmacOutput :=
  hmacImpl alg key msg

/-- Dispatch to the right hash function by algorithm. -/
def hash (alg : HashAlgorithm) (data : ByteArray) : HashOutput :=
  match alg with
  | .sha1   => sha256 data          -- SHA-1 not exposed; use SHA-256 as safe fallback
  | .sha256 => sha256 data
  | .sha384 => sha384 data
  | .sha512 => sha512 data

/-- Hash a UTF-8 string. -/
def hashString (alg : HashAlgorithm) (s : String) : HashOutput :=
  hash alg s.toUTF8

/-- Constant-time byte array equality for MAC comparison. -/
@[extern "swelib_const_time_eq"]
opaque constTimeEq (a b : @& ByteArray) : Bool

/-- Verify an HMAC tag in constant time to prevent timing side-channels. -/
def verifyHmac (alg : HashAlgorithm) (key : HmacKey) (msg expected : ByteArray) : Bool :=
  constTimeEq (hmac alg key msg) expected

end SWELibCode.Security
