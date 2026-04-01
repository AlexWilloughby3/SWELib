import SWELib.Networking.FastApi.Preamble
import SWELib.Networking.FastApi.Types
import SWELib.Networking.FastApi.Dependencies
import SWELib.Networking.FastApi.Params

/-!
# FastAPI Routing

Route definitions, routers, middleware configuration, and the top-level
`FastAPIApp` structure.

## References
- FastAPI: <https://fastapi.tiangolo.com/tutorial/bigger-applications/>
- Starlette routing: <https://www.starlette.io/routing/>
-/

namespace SWELib.Networking.FastApi

/-- A URL path template such as `"/users/{user_id}"`. -/
structure PathTemplate where
  raw : String
  deriving DecidableEq, Repr

/-- A declared path parameter extracted from a path template. -/
structure PathParam where
  name : String
  isPathType : Bool := false
  deriving DecidableEq, Repr

/-- Result of matching a request path against a route template. -/
structure RouteMatch where
  bindings : List (String × String)
  isExact : Bool
  deriving DecidableEq, Repr

/-- Configuration for response model serialization filtering. -/
structure ResponseModelConfig where
  model : Option SchemaObject := none
  excludeUnset : Bool := false
  excludeDefaults : Bool := false
  excludeNone : Bool := false
  «include» : Option (List String) := none
  «exclude» : Option (List String) := none
  byAlias : Bool := false

/-- Concrete middleware configuration, one constructor per middleware kind. -/
inductive MiddlewareConfig where
  | corsConfig (cfg : CORSConfig)
  | gzipConfig (cfg : GZipConfig)
  | trustedHostConfig (cfg : TrustedHostConfig)
  | httpsRedirectConfig
  | httpConfig (handler : CallableRef)

/-- An entry in the middleware stack. -/
structure MiddlewareEntry where
  config : MiddlewareConfig

/-- An entry in the exception handler registry. -/
structure ExceptionHandlerEntry where
  key : ExceptionHandlerKey
  handler : CallableRef

/-- A single path operation (route endpoint) in FastAPI. -/
structure PathOperation where
  path : PathTemplate
  method : String
  operationId : Option String := none
  tags : List String := []
  summary : Option String := none
  description : Option String := none
  deprecated : Bool := false
  includeInSchema : Bool := true
  responseModel : ResponseModelConfig := {}
  statusCode : Nat := 200
  dependencies : List DependsDecl := []
  responseClass : ResponseClass := .json
  callbacks : List String := []

/-- A WebSocket route in FastAPI. -/
structure WebSocketRoute where
  path : PathTemplate
  name : Option String := none
  dependencies : List DependsDecl := []

/-- An API router grouping related routes with shared configuration. -/
structure APIRouter where
  «prefix» : String := ""
  tags : List String := []
  dependencies : List DependsDecl := []
  defaultResponseClass : ResponseClass := .json
  routes : List PathOperation := []
  wsRoutes : List WebSocketRoute := []
  deprecated : Bool := false
  includeInSchema : Bool := true

/-- A server entry for the OpenAPI `servers` array. -/
structure ServerEntry where
  url : String
  description : Option String := none
  deriving Repr

/-- The top-level FastAPI application, encompassing routing, middleware,
    exception handling, and OpenAPI metadata. -/
structure FastAPIApp where
  router : APIRouter := {}
  title : String := "FastAPI"
  version : String := "0.1.0"
  description : Option String := none
  openApiUrl : Option String := some "/openapi.json"
  docsUrl : Option String := some "/docs"
  redocUrl : Option String := some "/redoc"
  debug : Bool := false
  middleware : List MiddlewareEntry := []
  exceptionHandlers : List ExceptionHandlerEntry := []
  lifespan : Option CallableRef := none
  dependencyOverrides : List (CallableRef × CallableRef) := []
  state : AppState := []
  openApiVersion : String := "3.1.0"
  separateInputOutputSchemas : Bool := true
  rootPath : String := ""
  servers : List ServerEntry := []
  webhooks : List PathOperation := []

/-- Alias: middleware chain is just the list of middleware entries. -/
abbrev MiddlewareChain := List MiddlewareEntry

end SWELib.Networking.FastApi
