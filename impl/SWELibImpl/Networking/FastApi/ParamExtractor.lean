import SWELib
import Lean.Data.Json
import SWELibImpl.Networking.FastApi.JsonConvert

/-!
# FastAPI Parameter Extraction

Extracts path, query, header, cookie, and body parameters from HTTP requests
based on the spec's `ParamDescriptor`, `BodyDescriptor`, and `HeaderParam`
declarations.
-/

namespace SWELibImpl.Networking.FastApi.ParamExtractor

open SWELib.Networking.FastApi
open SWELib.Networking.Http

/-- Parse a URL query string into key-value pairs.
    Handles `key=value&key2=value2` format. -/
def parseQueryString (qs : String) : List (String × String) :=
  let pairs := qs.splitOn "&"
  pairs.filterMap fun pair =>
    match pair.splitOn "=" with
    | [k, v] => if k.isEmpty then none else some (k, v)
    | [k] => if k.isEmpty then none else some (k, "")
    | _ => none

/-- Extract path parameters from route match bindings,
    filtering to only those declared in the param descriptors. -/
def extractPathParams (m : RouteMatch) (params : List ParamDescriptor) : List (String × String) :=
  m.bindings.filter fun (name, _) =>
    params.any fun p => p.source == .path && (p.alias.getD p.name) == name

/-- Extract query parameters from a request target's query string. -/
def extractQueryParams (target : RequestTarget) (params : List ParamDescriptor) : List (String × String) :=
  let queryStr := match target with
    | .originForm _ (some qs) => qs
    | _ => ""
  let allPairs := parseQueryString queryStr
  let queryParams := params.filter (·.source == .query)
  queryParams.filterMap fun p =>
    let name := p.alias.getD p.name
    match allPairs.find? (·.1 == name) with
    | some (_, v) => some (p.name, v)
    | none => match p.default_ with
      | some d => some (p.name, d)
      | none => if p.required then none else some (p.name, "")

/-- Extract a header value by field name from request headers. -/
def findHeader (headers : Headers) (name : String) : Option String :=
  (headers.find? fun f => f.name.raw.toLower == name.toLower).map (·.value)

/-- Extract header parameters from request headers. -/
def extractHeaderParams (headers : Headers) (params : List HeaderParam) : List (String × String) :=
  params.filterMap fun hp =>
    let lookupName := if hp.convertUnderscores
      then (hp.base.alias.getD hp.base.name).replace "-" "_"
      else hp.base.alias.getD hp.base.name
    match findHeader headers lookupName with
    | some v => some (hp.base.name, v)
    | none => match hp.base.default_ with
      | some d => some (hp.base.name, d)
      | none => if hp.base.required then none else some (hp.base.name, "")

/-- Parse the Cookie header into key-value pairs. -/
def parseCookies (headers : Headers) : List (String × String) :=
  match findHeader headers "cookie" with
  | some cookieStr =>
    let pairs := cookieStr.splitOn "; "
    pairs.filterMap fun pair =>
      match pair.splitOn "=" with
      | [k, v] => some (k.trimAscii.toString, v.trimAscii.toString)
      | _ => none
  | none => []

/-- Extract cookie parameters from request headers. -/
def extractCookieParams (headers : Headers) (params : List ParamDescriptor) : List (String × String) :=
  let cookies := parseCookies headers
  let cookieParams := params.filter (·.source == .cookie)
  cookieParams.filterMap fun p =>
    let name := p.alias.getD p.name
    match cookies.find? (·.1 == name) with
    | some (_, v) => some (p.name, v)
    | none => match p.default_ with
      | some d => some (p.name, d)
      | none => if p.required then none else some (p.name, "")

/-- Extract the JSON body from a request. -/
def extractJsonBody (req : Request) : IO Lean.Json := do
  match req.body with
  | some bytes =>
    let str := String.fromUTF8! bytes
    match Lean.Json.parse str with
    | .ok j => pure j
    | .error e => throw <| IO.userError s!"Invalid JSON body: {e}"
  | none => pure .null

/-- Validate a string value against `ValidationConstraints`.
    Returns an error message on failure. -/
def validateConstraints (c : ValidationConstraints) (name : String) (val : String) : Option String :=
  let checks : List (Option String) := [
    match c.minLength with
    | some min => if val.length < min then some s!"Parameter '{name}': length {val.length} < minLength {min}" else none
    | none => none,
    match c.maxLength with
    | some max => if val.length > max then some s!"Parameter '{name}': length {val.length} > maxLength {max}" else none
    | none => none
  ]
  checks.findSome? id

/-- Collect all extracted parameters into a unified key-value list. -/
def extractAllParams (req : Request) (m : RouteMatch) (params : List ParamDescriptor)
    (headerParams : List HeaderParam) : List (String × String) :=
  let path := extractPathParams m params
  let query := extractQueryParams req.target params
  let headers := extractHeaderParams req.headers headerParams
  let cookies := extractCookieParams req.headers params
  path ++ query ++ headers ++ cookies

end SWELibImpl.Networking.FastApi.ParamExtractor
