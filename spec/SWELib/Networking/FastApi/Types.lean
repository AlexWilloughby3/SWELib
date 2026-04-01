import SWELib.Networking.FastApi.Preamble

/-!
# FastAPI Core Types

Enumerations and flat data structures for FastAPI modelling.
No forward references to routing or dependency injection.

## References
- FastAPI: <https://fastapi.tiangolo.com/>
- Starlette middleware: <https://www.starlette.io/middleware/>
-/

namespace SWELib.Networking.FastApi

/-- A lightweight JSON value type for representing arbitrary serializable data
    (e.g., HTTPException detail fields, OpenAPI extra metadata). -/
inductive JsonValue where
  | null
  | bool (b : Bool)
  | num (n : Int)
  | str (s : String)
  | arr (items : List JsonValue)
  | obj (fields : List (String × JsonValue))

/-- Source location of a request parameter in the FastAPI parameter model. -/
inductive ParamSource where
  | path
  | query
  | header
  | cookie
  | body
  | form
  | file
  deriving DecidableEq, Repr

/-- Scope controlling the caching lifetime of a dependency result. -/
inductive DependencyScope where
  | request
  | function
  deriving DecidableEq, Repr

/-- Phase within the application lifespan lifecycle. -/
inductive LifespanPhase where
  | startup
  | shutdown
  deriving DecidableEq, Repr

/-- Built-in middleware categories supported by FastAPI / Starlette. -/
inductive MiddlewareKind where
  | cors
  | gzip
  | httpsRedirect
  | trustedHost
  | http
  deriving DecidableEq, Repr

/-- Response class determining the serialization strategy.
    Uses `Nat` for status codes to avoid import complexity. -/
inductive ResponseClass where
  | json
  | html
  | plainText
  | redirect (defaultStatus : Nat)
  | streaming (mediaType : String)
  | file
  | custom (mediaType : Option String)
  deriving Repr

/-- Key for dispatching exception handlers. -/
inductive ExceptionHandlerKey where
  | statusCode (n : Nat)
  | exceptionClass (name : String)
  deriving DecidableEq, Repr

/-- A segment in a validation error location path. -/
inductive LocSegment where
  | key (s : String)
  | index (n : Nat)
  deriving DecidableEq, Repr

/-- Security scheme descriptors matching FastAPI's security utilities.
    Covers API keys, HTTP auth, OAuth2, and OpenID Connect. -/
inductive SecurityScheme where
  | apiKeyHeader (name : String)
  | apiKeyCookie (name : String)
  | apiKeyQuery (name : String)
  | httpBasic
  | httpBearer (autoError : Bool)
  | httpDigest (autoError : Bool)
  | oauth2PasswordBearer (tokenUrl : String) (scopes : List (String × String)) (autoError : Bool)
  | oauth2AuthorizationCode (authorizationUrl tokenUrl : String) (scopes : List (String × String))
  | openIdConnect (openIdConnectUrl : String)
  deriving Repr

/-- Numeric validation constraints for FastAPI parameter declarations. -/
structure ValidationConstraints where
  gt : Option Int := none
  ge : Option Int := none
  lt : Option Int := none
  le : Option Int := none
  multipleOf : Option Int := none
  minLength : Option Nat := none
  maxLength : Option Nat := none
  pattern : Option String := none
  strict : Option Bool := none
  deriving Repr

/-- CORS middleware configuration (Starlette CORSMiddleware). -/
structure CORSConfig where
  allowOrigins : List String
  allowMethods : List String
  allowHeaders : List String
  allowCredentials : Bool
  allowOriginRegex : Option String
  exposeHeaders : List String
  maxAge : Nat
  deriving Repr

/-- GZip middleware configuration (Starlette GZipMiddleware). -/
structure GZipConfig where
  minimumSize : Nat
  compressLevel : Nat
  deriving Repr

/-- Trusted host middleware configuration (Starlette TrustedHostMiddleware). -/
structure TrustedHostConfig where
  allowedHosts : List String
  wwwRedirect : Bool
  deriving Repr

/-- HTTP Basic credentials (FastAPI security.HTTPBasicCredentials). -/
structure HTTPBasicCredentials where
  username : String
  password : String
  deriving Repr

/-- HTTP Authorization credentials (scheme + token). -/
structure HTTPAuthorizationCredentials where
  scheme : String
  credentials : String
  deriving Repr

/-- OAuth2 password request form fields (FastAPI security.OAuth2PasswordRequestForm). -/
structure OAuth2PasswordRequestForm where
  grantType : Option String
  username : String
  password : String
  scopes : List String
  clientId : Option String
  clientSecret : Option String
  deriving Repr

/-- Declared security scopes for an OAuth2 dependency. -/
structure SecurityScopes where
  scopes : List String
  deriving Repr

/-- HTTP exception raised by endpoint or dependency code.
    Maps to `fastapi.HTTPException`. The `detail` field accepts any
    JSON-serializable value (dict, list, string, etc.). -/
structure HTTPException where
  statusCode : Nat
  detail : JsonValue
  headers : List (String × String)

/-- WebSocket exception raised during WebSocket handling.
    Maps to `fastapi.WebSocketException`. -/
structure WebSocketException where
  code : Nat
  reason : String
  deriving Repr

/-- A single entry in a validation error's detail list. -/
structure ValidationErrorDetail where
  loc : List LocSegment
  msg : String
  type_ : String
  deriving Repr

/-- Request validation error containing one or more detail entries.
    Maps to `fastapi.exceptions.RequestValidationError`. -/
structure RequestValidationError where
  errors : List ValidationErrorDetail
  deriving Repr

/-- A background task to be run after the response is sent.
    Cannot derive `Repr` because `CallableRef` is opaque. -/
structure BackgroundTask where
  func : CallableRef
  description : String

/-- An ordered collection of background tasks. -/
structure BackgroundTasks where
  tasks : List BackgroundTask

end SWELib.Networking.FastApi
