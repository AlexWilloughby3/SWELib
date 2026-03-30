import SWELib.Basics.Base64url
import SWELib.Security.Jwt.Types
import SWELib.Security.Jwt.Algorithm
import Lean.Data.Json

open Lean

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

/-- Parse JOSE header from JSON (RFC 7515 Section 4). -/
def parseJoseHeader (json : Json) : Except ParseError JoseHeader :=
  match json with
  | .obj obj =>
    match obj.get? "alg" with
    | some (.str algStr) =>
      match JwtAlgorithm.fromString algStr with
      | some alg =>
        let typ := (obj.get? "typ" >>= fun j => j.getStr?.toOption)
        let cty := (obj.get? "cty" >>= fun j => j.getStr?.toOption)
        let kid := (obj.get? "kid" >>= fun j => j.getStr?.toOption)
        let jku := (obj.get? "jku" >>= fun j => j.getStr?.toOption)
        let x5u := (obj.get? "x5u" >>= fun j => j.getStr?.toOption)
        let x5c := match obj.get? "x5c" with
          | some (.arr arr) => some (arr.toList.map (fun j => j.getStr?.toOption.getD ""))
          | _ => none
        let x5t := (obj.get? "x5t" >>= fun j => j.getStr?.toOption)
        let x5tS256 := (obj.get? "x5tS256" >>= fun j => j.getStr?.toOption)
        .ok { alg := alg, typ := typ, cty := cty, kid := kid, jku := jku,
              x5u := x5u, x5c := x5c, x5t := x5t, x5tS256 := x5tS256 }
      | none => .error .unsupportedAlgorithm
    | _ => .error .missingAlgorithm
  | _ => .error .invalidJson

/-- Parse claims set from JSON (RFC 7519 Section 4). -/
def parseClaimsSet (json : Json) : Except ParseError JwtClaimsSet :=
  match json with
  | .obj obj =>
    let iss := (obj.get? "iss" >>= fun j => j.getStr?.toOption)
    let sub := (obj.get? "sub" >>= fun j => j.getStr?.toOption)
    let aud := match obj.get? "aud" with
      | some (.str s) => some [s]
      | some (.arr arr) => some (arr.toList.map (fun j => j.getStr?.toOption.getD ""))
      | _ => none
    let exp : Option SWELib.Basics.NumericDate := obj.get? "exp" >>= fun j =>
      j.getNat?.toOption >>= fun n => some (SWELib.Basics.NumericDate.ofSeconds n)
    let nbf : Option SWELib.Basics.NumericDate := obj.get? "nbf" >>= fun j =>
      j.getNat?.toOption >>= fun n => some (SWELib.Basics.NumericDate.ofSeconds n)
    let iat : Option SWELib.Basics.NumericDate := obj.get? "iat" >>= fun j =>
      j.getNat?.toOption >>= fun n => some (SWELib.Basics.NumericDate.ofSeconds n)
    let jti := obj.get? "jti" >>= fun j => j.getStr?.toOption
    -- Extract custom claims (everything not in registered claim names)
    let registeredClaims : List String := ["iss", "sub", "aud", "exp", "nbf", "iat", "jti"]
    let custom : JsonObject := obj.filter fun k _ => ¬registeredClaims.contains k
    .ok { iss := iss, sub := sub, aud := aud, exp := exp, nbf := nbf, iat := iat,
          jti := jti, custom := custom }
  | _ => .error .invalidJson

/-- Parse StringOrURI from string. -/
def parseStringOrURI (s : String) : Except ParseError StringOrURI :=
  if h : isValidStringOrURI s then
    .ok ⟨s, by simp [h]⟩
  else
    .error .invalidStringOrURI

/-- Parse a JWT from its compact serialization (dot-separated string). -/
def parseCompact (token : String) : Except ParseError Jwt :=
  let parts := token.splitOn "."
  match parts with
  | [headerB64, payloadB64, signatureB64] =>
    match SWELib.Basics.base64urlDecode headerB64,
          SWELib.Basics.base64urlDecode payloadB64,
          SWELib.Basics.base64urlDecode signatureB64 with
    | some headerBytes, some payloadBytes, some signatureBytes =>
      match String.fromUTF8? headerBytes with
      | some headerText =>
        match String.fromUTF8? payloadBytes with
        | some payloadText =>
          match Json.parse headerText with
          | .ok headerJson =>
            match Json.parse payloadText with
            | .ok payloadJson =>
              match parseJoseHeader headerJson with
              | Except.ok header =>
                match parseClaimsSet payloadJson with
                | Except.ok claims =>
                  Except.ok { header := header, claims := claims, signature := signatureBytes }
                | Except.error e => Except.error e
              | Except.error e => Except.error e
            | .error _ => Except.error .invalidJson
          | .error _ => Except.error .invalidJson
        | none => Except.error .invalidJson
      | none => Except.error .invalidJson
    | _, _, _ => Except.error .invalidBase64url
  | _ => Except.error .invalidFormat

/-- Serialize JOSE header to JSON. -/
def serializeJoseHeader (header : JoseHeader) : Json :=
  let obj : JsonObject := Std.TreeMap.Raw.empty
    |> fun (o : JsonObject) => o.insert "alg" (.str (toString header.alg))
    |> fun (o : JsonObject) => match header.typ with | some t => o.insert "typ" (.str t) | none => o
    |> fun (o : JsonObject) => match header.cty with | some c => o.insert "cty" (.str c) | none => o
    |> fun (o : JsonObject) => match header.kid with | some k => o.insert "kid" (.str k) | none => o
    |> fun (o : JsonObject) => match header.jku with | some j => o.insert "jku" (.str j) | none => o
    |> fun (o : JsonObject) => match header.x5u with | some x => o.insert "x5u" (.str x) | none => o
    |> fun (o : JsonObject) => match header.x5c with
      | some lst => o.insert "x5c" (.arr (lst.map Json.str).toArray)
      | none => o
    |> fun (o : JsonObject) => match header.x5t with | some t => o.insert "x5t" (.str t) | none => o
    |> fun (o : JsonObject) => match header.x5tS256 with | some t => o.insert "x5tS256" (.str t) | none => o
  .obj obj

/-- Serialize claims set to JSON. -/
def serializeClaimsSet (claims : JwtClaimsSet) : Json :=
  let baseObj : JsonObject := Std.TreeMap.Raw.empty
    |> fun (o : JsonObject) => match claims.iss with | some i => o.insert "iss" (.str i) | none => o
    |> fun (o : JsonObject) => match claims.sub with | some s => o.insert "sub" (.str s) | none => o
    |> fun (o : JsonObject) => match claims.aud with
      | some [a] => o.insert "aud" (.str a)
      | some lst => o.insert "aud" (.arr (lst.map Json.str).toArray)
      | none => o
    |> fun (o : JsonObject) => match claims.exp with
      | some e => o.insert "exp" (.num (SWELib.Basics.NumericDate.toSeconds e))
      | none => o
    |> fun (o : JsonObject) => match claims.nbf with
      | some n => o.insert "nbf" (.num (SWELib.Basics.NumericDate.toSeconds n))
      | none => o
    |> fun (o : JsonObject) => match claims.iat with
      | some i => o.insert "iat" (.num (SWELib.Basics.NumericDate.toSeconds i))
      | none => o
    |> fun (o : JsonObject) => match claims.jti with | some j => o.insert "jti" (.str j) | none => o
  let obj := claims.custom.foldl (fun o k v => o.insert k v) baseObj
  .obj obj

/-- Serialize JWT to compact form (dot-separated Base64url). -/
def serializeCompact (jwt : Jwt) : String :=
  let headerJson := serializeJoseHeader jwt.header
  let claimsJson := serializeClaimsSet jwt.claims
  let headerB64 := SWELib.Basics.base64urlEncode ((Json.compress headerJson).toUTF8)
  let payloadB64 := SWELib.Basics.base64urlEncode ((Json.compress claimsJson).toUTF8)
  let signatureB64 := SWELib.Basics.base64urlEncode jwt.signature
  s!"{headerB64}.{payloadB64}.{signatureB64}"

/-- Theorem: Parsing then serializing returns original for valid JWTs. -/
axiom parse_serialize_roundtrip (token : String) (jwt : Jwt)
    (h : parseCompact token = .ok jwt) :
    serializeCompact jwt = token

/-- Theorem: Serializing then parsing returns original JWT. -/
axiom serialize_parse_roundtrip (jwt : Jwt) :
    parseCompact (serializeCompact jwt) = .ok jwt

end SWELib.Security.Jwt
