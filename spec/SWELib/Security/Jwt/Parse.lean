import SWELib.Basics.Base64url
import SWELib.Security.Jwt.Types
import SWELib.Security.Jwt.Algorithm
import Lean.Data.Json

namespace SWELib.Security.Jwt

/-- Error types for parsing operations. -/
inductive ParseError where
  | invalidFormat
  | invalidBase64url
  | invalidJson
  | missingAlgorithm
  | unsupportedAlgorithm
  | invalidStringOrURI
  deriving DecidableEq, Repr

/-- Parse a JWT from its compact serialization (dot-separated string). -/
def parseCompact (token : String) : Except ParseError Jwt :=
  let parts := token.split (· = '.')
  match parts with
  | [headerB64, payloadB64, signatureB64] =>
    match base64urlDecode headerB64, base64urlDecode payloadB64, base64urlDecode signatureB64 with
    | some headerBytes, some payloadBytes, some signatureBytes =>
      match Json.parse (String.fromUTF8Unchecked headerBytes) with
      | .ok headerJson =>
        match Json.parse (String.fromUTF8Unchecked payloadBytes) with
        | .ok payloadJson =>
          match parseJoseHeader headerJson with
          | .ok header =>
            match parseClaimsSet payloadJson with
            | .ok claims =>
              .ok { header := header, claims := claims, signature := signatureBytes }
            | .error e => .error e
          | .error e => .error e
        | .error _ => .error .invalidJson
      | .error _ => .error .invalidJson
    | _, _, _ => .error .invalidBase64url
  | _ => .error .invalidFormat

/-- Parse JOSE header from JSON (RFC 7515 Section 4). -/
def parseJoseHeader (json : Json) : Except ParseError JoseHeader :=
  match json with
  | .obj obj =>
    match obj.find? "alg" with
    | some (.str algStr) =>
      match JwtAlgorithm.fromString algStr with
      | some alg =>
        let typ := obj.find? "typ" >>= Json.getStr?
        let cty := obj.find? "cty" >>= Json.getStr?
        let kid := obj.find? "kid" >>= Json.getStr?
        let jku := obj.find? "jku" >>= Json.getStr?
        let x5u := obj.find? "x5u" >>= Json.getStr?
        let x5c := match obj.find? "x5c" with
          | some (.arr arr) => some (arr.toList.map (·.getStr? |>.getD ""))
          | _ => none
        let x5t := obj.find? "x5t" >>= Json.getStr?
        let x5tS256 := obj.find? "x5tS256" >>= Json.getStr?
        .ok { alg := alg, typ := typ, cty := cty, kid := kid, jku := jku,
              x5u := x5u, x5c := x5c, x5t := x5t, x5tS256 := x5tS256 }
      | none => .error .unsupportedAlgorithm
    | _ => .error .missingAlgorithm
  | _ => .error .invalidJson

/-- Parse claims set from JSON (RFC 7519 Section 4). -/
def parseClaimsSet (json : Json) : Except ParseError JwtClaimsSet :=
  match json with
  | .obj obj =>
    let iss := obj.find? "iss" >>= Json.getStr?
    let sub := obj.find? "sub" >>= Json.getStr?
    let aud := match obj.find? "aud" with
      | some (.str s) => some [s]
      | some (.arr arr) => some (arr.toList.map (·.getStr? |>.getD ""))
      | _ => none
    let exp := obj.find? "exp" >>= Json.getNat? >>= (λ n => some (NumericDate.ofSeconds n))
    let nbf := obj.find? "nbf" >>= Json.getNat? >>= (λ n => some (NumericDate.ofSeconds n))
    let iat := obj.find? "iat" >>= Json.getNat? >>= (λ n => some (NumericDate.ofSeconds n))
    let jti := obj.find? "jti" >>= Json.getStr?
    -- Extract custom claims (everything not in registered claim names)
    let registeredClaims : List String := ["iss", "sub", "aud", "exp", "nbf", "iat", "jti"]
    let custom : Json.Object := obj.filter fun k _ => ¬registeredClaims.contains k
    .ok { iss := iss, sub := sub, aud := aud, exp := exp, nbf := nbf, iat := iat,
          jti := jti, custom := custom }
  | _ => .error .invalidJson

/-- Validate StringOrURI according to RFC 7519 Section 2.
    A StringOrURI is a string that, if it contains a colon (":"),
    must be a valid URI. -/
def isValidStringOrURI (s : String) : Bool :=
  if s.contains ':' then
    -- TODO: Add proper URI validation
    s.startsWith "http://" ∨ s.startsWith "https://" ∨ s.startsWith "urn:"
  else
    true

/-- Parse StringOrURI from string. -/
def parseStringOrURI (s : String) : Except ParseError StringOrURI :=
  if isValidStringOrURI s then
    .ok ⟨s, by simp [isValidStringOrURI]⟩
  else
    .error .invalidStringOrURI

/-- Serialize JWT to compact form (dot-separated Base64url). -/
def serializeCompact (jwt : Jwt) : String :=
  let headerJson := serializeJoseHeader jwt.header
  let claimsJson := serializeClaimsSet jwt.claims
  let headerB64 := base64urlEncode (headerJson.toString.toUTF8)
  let payloadB64 := base64urlEncode (claimsJson.toString.toUTF8)
  let signatureB64 := base64urlEncode jwt.signature
  s!"{headerB64}.{payloadB64}.{signatureB64}"

/-- Serialize JOSE header to JSON. -/
def serializeJoseHeader (header : JoseHeader) : Json :=
  let obj : Json.Object := {}
    |> Json.Object.insert "alg" (.str (toString header.alg))
    |> (λ o => match header.typ with | some t => o.insert "typ" (.str t) | none => o)
    |> (λ o => match header.cty with | some c => o.insert "cty" (.str c) | none => o)
    |> (λ o => match header.kid with | some k => o.insert "kid" (.str k) | none => o)
    |> (λ o => match header.jku with | some j => o.insert "jku" (.str j) | none => o)
    |> (λ o => match header.x5u with | some x => o.insert "x5u" (.str x) | none => o)
    |> (λ o => match header.x5c with
        | some lst => o.insert "x5c" (.arr (lst.map Json.str).toArray)
        | none => o)
    |> (λ o => match header.x5t with | some t => o.insert "x5t" (.str t) | none => o)
    |> (λ o => match header.x5tS256 with | some t => o.insert "x5tS256" (.str t) | none => o)
  .obj obj

/-- Serialize claims set to JSON. -/
def serializeClaimsSet (claims : JwtClaimsSet) : Json :=
  let obj : Json.Object := {}
    |> (λ o => match claims.iss with | some i => o.insert "iss" (.str i) | none => o)
    |> (λ o => match claims.sub with | some s => o.insert "sub" (.str s) | none => o)
    |> (λ o => match claims.aud with
        | some [a] => o.insert "aud" (.str a)
        | some lst => o.insert "aud" (.arr (lst.map Json.str).toArray)
        | none => o)
    |> (λ o => match claims.exp with | some e => o.insert "exp" (.num e.toSeconds) | none => o)
    |> (λ o => match claims.nbf with | some n => o.insert "nbf" (.num n.toSeconds) | none => o)
    |> (λ o => match claims.iat with | some i => o.insert "iat" (.num i.toSeconds) | none => o)
    |> (λ o => match claims.jti with | some j => o.insert "jti" (.str j) | none => o)
    -- Merge custom claims
    |> fun o => claims.custom.fold (init := o) fun k v o' => o'.insert k v
  .obj obj

/-- Theorem: Parsing then serializing returns original for valid JWTs. -/
theorem parse_serialize_roundtrip (token : String) (jwt : Jwt)
    (h : parseCompact token = .ok jwt) :
    serializeCompact jwt = token := by
  -- TODO: Prove using Base64url and JSON roundtrip properties
  sorry

/-- Theorem: Serializing then parsing returns original JWT. -/
theorem serialize_parse_roundtrip (jwt : Jwt) :
    parseCompact (serializeCompact jwt) = .ok jwt := by
  -- TODO: Prove using Base64url and JSON roundtrip properties
  sorry

end SWELib.Security.Jwt
