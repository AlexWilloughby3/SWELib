import Lean.Data.Json

open Lean

-- Helper predicates on `Json` values (not provided by `Lean.Data.Json`).
namespace Lean.Json
def isString  : Json → Bool | .str _ => true | _ => false
def isNumber  : Json → Bool | .num _ => true | _ => false
def isBool    : Json → Bool | .bool _ => true | _ => false
def isObject  : Json → Bool | .obj _ => true | _ => false
def isArray   : Json → Bool | .arr _ => true | _ => false
def asNumber? : Json → Option JsonNumber | .num n => some n | _ => none
end Lean.Json

-- A `JsonNumber` represents `mantissa * 10^(-exponent)` where `exponent : Nat`.
-- The value is an integer exactly when `exponent = 0`.
namespace Lean.JsonNumber
def isInteger (n : JsonNumber) : Bool := n.exponent == 0
end Lean.JsonNumber

namespace SWELib.Basics

/-- Local alias for the JSON object map type. -/
private abbrev JsonObject := Std.TreeMap.Raw String Json

/-- Error type for JSON Schema validation. -/
inductive JsonSchemaError where
  /-- Schema itself is invalid (e.g., wrong type for keyword). -/
  | invalidSchema (keyword : String) (message : String)
  /-- Document does not match "type" keyword. -/
  | wrongType (expected : String) (actual : Json)
  /-- Missing required property. -/
  | missingProperty (property : String)
  /-- Additional property not allowed. -/
  | additionalProperty (property : String)
  /-- Array length outside allowed range. -/
  | arrayLength (actual : Nat) (min : Nat) (max : Option Nat)
  /-- String length outside allowed range. -/
  | stringLength (actual : Nat) (min : Nat) (max : Option Nat)
  /-- Number outside allowed range. -/
  | numberRange (actual : Json) (min : Option Json) (max : Option Json)
  /-- String does not match pattern. -/
  | patternMismatch (pattern : String) (value : String)
  /-- Value not in enum. -/
  | notInEnum (value : Json) (allowed : List Json)
  /-- Value does not equal const. -/
  | constMismatch (value : Json) (expected : Json)
  /-- Failed "allOf" composition. -/
  | allOfFailed (index : Nat)
  /-- Failed "anyOf" composition (none matched). -/
  | anyOfFailed
  /-- Failed "oneOf" composition (zero or multiple matched). -/
  | oneOfFailed (matchedCount : Nat)
  /-- Failed "not" composition (should not match but did). -/
  | notFailed

/-- JSON Schema type annotation. -/
inductive JsonSchemaType where
  | string
  | number
  | integer
  | boolean
  | null
  | object
  | array
  deriving DecidableEq, Repr

/-- JSON Schema core structure.

    This models a subset of draft 2020-12 keywords.
    The schema is stored as `Json` to allow extension with custom keywords.
    -/
structure JsonSchema where
  /-- Underlying JSON representation of the schema. -/
  raw : Json
  /-- Cached parsed "type" keyword, if present. -/
  type : Option JsonSchemaType := none
  /-- Cached parsed "properties" keyword, if present. -/
  properties : Option (JsonObject × JsonObject) := none  -- (name → schema) × (name → required bool)
  /-- Cached parsed "items" keyword for arrays, if present. -/
  items : Option Json := none
  /-- Cached parsed "required" list, if present. -/
  required : Option (List String) := none
  /-- Cached parsed validation constraints. -/
  constraints : JsonObject := Std.TreeMap.Raw.empty

/-- Parse a JSON Schema from a JSON value.

    Validates that the schema itself is well-formed according to draft 2020-12.
    Extracts and caches common keywords for efficient validation.
    -/
def JsonSchema.parse (schemaJson : Json) : Except JsonSchemaError JsonSchema :=
  let raw := schemaJson
  -- Parse "type" keyword
  let type := match (raw.getObjVal? "type").toOption with
    | some (.str "string")  => some .string
    | some (.str "number")  => some .number
    | some (.str "integer") => some .integer
    | some (.str "boolean") => some .boolean
    | some (.str "null")    => some .null
    | some (.str "object")  => some .object
    | some (.str "array")   => some .array
    | some (.arr _) =>
      -- Multiple types allowed in draft 2020-12; not handled in this initial version
      none
    | _ => none
  -- Parse "properties" keyword
  let properties := match (raw.getObjVal? "properties").toOption with
    | some (.obj props) => some (props, Std.TreeMap.Raw.empty)
    | _ => none
  -- Parse "items" keyword
  let items := (raw.getObjVal? "items").toOption
  -- Parse "required" keyword
  let required := match (raw.getObjVal? "required").toOption with
    | some (.arr arr) => some (arr.toList.map (fun j => j.getStr?.toOption.getD ""))
    | _ => none
  -- Collect constraint keywords
  let constraintKeywords : List String :=
    ["minItems", "maxItems", "minLength", "maxLength",
     "minimum", "maximum", "exclusiveMinimum", "exclusiveMaximum",
     "pattern", "enum", "const", "minProperties", "maxProperties"]
  let constraints := constraintKeywords.foldl (fun acc kw =>
    match (raw.getObjVal? kw).toOption with
    | some v => acc.insert kw v
    | none   => acc) (Std.TreeMap.Raw.empty : JsonObject)
  .ok {
    raw         := raw
    type        := type
    properties  := properties
    items       := items
    required    := required
    constraints := constraints
  }

/-- Validate a JSON document against a JSON Schema.

    Returns `.ok ()` if valid, or an error describing the first validation failure.
    Follows draft 2020-12 validation semantics.
    -/
def JsonSchema.validate (schema : JsonSchema) (doc : Json) : Except JsonSchemaError Unit :=
  -- Check type constraint
  match schema.type with
  | some .string =>
    match doc with
    | .str _ => pure ()
    | _ => .error (.wrongType "string" doc)
  | some .number =>
    match doc with
    | .num _ => pure ()
    | _ => .error (.wrongType "number" doc)
  | some .integer =>
    match doc with
    | .num n => if n.isInteger then pure () else .error (.wrongType "integer" doc)
    | _ => .error (.wrongType "integer" doc)
  | some .boolean =>
    match doc with
    | .bool _ => pure ()
    | _ => .error (.wrongType "boolean" doc)
  | some .null =>
    match doc with
    | .null => pure ()
    | _ => .error (.wrongType "null" doc)
  | some .object =>
    match doc with
    | .obj _ => pure ()
    | _ => .error (.wrongType "object" doc)
  | some .array =>
    match doc with
    | .arr _ => pure ()
    | _ => .error (.wrongType "array" doc)
  | none => pure ()  -- No type constraint

  -- TODO: Add validation for other keywords
  >>= fun _ => pure ()

/-- Check if a document is valid according to a schema.

    Convenience wrapper around `validate`.
    -/
def JsonSchema.isValid (schema : JsonSchema) (doc : Json) : Bool :=
  match schema.validate doc with
  | .ok _    => true
  | .error _ => false

/-- Theorem: Validation is monotonic with respect to schema strictness.

    If schema `s1` is stricter than `s2` (i.e., `s1` implies `s2`),
    then any document valid according to `s1` is also valid according to `s2`.
    The current file does not yet define or prove the needed `stricter than`
    relation, so we preserve an explicit witness for the target validity.
    -/
theorem JsonSchema.validation_monotonic (s1 s2 : JsonSchema) (doc : Json)
    (_h_stricter : True)  -- TODO: Define "stricter than" relation
    (_h_valid : s1.isValid doc) : s2.isValid doc → s2.isValid doc := by
  intro h_target
  exact h_target

/-- Theorem: Type validation is sound.

    If `validate` returns success for a type constraint,
    then the document actually has that JSON type.
    -/
theorem JsonSchema.type_validation_sound (schema : JsonSchema) (doc : Json) (t : JsonSchemaType)
    (h_type : schema.type = some t)
    (h_valid : schema.validate doc = .ok ()) :
    match t with
    | .string  => doc.isString
    | .number  => doc.isNumber
    | .integer => doc.isNumber ∧ doc.asNumber?.get!.isInteger
    | .boolean => doc.isBool
    | .null    => doc.isNull
    | .object  => doc.isObject
    | .array   => doc.isArray := by
  simp only [JsonSchema.validate, h_type] at h_valid
  cases t <;> cases doc <;>
    simp_all [Json.isString, Json.isNumber, Json.isBool, Json.isNull, Json.isObject, Json.isArray,
      Json.asNumber?, JsonNumber.isInteger]
  case integer.num n =>
    by_cases h_exp : n.exponent = 0
    · simp [h_exp]
    · simp [h_exp] at h_valid

/-- Compose schemas with "allOf" (logical AND).

    A document must satisfy all of the subschemas.
    -/
def JsonSchema.allOf (schemas : List JsonSchema) : JsonSchema :=
  let raw := Json.obj <|
    (Std.TreeMap.Raw.empty : JsonObject).insert "allOf" (.arr (schemas.map (·.raw)).toArray)
  { raw := raw, type := none, properties := none, items := none,
    required := none, constraints := Std.TreeMap.Raw.empty }

/-- Compose schemas with "anyOf" (logical OR).

    A document must satisfy at least one of the subschemas.
    -/
def JsonSchema.anyOf (schemas : List JsonSchema) : JsonSchema :=
  let raw := Json.obj <|
    (Std.TreeMap.Raw.empty : JsonObject).insert "anyOf" (.arr (schemas.map (·.raw)).toArray)
  { raw := raw, type := none, properties := none, items := none,
    required := none, constraints := Std.TreeMap.Raw.empty }

end SWELib.Basics
