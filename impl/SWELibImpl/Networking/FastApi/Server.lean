import SWELib
import Lean.Data.Json
import SWELibImpl.Networking.HttpServer
import SWELibImpl.Networking.FastApi.CallableRegistry
import SWELibImpl.Networking.FastApi.JsonConvert
import SWELibImpl.Networking.FastApi.ParamExtractor
import SWELibImpl.Networking.FastApi.Router
import SWELibImpl.Networking.FastApi.ExceptionHandler

/-!
# FastAPI Server

The main dispatch loop that wires route matching, parameter extraction,
handler invocation, and exception handling into the existing `HttpServer`
accept loop.

Handlers are registered in the `CallableRegistry` under route keys
of the form `"GET:/path/template"` (method + path).
-/

namespace SWELibImpl.Networking.FastApi.Server

open SWELib.Networking.FastApi
open SWELib.Networking.Http
open SWELibImpl.Networking.HttpServer
open SWELibImpl.Networking.FastApi.CallableRegistry
open SWELibImpl.Networking.FastApi.ExceptionHandler
open SWELibImpl.Networking.FastApi.ParamExtractor
open SWELibImpl.Networking.FastApi.Router

/-- The FastAPI server state. -/
structure FastAPIServer where
  app : FastAPIApp
  registry : CallableRegistry
  httpServer : HttpServer

/-- Extract the request path from a `RequestTarget`. -/
private def requestPath (target : RequestTarget) : String :=
  match target with
  | .originForm path _ => path
  | .absoluteForm uri => if uri.path.isEmpty then "/" else uri.path
  | .authorityForm _ _ => "/"
  | .asteriskForm => "*"

/-- Extract the HTTP method string from a spec `Method`. -/
private def methodToString : Method → String
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

/-- Apply response model filtering to a JSON response body, if configured. -/
private def applyResponseFilter (config : ResponseModelConfig) (body : Option ByteArray)
    : Option ByteArray :=
  if config.model.isNone &&
     !config.excludeUnset && !config.excludeDefaults && !config.excludeNone &&
     config.include.isNone && config.exclude.isNone
  then body
  else
    match body with
    | none => none
    | some bytes =>
      let str := String.fromUTF8! bytes
      match Lean.Json.parse str with
      | .error _ => body
      | .ok json =>
        match json with
        | .obj fields =>
          let fieldList := fields.toList.map fun (k, v) =>
            (k, match v with | .null => none | _ => some (v.pretty))
          let filtered := applyResponseModelFilter config.include config.exclude
            config.excludeNone fieldList
          let resultFields := filtered.map fun (k, v) =>
            (k, match v with
              | some s =>
                match Lean.Json.parse s with | .ok j => j | .error _ => .str s
              | none => .null)
          let resultJson := Lean.Json.mkObj resultFields
          some resultJson.pretty.toUTF8
        | _ => body

/-- The core request dispatch function.

    Flow:
    1. Resolve route via spec's `resolveRoute`
    2. No match → 404
    3. Look up handler in registry by route key (METHOD:path_template)
    4. Call handler
    5. Apply response model filter
    6. On exception → dispatch via exception handlers -/
def dispatchRequest (server : FastAPIServer) (req : Request) : IO Response := do
  let path := requestPath req.target
  let method := methodToString req.method
  let routeResult ← resolveRouteIO server.app method path
  match routeResult with
  | none => pure notFoundResponse
  | some (op, _routeMatch) =>
    try
      -- Look up handler by route key
      let key := routeKey op.method op.path.raw
      match server.registry.lookupHandler key with
      | some handler =>
        let resp ← handler req
        let filteredBody := applyResponseFilter op.responseModel resp.body
        pure { resp with body := filteredBody }
      | none =>
        -- Try operationId as fallback key
        match op.operationId with
        | some opId =>
          match server.registry.lookupHandler opId with
          | some handler =>
            let resp ← handler req
            let filteredBody := applyResponseFilter op.responseModel resp.body
            pure { resp with body := filteredBody }
          | none => pure (internalErrorResponse "No handler registered for route")
        | none => pure (internalErrorResponse "No handler registered for route")
    catch e =>
      let key := ExceptionHandlerKey.statusCode 500
      let customResult ← dispatchCustomHandler server.registry key req
      match customResult with
      | some resp => pure resp
      | none => pure (internalErrorResponse s!"Internal error: {e}")

/-- Create and start a FastAPI server on the given host and port. -/
def serve (app : FastAPIApp) (registry : CallableRegistry)
    (host : String := "0.0.0.0") (port : UInt16) : IO FastAPIServer := do
  let httpServer ← HttpServer.serve host port
  return { app, registry, httpServer }

/-- Run the FastAPI server accept loop. Blocks indefinitely. -/
def run (server : FastAPIServer) : IO Unit :=
  server.httpServer.acceptLoop (dispatchRequest server)

/-- Stop the FastAPI server. -/
def stop (server : FastAPIServer) : IO Unit :=
  server.httpServer.close

end SWELibImpl.Networking.FastApi.Server
