import SWELib.Networking.FastApi.Routing
import SWELib.Networking.FastApi.Dependencies
import SWELib.Networking.FastApi.Params
import SWELib.Networking.FastApi.Types
import SWELib.Networking.Websocket.Types

/-!
# FastAPI Operations

Pure functions for path matching, route dispatch, router composition,
exception handling, response model filtering, and WebSocket state transitions.

## References
- FastAPI: <https://fastapi.tiangolo.com/>
- Starlette routing: <https://www.starlette.io/routing/>
- RFC 6455 (WebSocket): state machine
-/

namespace SWELib.Networking.FastApi

open SWELib.Networking.Websocket

-- Path template operations

/-- Split a path template into its non-empty segments. -/
def PathTemplate.segments (t : PathTemplate) : List String :=
  (t.raw.splitOn "/").filter (· ≠ "")

/-- Check whether a segment is a path parameter (enclosed in braces). -/
def PathTemplate.isParamSegment (s : String) : Bool :=
  s.startsWith "{" && s.endsWith "}"

/-- Extract parameter names from a path template.
    Strips braces and any `:path` suffix. -/
def PathTemplate.paramNames (t : PathTemplate) : List String :=
  t.segments.filterMap fun s =>
    if PathTemplate.isParamSegment s then
      let inner := ((s.drop 1).dropEnd 1).toString
      -- Strip `:path` suffix if present
      let name := if inner.endsWith ":path" then (inner.dropEnd 5).toString else inner
      some name
    else
      none

/-- A path template is well-formed if it starts with "/" and every parameter
    segment has a non-empty name. -/
def PathTemplate.isWellFormed (t : PathTemplate) : Bool :=
  t.raw.startsWith "/" &&
  t.segments.all fun s =>
    if PathTemplate.isParamSegment s then
      let inner := ((s.drop 1).dropEnd 1).toString
      !inner.isEmpty
    else
      true

-- Path matching

/-- Recursively match template segments against actual path segments.
    Parameter segments bind to the corresponding actual value.
    A `{param:path}` segment greedily consumes all remaining segments.
    Static segments must match exactly. -/
def matchSegments : List String → List String → Option (List (String × String))
  | [], [] => some []
  | [t], as_@(_ :: _) =>
    -- Last template segment: check if it's a :path wildcard
    if PathTemplate.isParamSegment t then
      let inner := ((t.drop 1).dropEnd 1).toString
      if inner.endsWith ":path" then
        -- Greedy: consume all remaining segments
        let name := (inner.dropEnd 5).toString
        some [(name, "/".intercalate as_)]
      else
        -- Regular param: must match exactly one segment
        match as_ with
        | [a] => some [(inner, a)]
        | _ => none
    else
      match as_ with
      | [a] => if t == a then some [] else none
      | _ => none
  | t :: ts, a :: as_ =>
    if PathTemplate.isParamSegment t then
      let inner := ((t.drop 1).dropEnd 1).toString
      if inner.endsWith ":path" then
        -- :path in non-final position: consume all remaining segments
        -- except those needed for remaining template segments
        -- For simplicity, :path in non-final position is unsupported
        none
      else
        match matchSegments ts as_ with
        | some rest => some ((inner, a) :: rest)
        | none => none
    else if t == a then
      matchSegments ts as_
    else
      none
  | _, _ => none

/-- Match a request path against a path template. -/
def matchPath (template : PathTemplate) (path : String) : Option RouteMatch :=
  let tSegs := template.segments
  let pSegs := (path.splitOn "/").filter (· ≠ "")
  match matchSegments tSegs pSegs with
  | some bindings => some { bindings, isExact := true }
  | none => none

/-- Find the first route in the application matching the given method and path. -/
def resolveRoute (app : FastAPIApp) (method : String) (path : String)
    : Option (PathOperation × RouteMatch) :=
  app.router.routes.findSome? fun op =>
    if op.method == method then
      match matchPath op.path path with
      | some m => some (op, m)
      | none => none
    else
      none

-- Router composition

/-- Register a new path operation on a router by appending it to the route list. -/
def registerRoute (router : APIRouter) (op : PathOperation) : APIRouter :=
  { router with routes := router.routes ++ [op] }

/-- Include a child router into a parent, prepending the child's prefix
    to each route path and merging tags and dependencies.
    Dependency order: parent deps → child deps → route deps (FastAPI semantics). -/
def includeRouter (parent : APIRouter) (child : APIRouter) : APIRouter :=
  let mergedDeps := parent.dependencies ++ child.dependencies
  let prefixedRoutes := child.routes.map fun op =>
    { op with
      path := ⟨child.prefix ++ op.path.raw⟩
      tags := child.tags ++ op.tags
      dependencies := mergedDeps ++ op.dependencies }
  let prefixedWsRoutes := child.wsRoutes.map fun ws =>
    { ws with
      path := ⟨child.prefix ++ ws.path.raw⟩
      dependencies := mergedDeps ++ ws.dependencies }
  { parent with
    routes := parent.routes ++ prefixedRoutes
    wsRoutes := parent.wsRoutes ++ prefixedWsRoutes }

/-- A router prefix is well-formed if it is empty or starts with "/"
    and does not end with "/". -/
def APIRouter.prefixWellFormed (r : APIRouter) : Bool :=
  r.prefix == "" || (r.prefix.startsWith "/" && !r.prefix.endsWith "/")

-- Exception dispatch

/-- Find the first exception handler matching the given key. -/
def dispatchException (handlers : List ExceptionHandlerEntry) (key : ExceptionHandlerKey)
    : Option CallableRef :=
  (handlers.find? fun e => e.key == key).map (·.handler)

-- Response model filtering

/-- Filter a field list according to include/exclude sets and excludeNone. -/
def applyResponseModelFilter
    (incl excl : Option (List String))
    (excludeNone : Bool)
    (fields : List (String × Option String))
    : List (String × Option String) :=
  fields.filter fun (name, val) =>
    let inInclude := match incl with
      | some inc => inc.contains name
      | none => true
    let notExcluded := match excl with
      | some exc => !exc.contains name
      | none => true
    let notNone := if excludeNone then val.isSome else true
    inInclude && notExcluded && notNone

-- WebSocket state transitions (using ReadyState from Websocket.Types)

/-- Accept a WebSocket connection: transitions CONNECTING -> OPEN. -/
def acceptWebSocket (s : ReadyState) : Option ReadyState :=
  match s with
  | .CONNECTING => some .OPEN
  | _ => none

/-- Send data on a WebSocket: only valid in OPEN state. -/
def sendWebSocket (s : ReadyState) : Option ReadyState :=
  match s with
  | .OPEN => some .OPEN
  | _ => none

/-- Receive data on a WebSocket: only valid in OPEN state. -/
def receiveWebSocket (s : ReadyState) : Option ReadyState :=
  match s with
  | .OPEN => some .OPEN
  | _ => none

/-- Close a WebSocket: transitions OPEN -> CLOSING. -/
def closeWebSocket (s : ReadyState) : Option ReadyState :=
  match s with
  | .OPEN => some .CLOSING
  | _ => none

/-- Complete WebSocket close: transitions CLOSING -> CLOSED
    (after receiving close frame acknowledgement from peer). -/
def completeClose (s : ReadyState) : Option ReadyState :=
  match s with
  | .CLOSING => some .CLOSED
  | _ => none

end SWELib.Networking.FastApi
