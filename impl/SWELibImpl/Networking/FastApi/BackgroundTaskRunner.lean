import SWELib
import SWELibImpl.Networking.FastApi.CallableRegistry

/-!
# FastAPI Background Task Runner

Executes background tasks after the HTTP response has been sent.
Tasks run in insertion order, as specified by `BackgroundTasks.tasks`.
Each task's handler is looked up in the registry by its `description` field.
-/

namespace SWELibImpl.Networking.FastApi.BackgroundTaskRunner

open SWELib.Networking.FastApi
open SWELib.Networking.Http
open SWELibImpl.Networking.FastApi.CallableRegistry

/-- Execute background tasks sequentially in insertion order.
    Each task's handler is looked up in the registry keyed by
    `"bg:{description}"`. Errors are logged but do not propagate. -/
def runBackgroundTasks (tasks : BackgroundTasks) (registry : CallableRegistry) : IO Unit := do
  for task in tasks.tasks do
    let key := s!"bg:{task.description}"
    match registry.lookupHandler key with
    | some handler =>
      try
        let emptyReq : Request := {
          method := .GET
          target := .originForm "/" none
          headers := []
          body := none
        }
        let _ ← handler emptyReq
      catch e =>
        let _ ← IO.eprintln s!"[FastAPI] Background task '{task.description}' failed: {e}"
    | none =>
      let _ ← IO.eprintln s!"[FastAPI] Background task '{task.description}': handler not found"

/-- Spawn background tasks asynchronously using `IO.asTask`.
    Returns immediately; tasks run in the background. -/
def spawnBackgroundTasks (tasks : BackgroundTasks) (registry : CallableRegistry) : IO Unit := do
  let _ ← IO.asTask (runBackgroundTasks tasks registry)
  pure ()

end SWELibImpl.Networking.FastApi.BackgroundTaskRunner
