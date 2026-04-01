import SWELib
import Lean.Data.Json
import SWELibImpl.Networking.FastApi.CallableRegistry

/-!
# FastAPI Middleware

Middleware chain execution following FastAPI/ASGI semantics: last-registered
middleware is outermost and executes first (spec's `MiddlewareChain.executionOrder`).

Implements CORS, HTTPS redirect, and trusted host middleware. GZip is stubbed
pending a zlib FFI binding.
-/

namespace SWELibImpl.Networking.FastApi.Middleware

open SWELib.Networking.FastApi
open SWELib.Networking.Http
open SWELibImpl.Networking.FastApi.CallableRegistry

/-- A middleware runner wraps an inner handler, potentially modifying the
    request before and/or the response after. -/
abbrev MiddlewareRunner := (Request → IO Response) → Request → IO Response

/-- Find a header value in a request (case-insensitive). -/
private def getHeader (headers : Headers) (name : String) : Option String :=
  (headers.find? fun f => f.name.raw.toLower == name.toLower).map (·.value)

/-- Add a header to a response. -/
private def addResponseHeader (resp : Response) (name : String) (value : String) : Response :=
  { resp with headers := resp.headers ++ [{ name := ⟨name⟩, value }] }

/-- CORS middleware: handles preflight OPTIONS requests and adds CORS headers
    to all responses per the `CORSConfig`. -/
def applyCors (cfg : CORSConfig) : MiddlewareRunner := fun inner req => do
  let origin := getHeader req.headers "origin"
  if req.method == .OPTIONS && origin.isSome then
    let resp : Response := {
      status := StatusCode.ok
      headers := []
      body := none
    }
    let resp := addResponseHeader resp "Access-Control-Allow-Methods"
      (", ".intercalate cfg.allowMethods)
    let resp := addResponseHeader resp "Access-Control-Allow-Headers"
      (", ".intercalate cfg.allowHeaders)
    let resp := addResponseHeader resp "Access-Control-Max-Age"
      (toString cfg.maxAge)
    let resp := match origin with
      | some o =>
        if cfg.allowOrigins.contains o || cfg.allowOrigins.contains "*"
        then addResponseHeader resp "Access-Control-Allow-Origin" o
        else resp
      | none => resp
    let resp := if cfg.allowCredentials
      then addResponseHeader resp "Access-Control-Allow-Credentials" "true"
      else resp
    pure resp
  else
    let resp ← inner req
    let resp := match origin with
      | some o =>
        if cfg.allowOrigins.contains o || cfg.allowOrigins.contains "*"
        then addResponseHeader resp "Access-Control-Allow-Origin" o
        else resp
      | none => resp
    let resp := if cfg.allowCredentials
      then addResponseHeader resp "Access-Control-Allow-Credentials" "true"
      else resp
    let resp := if !cfg.exposeHeaders.isEmpty
      then addResponseHeader resp "Access-Control-Expose-Headers"
        (", ".intercalate cfg.exposeHeaders)
      else resp
    pure resp

/-- HTTPS redirect middleware: redirects HTTP requests to HTTPS. -/
def applyHttpsRedirect : MiddlewareRunner := fun inner req => do
  let proto := getHeader req.headers "x-forwarded-proto"
  if proto == some "http" then
    let host := (getHeader req.headers "host").getD "localhost"
    let path := match req.target with
      | .originForm p qs => p ++ (match qs with | some q => "?" ++ q | none => "")
      | _ => "/"
    pure {
      status := StatusCode.temporaryRedirect
      headers := [{ name := ⟨"Location"⟩, value := s!"https://{host}{path}" }]
      body := none
    }
  else
    inner req

/-- Trusted host middleware: validates the Host header against allowed hosts. -/
def applyTrustedHost (cfg : TrustedHostConfig) : MiddlewareRunner := fun inner req => do
  let host := getHeader req.headers "host"
  match host with
  | some h =>
    let hostName := (h.splitOn ":").head!
    if cfg.allowedHosts.contains hostName || cfg.allowedHosts.contains "*" then
      inner req
    else if cfg.wwwRedirect && cfg.allowedHosts.any (· == s!"www.{hostName}") then
      pure {
        status := StatusCode.movedPermanently
        headers := [{ name := ⟨"Location"⟩, value := s!"https://www.{hostName}/" }]
        body := none
      }
    else
      pure {
        status := StatusCode.badRequest
        headers := [{ name := FieldName.contentType, value := "text/plain" }]
        body := some "Invalid host header".toUTF8
      }
  | none =>
    pure {
      status := StatusCode.badRequest
      headers := [{ name := FieldName.contentType, value := "text/plain" }]
      body := some "Missing host header".toUTF8
    }

/-- GZip middleware stub. Requires zlib FFI for actual compression. -/
def applyGzip (_cfg : GZipConfig) : MiddlewareRunner := fun inner req => do
  -- TODO: requires zlib FFI for compression
  inner req

/-- Convert a `MiddlewareConfig` to a `MiddlewareRunner`.
    For custom HTTP middleware, looks up a handler by key "middleware:{index}". -/
def middlewareConfigToRunner (config : MiddlewareConfig) (registry : CallableRegistry)
    (idx : Nat) : MiddlewareRunner :=
  match config with
  | .corsConfig cfg => applyCors cfg
  | .gzipConfig cfg => applyGzip cfg
  | .trustedHostConfig cfg => applyTrustedHost cfg
  | .httpsRedirectConfig => applyHttpsRedirect
  | .httpConfig _callRef =>
    fun inner req => do
      let key := s!"middleware:{idx}"
      match registry.lookupHandler key with
      | some handler => handler req
      | none => inner req

/-- Build the complete middleware chain from a list of `MiddlewareEntry`.
    Last-registered is outermost (executes first), per ASGI stacking semantics. -/
def buildMiddlewareChain (entries : List MiddlewareEntry) (registry : CallableRegistry)
    (innerHandler : Request → IO Response) : Request → IO Response :=
  let executionOrder := entries.reverse
  let indexed := executionOrder.zip (List.range executionOrder.length)
  indexed.foldl (fun handler (entry, idx) =>
    (middlewareConfigToRunner entry.config registry idx) handler
  ) innerHandler

end SWELibImpl.Networking.FastApi.Middleware
