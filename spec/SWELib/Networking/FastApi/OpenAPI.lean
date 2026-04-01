import SWELib.Networking.FastApi.Preamble
import SWELib.Networking.FastApi.Types
import SWELib.Networking.FastApi.Routing

/-!
# FastAPI OpenAPI Schema Types

Data structures representing the OpenAPI 3.1 schema that FastAPI generates
from route declarations.

## References
- OpenAPI Specification 3.1: <https://spec.openapis.org/oas/v3.1.0>
- FastAPI: <https://fastapi.tiangolo.com/tutorial/metadata/>
-/

namespace SWELib.Networking.FastApi

/-- The `info` object of an OpenAPI document. -/
structure OpenAPIInfo where
  title : String
  version : String
  description : Option String := none
  deriving Repr

/-- An OpenAPI parameter object. -/
structure OpenAPIParameter where
  name : String
  location : ParamSource
  required : Bool
  schema : SchemaObject

/-- An OpenAPI request body object. -/
structure OpenAPIRequestBody where
  content : SchemaObject
  required : Bool

/-- An OpenAPI operation object (one HTTP method on one path). -/
structure OpenAPIOperation where
  operationId : Option String := none
  tags : List String := []
  summary : Option String := none
  description : Option String := none
  parameters : List OpenAPIParameter := []
  requestBody : Option OpenAPIRequestBody := none
  responses : List (String × SchemaObject) := []
  security : List (String × List String) := []
  deprecated : Bool := false

/-- The top-level OpenAPI document structure. -/
structure OpenAPISchema where
  openapi : String := "3.1.0"
  info : OpenAPIInfo
  paths : List (String × List (String × OpenAPIOperation)) := []
  components : List (String × SchemaObject) := []
  servers : List ServerEntry := []
  tags : List String := []
  webhooks : List (String × List (String × OpenAPIOperation)) := []

end SWELib.Networking.FastApi
