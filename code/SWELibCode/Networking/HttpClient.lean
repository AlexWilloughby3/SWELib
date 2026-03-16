import SWELib
import SWELibBridge
import SWELibCode.Ffi.Libcurl
import SWELibBridge.Libcurl.Response

/-!
# HTTP Client

Executable HTTP client using the libcurl FFI path.
Provides `get`, `post`, and generic `request` functions
that return spec-level `Http.Response` values.
-/

namespace SWELibCode.Networking.HttpClient

open SWELib.Networking.Http
open SWELibCode.Ffi.Libcurl
open SWELibBridge.Libcurl

/-- Convert a `Method` to its string representation for curl. -/
private def methodString : Method → String
  | .GET => "GET"
  | .HEAD => "HEAD"
  | .POST => "POST"
  | .PUT => "PUT"
  | .PATCH => "PATCH"
  | .DELETE => "DELETE"
  | .CONNECT => "CONNECT"
  | .OPTIONS => "OPTIONS"
  | .TRACE => "TRACE"
  | .extension t => t

/-- Convert spec Headers to curl header strings ("Name: Value"). -/
private def headersToCurlList (hs : Headers) : Array String :=
  hs.toArray.map fun f => s!"{f.name.raw}: {f.value}"

/-- Parse a raw status code into a spec StatusCode.
    Throws if the code is outside [100, 999]. -/
private def parseStatusCode (code : UInt32) : IO StatusCode := do
  let n := code.toNat
  if h : 100 ≤ n ∧ n ≤ 999 then
    return ⟨n, h⟩
  else
    throw <| IO.userError s!"Invalid HTTP status code: {n}"

/-- Perform an HTTP request and return a spec-level Response. -/
def request (method : Method) (url : String)
    (headers : Headers := []) (body : Option ByteArray := none) :
    IO Response := do
  let curlHeaders := headersToCurlList headers
  let curlBody := body.getD ByteArray.empty
  let (rawStatus, rawHeaders, rawBody) ←
    curlPerform (methodString method) url curlHeaders curlBody
  let status ← parseStatusCode rawStatus
  let parsedHeaders := parseRawHeaders rawHeaders
  let responseBody := if rawBody.isEmpty then none else some rawBody
  return {
    status  := status
    headers := parsedHeaders
    body    := responseBody
  }

/-- Perform an HTTP GET request. -/
def get (url : String) (headers : Headers := []) : IO Response :=
  request .GET url headers none

/-- Perform an HTTP POST request. -/
def post (url : String) (body : ByteArray)
    (headers : Headers := []) : IO Response :=
  request .POST url headers (some body)

/-- Perform an HTTP POST request with a string body and Content-Type. -/
def postString (url : String) (body : String)
    (contentType : String := "application/json")
    (headers : Headers := []) : IO Response :=
  let hs := headers.add FieldName.contentType contentType
  post url body.toUTF8 hs

/-- Perform an HTTP PUT request. -/
def put (url : String) (body : ByteArray)
    (headers : Headers := []) : IO Response :=
  request .PUT url headers (some body)

/-- Perform an HTTP DELETE request. -/
def delete (url : String) (headers : Headers := []) : IO Response :=
  request .DELETE url headers none

/-- Perform an HTTP HEAD request (no body in response). -/
def head (url : String) (headers : Headers := []) : IO Response :=
  request .HEAD url headers none

end SWELibCode.Networking.HttpClient
