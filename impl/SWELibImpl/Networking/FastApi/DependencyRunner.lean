import SWELib
import Lean.Data.Json
import SWELibImpl.Networking.FastApi.CallableRegistry

/-!
# FastAPI Dependency Runner

Executes the spec's `DependencyGraph` with proper setup/teardown ordering,
caching, and scope handling.

Setup runs in pre-order (spec's `DependencyGraph.setupOrder`).
Teardown runs in post-order for yield-based dependencies only
(spec's `DependencyGraph.teardownOrder` + `filterYieldDeps`).

Since `CallableRef` has noncomputable `BEq`, the runner uses string-based
dependency names for cache keys and registry lookups. Users must register
dependencies under names that correspond to their `DependsDecl` entries.
-/

namespace SWELibImpl.Networking.FastApi.DependencyRunner

open SWELib.Networking.FastApi
open SWELib.Networking.Http
open SWELibImpl.Networking.FastApi.CallableRegistry

/-- Cached dependency results, keyed by string name. -/
abbrev DependencyCache := List (String × Lean.Json)

/-- Context for dependency execution. -/
structure DependencyContext where
  request : Request
  registry : CallableRegistry
  cache : DependencyCache
  depKeyMap : List (String × String)  -- maps dependency description/index to registry key

/-- Look up a cached dependency result. -/
def lookupCache (cache : DependencyCache) (key : String) : Option Lean.Json :=
  (cache.find? fun (k, _) => k == key).map (·.2)

/-- Derive a registry key for a dependency declaration.
    Uses position index as a fallback since `CallableRef` can't be compared. -/
def depKey (idx : Nat) : String :=
  s!"dep:{idx}"

/-- Execute a single dependency by its registry key. -/
def executeDependency (ctx : DependencyContext) (key : String) (useCache : Bool)
    : IO (DependencyContext × Lean.Json) := do
  -- Check cache if caching is enabled
  if useCache then
    match lookupCache ctx.cache key with
    | some result => return (ctx, result)
    | none => pure ()
  -- Execute the dependency
  match ctx.registry.lookupDependency key with
  | some depFn =>
    let result ← depFn ctx.request
    let newCache := if useCache then (key, result) :: ctx.cache else ctx.cache
    return ({ ctx with cache := newCache }, result)
  | none =>
    throw <| IO.userError s!"Dependency '{key}' not found in registry"

/-- Execute the setup phase of a dependency graph.
    Runs dependencies in pre-order (spec's `DependencyGraph.setupOrder`).
    Returns the updated context and the list of yield dependency keys for teardown. -/
def runSetup (graph : DependencyGraph) (ctx : DependencyContext)
    : IO (DependencyContext × List String) := do
  let setupOrder := graph.setupOrder
  let mut currentCtx := ctx
  let mut yieldKeys : List String := []
  let mut idx := 0
  for decl in setupOrder do
    let key := depKey idx
    let (newCtx, _) ← executeDependency currentCtx key decl.useCache
    currentCtx := newCtx
    if decl.hasYield then
      yieldKeys := yieldKeys ++ [key]
    idx := idx + 1
  return (currentCtx, yieldKeys)

/-- Execute the teardown phase for yield-based dependencies.
    Runs in reverse order (post-order teardown). -/
def runTeardown (yieldKeys : List String) (ctx : DependencyContext)
    : IO Unit := do
  for key in yieldKeys.reverse do
    match ctx.registry.lookupDependency key with
    | some depFn =>
      try
        let _ ← depFn ctx.request
      catch e =>
        let _ ← IO.eprintln s!"[FastAPI] Teardown error for '{key}': {e}"
    | none => pure ()

/-- Execute the full dependency lifecycle for a request:
    setup → action → teardown. Teardown runs even on error. -/
def withDependencies (graph : DependencyGraph) (ctx : DependencyContext)
    (action : DependencyContext → IO Response) : IO Response := do
  let (setupCtx, yieldKeys) ← runSetup graph ctx
  try
    let resp ← action setupCtx
    runTeardown yieldKeys setupCtx
    return resp
  catch e =>
    runTeardown yieldKeys setupCtx
    throw e

end SWELibImpl.Networking.FastApi.DependencyRunner
