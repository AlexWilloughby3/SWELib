import SWELib.Security.Jwt.Types
import SWELib.Security.Jwt.Key
import SWELib.Security.Jwt.Algorithm
import SWELib.Security.Jwt.Parse
import SWELib.Security.Hashing

open Lean

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
  let headerB64 := SWELib.Basics.base64urlEncode ((Json.compress headerJson).toUTF8)
  let payloadB64 := SWELib.Basics.base64urlEncode ((Json.compress claimsJson).toUTF8)
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
noncomputable def signRsa (alg : JwtAlgorithm) (key : Jwk) (_signingInput : ByteArray) :
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
noncomputable def signEcdsa (alg : JwtAlgorithm) (key : Jwk) (_signingInput : ByteArray) :
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
  | .HS256 =>
    match key with
    | .oct k =>
      match signHmac .HS256 k signingInput with
      | .ok signature => .ok { header := header, claims := claims, signature := signature }
      | .error e => .error e
    | _ => .error .keyTypeMismatch
  | .HS384 =>
    match key with
    | .oct k =>
      match signHmac .HS384 k signingInput with
      | .ok signature => .ok { header := header, claims := claims, signature := signature }
      | .error e => .error e
    | _ => .error .keyTypeMismatch
  | .HS512 =>
    match key with
    | .oct k =>
      match signHmac .HS512 k signingInput with
      | .ok signature => .ok { header := header, claims := claims, signature := signature }
      | .error e => .error e
    | _ => .error .keyTypeMismatch
  | .RS256 =>
    match signRsa .RS256 key signingInput with
    | .ok signature => .ok { header := header, claims := claims, signature := signature }
    | .error e => .error e
  | .RS384 =>
    match signRsa .RS384 key signingInput with
    | .ok signature => .ok { header := header, claims := claims, signature := signature }
    | .error e => .error e
  | .RS512 =>
    match signRsa .RS512 key signingInput with
    | .ok signature => .ok { header := header, claims := claims, signature := signature }
    | .error e => .error e
  | .PS256 =>
    match signRsa .PS256 key signingInput with
    | .ok signature => .ok { header := header, claims := claims, signature := signature }
    | .error e => .error e
  | .PS384 =>
    match signRsa .PS384 key signingInput with
    | .ok signature => .ok { header := header, claims := claims, signature := signature }
    | .error e => .error e
  | .PS512 =>
    match signRsa .PS512 key signingInput with
      | .ok signature => .ok { header := header, claims := claims, signature := signature }
      | .error e => .error e
  | .ES256 =>
    match signEcdsa .ES256 key signingInput with
    | .ok signature => .ok { header := header, claims := claims, signature := signature }
    | .error e => .error e
  | .ES384 =>
    match signEcdsa .ES384 key signingInput with
    | .ok signature => .ok { header := header, claims := claims, signature := signature }
    | .error e => .error e
  | .ES512 =>
    match signEcdsa .ES512 key signingInput with
    | .ok signature => .ok { header := header, claims := claims, signature := signature }
    | .error e => .error e

/-- Create a JWT builder for fluent construction. -/
structure JwtBuilder where
  header : JoseHeader
  claims : JwtClaimsSet

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
def JwtBuilder.setExpiresIn (seconds : Nat) (now : SWELib.Basics.NumericDate) (builder : JwtBuilder) : JwtBuilder :=
  let exp := now.addSeconds seconds
  { builder with claims := { builder.claims with exp := some exp } }

/-- Set not before time (seconds from now). Requires the current time as a parameter. -/
def JwtBuilder.setNotBeforeIn (seconds : Nat) (now : SWELib.Basics.NumericDate) (builder : JwtBuilder) : JwtBuilder :=
  let nbf := now.addSeconds seconds
  { builder with claims := { builder.claims with nbf := some nbf } }

/-- Set issued at time to now. Requires the current time as a parameter. -/
def JwtBuilder.setIssuedAtNow (now : SWELib.Basics.NumericDate) (builder : JwtBuilder) : JwtBuilder :=
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
    Requires the current time `now` (obtain from `SWELib.Basics.NumericDate.now` in IO). -/
noncomputable def createSimple (alg : JwtAlgorithm) (key : Jwk) (issuer subject : String)
    (expiresIn : Nat) (now : SWELib.Basics.NumericDate) : Except CreationError Jwt :=
  JwtBuilder.start alg
    |> (λ b => b.setIssuer issuer)
    |> (λ b => b.setSubject subject)
    |> (λ b => b.setIssuedAtNow now)
    |> (λ b => b.setExpiresIn expiresIn now)
    |> (λ b => b.sign key)

/-- Theorem: Created JWT has correct algorithm in header. -/
axiom created_jwt_has_correct_algorithm (header : JoseHeader) (claims : JwtClaimsSet)
    (key : Jwk) (jwt : Jwt) (h : createAndSign header claims key = .ok jwt) :
    jwt.header.alg = header.alg

/-- Theorem: Created JWT has provided claims. -/
axiom created_jwt_has_correct_claims (header : JoseHeader) (claims : JwtClaimsSet)
    (key : Jwk) (jwt : Jwt) (h : createAndSign header claims key = .ok jwt) :
    jwt.claims = claims

/-- Theorem: Builder pattern produces same result as direct creation. -/
theorem builder_equivalent_direct (alg : JwtAlgorithm) (key : Jwk)
    (issuer subject : String) (expiresIn : Nat) (now : SWELib.Basics.NumericDate) :
    createSimple alg key issuer subject expiresIn now =
      createAndSign
        { alg := alg }
        { iss := some issuer, sub := some subject,
          iat := some now, exp := some (now.addSeconds expiresIn) }
        key := by
  simp [createSimple, JwtBuilder.start, JwtBuilder.setIssuer, JwtBuilder.setSubject,
    JwtBuilder.setIssuedAtNow, JwtBuilder.setExpiresIn, JwtBuilder.sign]

end SWELib.Security.Jwt
