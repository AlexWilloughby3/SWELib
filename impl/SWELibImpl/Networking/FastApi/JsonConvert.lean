import SWELib
import Lean.Data.Json

/-!
# FastAPI JSON Conversion

Bidirectional conversion between the spec's `JsonValue` type and `Lean.Json`,
plus serialization of `HTTPException` and `RequestValidationError` to their
standard FastAPI JSON response formats.
-/

namespace SWELibImpl.Networking.FastApi.JsonConvert

open SWELib.Networking.FastApi
open Lean (Json)

instance : Inhabited JsonValue := ⟨.null⟩

/-- Convert a spec `JsonValue` to `Lean.Json`. -/
partial def jsonValueToLean : JsonValue → Json
  | .null => .null
  | .bool b => .bool b
  | .num n => .num (Lean.JsonNumber.fromInt n)
  | .str s => .str s
  | .arr items => .arr (items.map jsonValueToLean).toArray
  | .obj fields => Json.mkObj (fields.map fun (k, v) => (k, jsonValueToLean v))

/-- Convert `Lean.Json` to a spec `JsonValue`. -/
partial def leanToJsonValue : Json → JsonValue
  | .null => .null
  | .bool b => .bool b
  | .num n => .num n.mantissa
  | .str s => .str s
  | .arr items => .arr (items.toList.map leanToJsonValue)
  | .obj fields => .obj (fields.toList.map fun (k, v) => (k, leanToJsonValue v))

/-- Serialize a `JsonValue` to a JSON string. -/
def jsonValueToString (v : JsonValue) : String :=
  (jsonValueToLean v).pretty

/-- Serialize an `HTTPException` to the standard FastAPI JSON format:
    `{"detail": <detail>}` -/
def httpExceptionToJson (e : HTTPException) : Json :=
  Json.mkObj [("detail", jsonValueToLean e.detail)]

/-- Serialize a `LocSegment` to a JSON value. -/
def locSegmentToJson : LocSegment → Json
  | .key s => .str s
  | .index n => .num (Lean.JsonNumber.fromNat n)

/-- Serialize a `ValidationErrorDetail` to JSON. -/
def validationErrorDetailToJson (d : ValidationErrorDetail) : Json :=
  Json.mkObj [
    ("loc", .arr (d.loc.map locSegmentToJson).toArray),
    ("msg", .str d.msg),
    ("type", .str d.type_)
  ]

/-- Serialize a `RequestValidationError` to the standard FastAPI 422 format:
    `{"detail": [{"loc": [...], "msg": "...", "type": "..."}]}` -/
def validationErrorToJson (e : RequestValidationError) : Json :=
  Json.mkObj [("detail", .arr (e.errors.map validationErrorDetailToJson).toArray)]

end SWELibImpl.Networking.FastApi.JsonConvert
