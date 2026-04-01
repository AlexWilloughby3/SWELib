import SWELib
import SWELibImpl.Networking.FastApi.CallableRegistry

/-!
# FastAPI Lifespan

Startup/shutdown lifecycle management for the FastAPI application.
Implements a bracket pattern: run startup hooks, execute the server,
then run shutdown hooks (even on error).

Lifespan handlers are registered under keys `"lifespan:startup"` and
`"lifespan:shutdown"` in the callable registry.
-/

namespace SWELibImpl.Networking.FastApi.Lifespan

open SWELib.Networking.FastApi
open SWELib.Networking.Http
open SWELibImpl.Networking.FastApi.CallableRegistry

/-- Run the startup phase of the application lifespan. -/
def runStartup (app : FastAPIApp) (registry : CallableRegistry) : IO Unit := do
  match app.lifespan with
  | some _ =>
    match registry.lookupHandler "lifespan:startup" with
    | some handler =>
      let startupReq : Request := {
        method := .GET
        target := .originForm "/__lifespan/startup" none
        headers := []
        body := none
      }
      let _ ← handler startupReq
    | none =>
      let _ ← IO.eprintln "[FastAPI] Lifespan callable not found in registry"
  | none => pure ()

/-- Run the shutdown phase of the application lifespan. -/
def runShutdown (app : FastAPIApp) (registry : CallableRegistry) : IO Unit := do
  match app.lifespan with
  | some _ =>
    match registry.lookupHandler "lifespan:shutdown" with
    | some handler =>
      let shutdownReq : Request := {
        method := .GET
        target := .originForm "/__lifespan/shutdown" none
        headers := []
        body := none
      }
      let _ ← handler shutdownReq
    | none => pure ()
  | none => pure ()

/-- Bracket pattern: run startup, execute the action, then run shutdown.
    Shutdown runs even if the action throws an exception. -/
def withLifespan (app : FastAPIApp) (registry : CallableRegistry) (action : IO Unit) : IO Unit := do
  runStartup app registry
  try
    action
  finally
    runShutdown app registry

end SWELibImpl.Networking.FastApi.Lifespan
