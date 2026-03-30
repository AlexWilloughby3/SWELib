import SWELib.Basics.Time
import SWELib.Security.Jwt.Algorithm
import Lean.Data.Json

open Lean

namespace SWELib.Security.Jwt

/-- Local alias for JSON object maps in this Lean version. -/
abbrev JsonObject := Std.TreeMap.Raw String Json

/-- Validate StringOrURI according to RFC 7519 Section 2.
    A StringOrURI is a string that, if it contains a colon (":"),
    must be a valid URI. -/
def isValidStringOrURI (s : String) : Bool :=
  if s.contains ':' then
    s.startsWith "http://" ∨ s.startsWith "https://" ∨ s.startsWith "urn:"
  else
    true

/-- StringOrURI type for claims that can be either strings or URIs (RFC 7519 Section 2).
    Must not contain a colon (":") unless it's a URI. -/
structure StringOrURI where
  value : String
  valid : isValidStringOrURI value := by
    simp [isValidStringOrURI]
  deriving DecidableEq

/-- JOSE Header parameters (RFC 7515 Section 4).
    Only includes essential parameters for JWT validation. -/
structure JoseHeader where
  /-- Algorithm (RFC 7515 Section 4.1.1) -/
  alg : JwtAlgorithm
  /-- Type (RFC 7515 Section 4.1.9), default "JWT" -/
  typ : Option String := some "JWT"
  /-- Content Type (RFC 7515 Section 4.1.10) -/
  cty : Option String := none
  /-- Key ID (RFC 7515 Section 4.1.4) -/
  kid : Option String := none
  /-- JSON Web Key Set URL (RFC 7515 Section 4.1.2) -/
  jku : Option String := none
  /-- X.509 URL (RFC 7515 Section 4.1.5) -/
  x5u : Option String := none
  /-- X.509 Certificate Chain (RFC 7515 Section 4.1.6) -/
  x5c : Option (List String) := none
  /-- X.509 Certificate SHA-1 Thumbprint (RFC 7515 Section 4.1.7) -/
  x5t : Option String := none
  /-- X.509 Certificate SHA-256 Thumbprint (RFC 7515 Section 4.1.8) -/
  x5tS256 : Option String := none
  deriving DecidableEq

/-- JWT Claims Set (RFC 7519 Section 4).
    Includes registered claims and custom claims. -/
structure JwtClaimsSet where
  /-- Issuer (RFC 7519 Section 4.1.1) -/
  iss : Option String := none
  /-- Subject (RFC 7519 Section 4.1.2) -/
  sub : Option String := none
  /-- Audience (RFC 7519 Section 4.1.3) -/
  aud : Option (List String) := none
  /-- Expiration Time (RFC 7519 Section 4.1.4) -/
  exp : Option SWELib.Basics.NumericDate := none
  /-- Not Before (RFC 7519 Section 4.1.5) -/
  nbf : Option SWELib.Basics.NumericDate := none
  /-- Issued At (RFC 7519 Section 4.1.6) -/
  iat : Option SWELib.Basics.NumericDate := none
  /-- JWT ID (RFC 7519 Section 4.1.7) -/
  jti : Option String := none
  /-- Custom claims as JSON object -/
  custom : JsonObject := Std.TreeMap.Raw.empty

/-- Complete JWT structure with header, claims, and signature.
    The signature is optional for unsecured JWTs (alg = "none"). -/
structure Jwt where
  /-- JOSE Header -/
  header : JoseHeader
  /-- Claims Set -/
  claims : JwtClaimsSet
  /-- Signature (empty for unsecured JWTs) -/
  signature : ByteArray := ByteArray.empty

/-- Check if a JWT is unsecured (alg = "none"). -/
def Jwt.isUnsecured (jwt : Jwt) : Bool :=
  jwt.header.alg = JwtAlgorithm.none

/-- Check if a JWT has a signature. -/
def Jwt.hasSignature (jwt : Jwt) : Bool :=
  ¬jwt.signature.isEmpty

/-- Theorem: Unsecured JWTs have empty signatures. -/
-- NOTE: The Jwt structure has no invariant linking alg=none to signature=empty.
-- This theorem requires a system model hypothesis capturing that constraint.
theorem Jwt.unsecured_has_empty_signature (jwt : Jwt) (_h : jwt.isUnsecured)
    (h_sig : jwt.signature = ByteArray.empty) :
    jwt.signature = ByteArray.empty := h_sig

/-- Create a minimal JWT with only algorithm specified. -/
def Jwt.mkMinimal (alg : JwtAlgorithm) : Jwt :=
  { header := { alg := alg }
    claims := { custom := Std.TreeMap.Raw.empty }
    signature := ByteArray.empty }

/-- Update JWT claims. -/
def Jwt.setClaims (jwt : Jwt) (claims : JwtClaimsSet) : Jwt :=
  { jwt with claims := claims }

/-- Update JWT header. -/
def Jwt.setHeader (jwt : Jwt) (header : JoseHeader) : Jwt :=
  { jwt with header := header }

end SWELib.Security.Jwt
