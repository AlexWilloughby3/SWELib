import SWELib

/-!
# FastAPI Router

Thin IO wrappers around the spec's pure routing functions: `resolveRoute`,
`matchPath`, `registerRoute`, and `includeRouter`. These functions delegate
entirely to the spec layer; the IO wrapper exists for logging and error context.
-/

namespace SWELibImpl.Networking.FastApi.Router

open SWELib.Networking.FastApi

/-- Resolve a route for the given HTTP method and path.
    Delegates to the spec's `resolveRoute`. -/
def resolveRouteIO (app : FastAPIApp) (method : String) (path : String)
    : IO (Option (PathOperation × RouteMatch)) :=
  pure (resolveRoute app method path)

/-- Resolve a WebSocket route for the given path.
    Searches the app's WebSocket routes using `matchPath`. -/
def resolveWebSocketRouteIO (app : FastAPIApp) (path : String)
    : IO (Option (WebSocketRoute × RouteMatch)) :=
  pure <| app.router.wsRoutes.findSome? fun ws =>
    match matchPath ws.path path with
    | some m => some (ws, m)
    | none => none

/-- Register a new path operation on a router.
    Delegates to the spec's `registerRoute`. -/
def registerRouteIO (router : APIRouter) (op : PathOperation) : IO APIRouter :=
  pure (registerRoute router op)

/-- Include a child router into a parent router.
    Delegates to the spec's `includeRouter`. -/
def includeRouterIO (parent : APIRouter) (child : APIRouter) : IO APIRouter :=
  pure (includeRouter parent child)

/-- Build a `FastAPIApp` by including multiple routers into its base router. -/
def buildApp (app : FastAPIApp) (routers : List APIRouter) : FastAPIApp :=
  let merged := routers.foldl includeRouter app.router
  { app with router := merged }

end SWELibImpl.Networking.FastApi.Router
