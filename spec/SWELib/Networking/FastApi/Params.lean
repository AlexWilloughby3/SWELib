import SWELib.Networking.FastApi.Preamble
import SWELib.Networking.FastApi.Types

/-!
# FastAPI Parameter Descriptors

Structures modelling FastAPI's `Query`, `Path`, `Header`, `Cookie`, `Body`,
`Form`, and `File` parameter declarations.

## References
- FastAPI: <https://fastapi.tiangolo.com/tutorial/query-params/>
- FastAPI: <https://fastapi.tiangolo.com/tutorial/body/>
-/

namespace SWELib.Networking.FastApi

/-- Descriptor for a declared request parameter (path, query, header, cookie). -/
structure ParamDescriptor where
  source : ParamSource
  name : String
  alias : Option String := none
  required : Bool := true
  default_ : Option String := none
  title : Option String := none
  description : Option String := none
  deprecated : Bool := false
  includeInSchema : Bool := true
  constraints : ValidationConstraints := {}
  deriving Repr

/-- Descriptor for a request body parameter with media type and embed flag. -/
structure BodyDescriptor where
  base : ParamDescriptor
  mediaType : String
  embed : Bool := false
  deriving Repr

/-- Descriptor for a header parameter with underscore conversion control. -/
structure HeaderParam where
  base : ParamDescriptor
  convertUnderscores : Bool := true
  deriving Repr

end SWELib.Networking.FastApi
