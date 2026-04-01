import SWELib
import Lean.Data.Json
import SWELibImpl.Networking.FastApi.JsonConvert

/-!
# FastAPI OpenAPI Generator

Generates an OpenAPI 3.1 JSON document from a `FastAPIApp`'s metadata and
route declarations. Serializes the spec's `OpenAPISchema` to `Lean.Json`.

Note: `SchemaObject` is opaque in the spec, so request/response schemas
are emitted as empty `{}` placeholders.
-/

namespace SWELibImpl.Networking.FastApi.OpenAPIGenerator

open SWELib.Networking.FastApi
open SWELib.Networking.Http
open Lean (Json)

/-- Convert a `ParamSource` to the OpenAPI `in` field string. -/
private def paramSourceToString : ParamSource → String
  | .path => "path"
  | .query => "query"
  | .header => "header"
  | .cookie => "cookie"
  | .body => "body"
  | .form => "formData"
  | .file => "file"

/-- Serialize a `ServerEntry` to JSON. -/
private def serverEntryToJson (s : ServerEntry) : Json :=
  let fields := [("url", Json.str s.url)]
  let fields := match s.description with
    | some d => fields ++ [("description", .str d)]
    | none => fields
  Json.mkObj fields

/-- Build the OpenAPI operation object for a `PathOperation`. -/
private def pathOperationToJson (op : PathOperation) : Json :=
  let fields : List (String × Json) := []
  let fields := match op.operationId with
    | some id => fields ++ [("operationId", .str id)]
    | none => fields
  let fields := if op.tags.isEmpty then fields
    else fields ++ [("tags", .arr (op.tags.map .str).toArray)]
  let fields := match op.summary with
    | some s => fields ++ [("summary", .str s)]
    | none => fields
  let fields := match op.description with
    | some d => fields ++ [("description", .str d)]
    | none => fields
  let fields := if op.deprecated
    then fields ++ [("deprecated", .bool true)]
    else fields
  -- Parameters from path template
  let paramNames := op.path.paramNames
  let params := paramNames.map fun name =>
    Json.mkObj [
      ("name", .str name),
      ("in", .str "path"),
      ("required", .bool true),
      ("schema", Json.mkObj [])  -- opaque SchemaObject → empty
    ]
  let fields := if params.isEmpty then fields
    else fields ++ [("parameters", .arr params.toArray)]
  -- Default response
  let fields := fields ++ [("responses", Json.mkObj [
    (toString op.statusCode, Json.mkObj [
      ("description", .str "Successful Response")
    ])
  ])]
  Json.mkObj fields

/-- Group path operations by their path template string. -/
private def groupByPath (ops : List PathOperation)
    : List (String × List (String × Json)) :=
  ops.foldl (init := ([] : List (String × List (String × Json)))) fun acc op =>
    let pathStr := op.path.raw
    let methodEntry := (op.method.toLower, pathOperationToJson op)
    match acc.find? (·.1 == pathStr) with
    | some _ => acc.map fun (p, methods) =>
        if p == pathStr then (p, methods ++ [methodEntry]) else (p, methods)
    | none => acc ++ [(pathStr, [methodEntry])]

/-- Generate the `OpenAPISchema` from a `FastAPIApp`. -/
def generateOpenAPISchema (app : FastAPIApp) : OpenAPISchema :=
  {
    openapi := app.openApiVersion
    info := {
      title := app.title
      version := app.version
      description := app.description
    }
    servers := app.servers
    tags := app.router.tags
  }

/-- Serialize a `FastAPIApp` to an OpenAPI JSON document. -/
def openAPISchemaToJson (app : FastAPIApp) : Json :=
  let infoFields : List (String × Json) := [
    ("title", .str app.title),
    ("version", .str app.version)
  ]
  let infoFields := match app.description with
    | some d => infoFields ++ [("description", .str d)]
    | none => infoFields
  let info := Json.mkObj infoFields
  -- Build paths
  let pathGroups := groupByPath app.router.routes
  let pathsEntries := pathGroups.map fun (pathStr, methods) =>
    (pathStr, Json.mkObj methods)
  let paths := Json.mkObj pathsEntries
  -- Build servers
  let servers := Json.arr (app.servers.map serverEntryToJson).toArray
  -- Assemble top-level document
  let fields : List (String × Json) := [
    ("openapi", .str app.openApiVersion),
    ("info", info),
    ("paths", paths)
  ]
  let fields := if app.servers.isEmpty then fields
    else fields ++ [("servers", servers)]
  Json.mkObj fields

/-- Serve the OpenAPI JSON document as an HTTP response. -/
def serveOpenAPI (app : FastAPIApp) : IO Response :=
  let json := openAPISchemaToJson app
  pure {
    status := StatusCode.ok
    headers := [{ name := FieldName.contentType, value := "application/json" }]
    body := some json.pretty.toUTF8
  }

end SWELibImpl.Networking.FastApi.OpenAPIGenerator
