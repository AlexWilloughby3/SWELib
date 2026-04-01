import SWELib
import Lean.Data.Json
import SWELibImpl.Networking.FastApi.JsonConvert
import SWELibImpl.Networking.FastApi.CallableRegistry

/-!
# FastAPI Exception Handling

Converts `HTTPException` and `RequestValidationError` into HTTP responses,
and dispatches custom exception handlers via the spec's `dispatchException`
and the callable registry.
-/

namespace SWELibImpl.Networking.FastApi.ExceptionHandler

open SWELib.Networking.FastApi
open SWELib.Networking.Http
open SWELibImpl.Networking.FastApi.JsonConvert
open SWELibImpl.Networking.FastApi.CallableRegistry

/-- Safely construct a `StatusCode` from a `Nat`, falling back to 500 if out of range. -/
private def mkStatusCode (n : Nat) : StatusCode :=
  if h : 100 ≤ n ∧ n ≤ 999 then ⟨n, h⟩
  else StatusCode.internalServerError

/-- Convert an `HTTPException` to an HTTP `Response` with JSON body. -/
def httpExceptionToResponse (e : HTTPException) : Response :=
  let body := (httpExceptionToJson e).pretty
  let headers : Headers := [
    { name := FieldName.contentType, value := "application/json" }
  ] ++ (e.headers.map fun (k, v) => { name := ⟨k⟩, value := v })
  {
    status := mkStatusCode e.statusCode
    headers := headers
    body := some body.toUTF8
  }

/-- Convert a `RequestValidationError` to a 422 HTTP `Response`. -/
def validationErrorToResponse (e : RequestValidationError) : Response :=
  let body := (validationErrorToJson e).pretty
  {
    status := StatusCode.unprocessableContent
    headers := [{ name := FieldName.contentType, value := "application/json" }]
    body := some body.toUTF8
  }

/-- Build a default error response for an unhandled exception. -/
def defaultErrorResponse (statusCode : Nat) (message : String) : Response :=
  let body := Lean.Json.mkObj [("detail", .str message)]
  {
    status := mkStatusCode statusCode
    headers := [{ name := FieldName.contentType, value := "application/json" }]
    body := some body.pretty.toUTF8
  }

/-- Build a 404 Not Found response. -/
def notFoundResponse : Response :=
  defaultErrorResponse 404 "Not Found"

/-- Build a 405 Method Not Allowed response. -/
def methodNotAllowedResponse : Response :=
  defaultErrorResponse 405 "Method Not Allowed"

/-- Build a 500 Internal Server Error response. -/
def internalErrorResponse (msg : String) : Response :=
  defaultErrorResponse 500 msg

/-- Dispatch a custom exception handler. Looks up a handler in the registry
    keyed by status code or exception class name. -/
def dispatchCustomHandler
    (registry : CallableRegistry)
    (key : ExceptionHandlerKey)
    (req : Request)
    : IO (Option Response) := do
  let handlerKey := match key with
    | .statusCode n => s!"exception:{n}"
    | .exceptionClass name => s!"exception:{name}"
  match registry.lookupHandler handlerKey with
  | some handler => return some (← handler req)
  | none => return none

end SWELibImpl.Networking.FastApi.ExceptionHandler
