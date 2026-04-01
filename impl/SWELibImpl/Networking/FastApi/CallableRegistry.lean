import SWELib
import SWELibImpl.Networking.HttpServer

/-!
# FastAPI Callable Registry

Maps string keys to concrete `IO` handler/dependency functions.

The spec layer uses opaque `CallableRef` values with axiomatized `BEq`,
which makes them noncomputable. The impl layer sidesteps this by keying
handlers on `String` identifiers (e.g., operation IDs, route keys like
"GET:/users/{id}", or dependency names). Users register handlers under
these keys and the dispatch loop looks them up by the same keys.
-/

namespace SWELibImpl.Networking.FastApi.CallableRegistry

open SWELib.Networking.FastApi
open SWELib.Networking.Http

/-- An endpoint handler: takes a request and returns a response. -/
abbrev HandlerFn := Request → IO Response

/-- A dependency callable: takes a request and returns a JSON result for injection. -/
abbrev DependencyFn := Request → IO Lean.Json

/-- A unified callable entry — either an endpoint handler or a dependency function. -/
inductive CallableImpl where
  | handler (f : HandlerFn)
  | dependency (f : DependencyFn)

/-- A registry entry pairing a string key with its concrete implementation. -/
structure CallableEntry where
  key : String
  impl : CallableImpl

/-- The callable registry: a list of entries searched by string key. -/
structure CallableRegistry where
  entries : List CallableEntry := []

/-- Register an endpoint handler under a string key. -/
def CallableRegistry.registerHandler (reg : CallableRegistry) (key : String) (f : HandlerFn)
    : CallableRegistry :=
  { reg with entries := reg.entries ++ [{ key, impl := .handler f }] }

/-- Register a dependency function under a string key. -/
def CallableRegistry.registerDependency (reg : CallableRegistry) (key : String) (f : DependencyFn)
    : CallableRegistry :=
  { reg with entries := reg.entries ++ [{ key, impl := .dependency f }] }

/-- Look up the implementation for a string key. Returns the first match. -/
def CallableRegistry.lookup (reg : CallableRegistry) (key : String) : Option CallableImpl :=
  (reg.entries.find? fun e => e.key == key).map (·.impl)

/-- Look up an endpoint handler specifically. Returns `none` if not found or if
    the callable is a dependency function. -/
def CallableRegistry.lookupHandler (reg : CallableRegistry) (key : String) : Option HandlerFn :=
  match reg.lookup key with
  | some (.handler f) => some f
  | _ => none

/-- Look up a dependency function specifically. Returns `none` if not found or if
    the callable is an endpoint handler. -/
def CallableRegistry.lookupDependency (reg : CallableRegistry) (key : String) : Option DependencyFn :=
  match reg.lookup key with
  | some (.dependency f) => some f
  | _ => none

/-- Build a route key from an HTTP method and path template. -/
def routeKey (method : String) (path : String) : String :=
  s!"{method}:{path}"

/-- Create an empty registry. -/
def CallableRegistry.empty : CallableRegistry := {}

end SWELibImpl.Networking.FastApi.CallableRegistry
