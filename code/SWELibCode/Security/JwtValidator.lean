/-!
# JWT Validator Implementation

Executable JWT validation implementation using FFI bindings.
Provides @[extern] functions for Base64url, HMAC, RSA, and ECDSA operations.

## References
- RFC 7519: JSON Web Token (JWT)
- RFC 7515: JSON Web Signature (JWS)
- RFC 7518: JSON Web Algorithms (JWA)
-/

import SWELib
import SWELibBridge

namespace SWELibCode.Security

open SWELib.Security.Jwt
open SWELib.Basics

/-- @[extern] binding for Base64url encoding. -/
@[extern "swelib_base64url_encode"]
opaque base64urlEncodeImpl (data : @& ByteArray) : String

/-- @[extern] binding for Base64url decoding. -/
@[extern "swelib_base64url_decode"]
opaque base64urlDecodeImpl (s : @& String) : Option ByteArray

/-- @[extern] binding for HMAC computation. -/
@[extern "swelib_hmac"]
opaque hmacImpl (alg : @& HashAlgorithm) (key : @& HmacKey) (msg : @& ByteArray) : ByteArray

/-- @[extern] binding for RSA SHA-256 verification. -/
@[extern "swelib_rsa_sha256_verify"]
opaque rsaSha256VerifyImpl (n : @& ByteArray) (e : @& ByteArray) (msg : @& ByteArray)
  (sig : @& ByteArray) : Bool

/-- @[extern] binding for ECDSA SHA-256 verification. -/
@[extern "swelib_ecdsa_sha256_verify"]
opaque ecdsaSha256VerifyImpl (x : @& ByteArray) (y : @& ByteArray) (msg : @& ByteArray)
  (sig : @& ByteArray) : Bool

/-- Implementation of Base64url encoding. -/
def base64urlEncode' (data : ByteArray) : String :=
  base64urlEncodeImpl data

/-- Implementation of Base64url decoding. -/
def base64urlDecode' (s : String) : Option ByteArray :=
  base64urlDecodeImpl s

/-- Implementation of HMAC. -/
def hmac' (alg : HashAlgorithm) (key : HmacKey) (msg : ByteArray) : ByteArray :=
  hmacImpl alg key msg

/-- Verify RSA SHA-256 signature. -/
def verifyRsaSha256 (n e msg sig : ByteArray) : Bool :=
  rsaSha256VerifyImpl n e msg sig

/-- Verify ECDSA SHA-256 signature. -/
def verifyEcdsaSha256 (x y msg sig : ByteArray) : Bool :=
  ecdsaSha256VerifyImpl x y msg sig

/-- Parse and validate a JWT token. -/
noncomputable def validateToken (token : String) (key : Jwk) (config : ValidationConfig) :
    Except ValidationError Unit :=
  match parseCompact token with
  | .error _ => .error (.signature .invalidFormat)
  | .ok jwt => validate jwt key config

/-- Create a signed JWT token. -/
noncomputable def createToken (header : JoseHeader) (claims : JwtClaimsSet) (key : Jwk) :
    Except CreationError String :=
  match createAndSign header claims key with
  | .error e => .error e
  | .ok jwt => .ok (serializeCompact jwt)

/-- Quick validation: parse and check signature only. -/
noncomputable def quickValidate (token : String) (key : Jwk) : Except SignatureError Unit :=
  match parseCompact token with
  | .error _ => .error .invalidFormat
  | .ok jwt => verifySignature jwt key

/-- Check if token is expired (without full validation). -/
noncomputable def isTokenExpired (token : String) (clockSkew : Nat := 60) : Option Bool :=
  match parseCompact token with
  | .ok jwt => some (isExpired jwt clockSkew)
  | .error _ => none

/-- Get claims from token without validation. -/
def getClaimsUnsafe (token : String) : Option JwtClaimsSet :=
  match parseCompact token with
  | .ok jwt => some jwt.claims
  | .error _ => none

/-- Get algorithm from token without validation. -/
def getAlgorithmUnsafe (token : String) : Option JwtAlgorithm :=
  match parseCompact token with
  | .ok jwt => some jwt.header.alg
  | .error _ => none

/-- Create a simple JWT token with common claims. -/
noncomputable def createSimpleToken (alg : JwtAlgorithm) (key : Jwk) (issuer subject : String)
    (expiresIn : Nat) : Except CreationError String :=
  match createSimple alg key issuer subject expiresIn with
  | .error e => .error e
  | .ok jwt => .ok (serializeCompact jwt)

end SWELibCode.Security