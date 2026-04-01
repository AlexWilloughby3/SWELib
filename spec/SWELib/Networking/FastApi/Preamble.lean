/-!
# FastAPI Preamble

Opaque surrogates for Python runtime concepts used throughout the FastAPI
formalization.

## References
- FastAPI: <https://fastapi.tiangolo.com/>
- ASGI Specification: <https://asgi.readthedocs.io/en/latest/specs/main.html>
-/

namespace SWELib.Networking.FastApi

/-- Surrogate for a Python callable identity (endpoint function, dependency, etc.).
    Opaque because the spec layer does not model Python execution. -/
opaque CallableRef : Type

/-- Callable references support identity equality (Python `is` semantics). -/
@[instance] axiom instBEqCallableRef : BEq CallableRef

/-- Callable references support decidable equality. -/
@[instance] axiom instDecidableEqCallableRef : DecidableEq CallableRef

/-- Surrogate for a JSON Schema leaf node used in OpenAPI schema generation.
    Opaque because full JSON Schema modelling is out of scope. -/
opaque SchemaObject : Type

end SWELib.Networking.FastApi
