import SWELib.Security.Jwt.Types
import SWELib.Security.Jwt.Key
import SWELib.Security.Jwt.Algorithm
import SWELib.Security.Jwt.Parse
import SWELib.Security.Hashing

namespace SWELib.Security.Jwt

/-- Errors that can occur during JWT creation. -/
inductive CreationError where
  | unsupportedAlgorithm
  | keyTypeMismatch
  | invalidKeySize
  | signingFailed
  deriving DecidableEq, Repr

/-- Create the signing input for a JWT (header.payload). -/
def createSigningInput (header : JoseHeader) (claims : JwtClaimsSet) : ByteArray :=
  let headerJson := serializeJoseHeader header
  let claimsJson := serializeClaimsSet claims
  let headerB64 := base64urlEncode (headerJson.toString.toUTF8)
  let payloadB64 := base64urlEncode (claimsJson.toString.toUTF8)
  (s!"{headerB64}.{payloadB64}").toUTF8

/-- Sign a JWT with HMAC (RFC 7518 Section 3.2). -/
noncomputable def signHmac (alg : JwtAlgorithm) (key : ByteArray) (signingInput : ByteArray) :
    Except CreationError ByteArray :=
  match alg.toHashAlgorithm with
  | some hashAlg =>
    let hmacKey : HmacKey := ⟨key⟩
    -- TODO: Use bridge hmac function
    let signature := hmac hashAlg hmacKey signingInput
    .ok signature
  | none => .error .unsupportedAlgorithm

/-- Sign a JWT with RSA (RFC 7518 Section 3.3). -/
noncomputable def signRsa (alg : JwtAlgorithm) (key : Jwk) (signingInput : ByteArray) :
    Except CreationError ByteArray :=
  match key with
  | .rsa _ _ (some _) =>
    if key.supportsAlgorithm alg then
      -- Placeholder: RSA signing requires bridge axioms (FFI to crypto library)
      .error .signingFailed
    else
      .error .keyTypeMismatch
  | _ => .error .keyTypeMismatch

/-- Sign a JWT with ECDSA (RFC 7518 Section 3.4). -/
noncomputable def signEcdsa (alg : JwtAlgorithm) (key : Jwk) (signingInput : ByteArray) :
    Except CreationError ByteArray :=
  match key with
  | .ec _ _ (some _) =>
    if key.supportsAlgorithm alg then
      -- Placeholder: ECDSA signing requires bridge axioms (FFI to crypto library)
      .error .signingFailed
    else
      .error .keyTypeMismatch
  | _ => .error .keyTypeMismatch

/-- Create and sign a JWT. -/
noncomputable def createAndSign (header : JoseHeader) (claims : JwtClaimsSet) (key : Jwk) :
    Except CreationError Jwt :=
  let signingInput := createSigningInput header claims
  match header.alg with
  | .none =>
    .ok { header := header, claims := claims, signature := ByteArray.empty }
  | alg@(.HS256 | .HS384 | .HS512) =>
    match key with
    | .oct k =>
      match signHmac alg k signingInput with
      | .ok signature => .ok { header := header, claims := claims, signature := signature }
      | .error e => .error e
    | _ => .error .keyTypeMismatch
  | alg@(.RS256 | .RS384 | .RS512 | .PS256 | .PS384 | .PS512) =>
    match signRsa alg key signingInput with
    | .ok signature => .ok { header := header, claims := claims, signature := signature }
    | .error e => .error e
  | alg@(.ES256 | .ES384 | .ES512) =>
    match signEcdsa alg key signingInput with
    | .ok signature => .ok { header := header, claims := claims, signature := signature }
    | .error e => .error e

/-- Create a JWT builder for fluent construction. -/
structure JwtBuilder where
  header : JoseHeader
  claims : JwtClaimsSet
  deriving DecidableEq, Repr

/-- Start building a JWT with given algorithm. -/
def JwtBuilder.start (alg : JwtAlgorithm) : JwtBuilder :=
  { header := { alg := alg }, claims := {} }

/-- Set issuer claim. -/
def JwtBuilder.setIssuer (issuer : String) (builder : JwtBuilder) : JwtBuilder :=
  { builder with claims := { builder.claims with iss := some issuer } }

/-- Set subject claim. -/
def JwtBuilder.setSubject (subject : String) (builder : JwtBuilder) : JwtBuilder :=
  { builder with claims := { builder.claims with sub := some subject } }

/-- Set audience claim. -/
def JwtBuilder.setAudience (audience : String) (builder : JwtBuilder) : JwtBuilder :=
  { builder with claims := { builder.claims with aud := some [audience] } }

/-- Set expiration time (seconds from now). Requires the current time as a parameter. -/
def JwtBuilder.setExpiresIn (seconds : Nat) (now : NumericDate) (builder : JwtBuilder) : JwtBuilder :=
  let exp := now.addSeconds seconds
  { builder with claims := { builder.claims with exp := some exp } }

/-- Set not before time (seconds from now). Requires the current time as a parameter. -/
def JwtBuilder.setNotBeforeIn (seconds : Nat) (now : NumericDate) (builder : JwtBuilder) : JwtBuilder :=
  let nbf := now.addSeconds seconds
  { builder with claims := { builder.claims with nbf := some nbf } }

/-- Set issued at time to now. Requires the current time as a parameter. -/
def JwtBuilder.setIssuedAtNow (now : NumericDate) (builder : JwtBuilder) : JwtBuilder :=
  { builder with claims := { builder.claims with iat := some now } }

/-- Set JWT ID. -/
def JwtBuilder.setJwtId (jti : String) (builder : JwtBuilder) : JwtBuilder :=
  { builder with claims := { builder.claims with jti := some jti } }

/-- Add custom claim. -/
def JwtBuilder.addCustomClaim (key : String) (value : Json) (builder : JwtBuilder) : JwtBuilder :=
  { builder with claims :=
      { builder.claims with custom := builder.claims.custom.insert key value } }

/-- Set key ID in header. -/
def JwtBuilder.setKeyId (kid : String) (builder : JwtBuilder) : JwtBuilder :=
  { builder with header := { builder.header with kid := some kid } }

/-- Set content type in header. -/
def JwtBuilder.setContentType (cty : String) (builder : JwtBuilder) : JwtBuilder :=
  { builder with header := { builder.header with cty := some cty } }

/-- Finalize and sign the JWT. -/
noncomputable def JwtBuilder.sign (builder : JwtBuilder) (key : Jwk) :
    Except CreationError Jwt :=
  createAndSign builder.header builder.claims key

/-- Create a simple JWT with minimal claims.
    Requires the current time `now` (obtain from `NumericDate.now` in IO). -/
noncomputable def createSimple (alg : JwtAlgorithm) (key : Jwk) (issuer subject : String)
    (expiresIn : Nat) (now : NumericDate) : Except CreationError Jwt :=
  JwtBuilder.start alg
    |> (λ b => b.setIssuer issuer)
    |> (λ b => b.setSubject subject)
    |> (λ b => b.setIssuedAtNow now)
    |> (λ b => b.setExpiresIn expiresIn now)
    |> (λ b => b.sign key)

/-- Theorem: Created JWT has correct algorithm in header. -/
theorem created_jwt_has_correct_algorithm (header : JoseHeader) (claims : JwtClaimsSet)
    (key : Jwk) (jwt : Jwt) (h : createAndSign header claims key = .ok jwt) :
    jwt.header.alg = header.alg := by
  simp only [createAndSign] at h
  split at h <;> simp_all

/-- Theorem: Created JWT has provided claims. -/
theorem created_jwt_has_correct_claims (header : JoseHeader) (claims : JwtClaimsSet)
    (key : Jwk) (jwt : Jwt) (h : createAndSign header claims key = .ok jwt) :
    jwt.claims = claims := by
  simp only [createAndSign] at h
  split at h <;> simp_all

/-- Theorem: Builder pattern produces same result as direct creation. -/
theorem builder_equivalent_direct (alg : JwtAlgorithm) (key : Jwk)
    (issuer subject : String) (expiresIn : Nat) (now : NumericDate) :
    createSimple alg key issuer subject expiresIn now =
      createAndSign
        { alg := alg }
        { iss := some issuer, sub := some subject,
          iat := some now, exp := some (now.addSeconds expiresIn) }
        key := by
  simp only [createSimple, JwtBuilder.start, JwtBuilder.setIssuer, JwtBuilder.setSubject,
    JwtBuilder.setIssuedAtNow, JwtBuilder.setExpiresIn, JwtBuilder.sign, createAndSign]

end SWELib.Security.Jwt
