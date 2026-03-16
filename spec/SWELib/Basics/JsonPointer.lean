
import Lean.Data.Json

namespace SWELib.Basics

open Lean

/-- Error type for JSON Pointer resolution. -/
inductive JsonPointerError where
  /-- Pointer syntax is invalid (e.g., token not properly escaped). -/
  | invalidSyntax
  /-- Reference token targets a property that does not exist. -/
  | propertyNotFound (property : String)
  /-- Reference token targets an array index that is out of bounds. -/
  | indexOutOfBounds (index : Nat) (arraySize : Nat)
  /-- Reference token expects an object but value is not an object. -/
  | notAnObject
  /-- Reference token expects an array but value is not an array. -/
  | notAnArray
  deriving DecidableEq, Repr

/-- A JSON Pointer is a sequence of reference tokens. -/
structure JsonPointer where
  /-- Tokens in order from root to target. Empty list means root pointer "". -/
  tokens : List String := []
  deriving DecidableEq, Repr

/-- Parse a JSON Pointer string according to RFC 6901 Section 3.

    Grammar:
      json-pointer    = *( "/" reference-token )
      reference-token = *( unescaped / escaped )
      unescaped       = %x00-2E / %x30-7D / %x7F-10FFFF
        ; any Unicode character except "/" (~) and %x00-1F control chars
      escaped         = "~" ( "0" / "1" )
        ; "~0" represents "~"
        ; "~1" represents "/"

    The empty string is a valid pointer referencing the entire document.
    -/
def JsonPointer.parse (s : String) : Except JsonPointerError JsonPointer :=
  if s == "" then
    .ok ⟨[]⟩
  else if ¬ s.startsWith "/" then
    .error .invalidSyntax
  else
    let parts := s.splitOn "/"
    -- First element is empty because string starts with "/"
    let tokens := parts.tail!
    let processToken (token : String) : Except JsonPointerError String :=
      let chars := token.toList
      let rec go (cs : List Char) (acc : List Char) : Except JsonPointerError String :=
        match cs with
        | [] => .ok (String.ofList acc.reverse)
        | '~' :: '0' :: rest => go rest ('~' :: acc)
        | '~' :: '1' :: rest => go rest ('/' :: acc)
        | '~' :: _ => .error .invalidSyntax
        | c :: rest => go rest (c :: acc)
      go chars []
    match tokens.mapM processToken with
    | .ok ts => .ok ⟨ts⟩
    | .error e => .error e

/-- Serialize a JSON Pointer to its string representation (RFC 6901 Section 5).

    Inverse of `parse` for valid pointers.
    -/
def JsonPointer.toString (p : JsonPointer) : String :=
  if p.tokens.isEmpty then
    ""
  else
    let escapeToken (token : String) : String :=
      token.foldl (fun acc c =>
        match c with
        | '~' => acc ++ "~0"
        | '/' => acc ++ "~1"
        | _ => acc.push c) ""
    "/" ++ String.intercalate "/" (p.tokens.map escapeToken)

/-- Walk a list of reference tokens into a JSON value (RFC 6901 Section 4).
    Extracted as a top-level function to enable inductive proofs. -/
def JsonPointer.resolveAux (tokens : List String) (current : Json)
    : Except JsonPointerError Json :=
  match tokens with
  | [] => .ok current
  | token :: rest =>
    match current with
    | .obj obj =>
      match obj.get? token with
      | some next => resolveAux rest next
      | none => .error (.propertyNotFound token)
    | .arr arr =>
      match String.toNat? token with
      | some idx =>
        if h : idx < arr.size then
          resolveAux rest (arr[idx])
        else
          .error (.indexOutOfBounds idx arr.size)
      | none => .error (.propertyNotFound token)
    | _ => .error .notAnObject

/-- Resolve a JSON Pointer against a JSON value (RFC 6901 Section 4).

    Returns the referenced value, or an error if the pointer cannot be resolved.
    -/
def JsonPointer.resolve (ptr : JsonPointer) (doc : Json) : Except JsonPointerError Json :=
  resolveAux ptr.tokens doc

/-- `resolveAux` distributes over list append via monadic bind. -/
theorem JsonPointer.resolveAux_append (ts1 ts2 : List String) (j : Json) :
    resolveAux (ts1 ++ ts2) j = (resolveAux ts1 j).bind (resolveAux ts2) := by
  induction ts1 generalizing j with
  | nil => simp [resolveAux, Except.bind]
  | cons token rest ih =>
    simp only [List.cons_append]
    unfold resolveAux
    split
    · -- j = .obj obj
      rename_i obj
      split
      · -- obj.get? token = some next
        rename_i next _
        exact ih next
      · -- obj.get? token = none
        simp [Except.bind]
    · -- j = .arr arr
      rename_i arr
      split
      · -- toNat? = some idx
        rename_i idx _
        split
        · -- idx < arr.size
          rename_i h
          exact ih (arr[idx])
        · -- idx >= arr.size
          simp [Except.bind]
      · -- toNat? = none
        simp [Except.bind]
    · -- j is not obj or arr
      simp [Except.bind]

/-- Theorem: Parsing then serializing returns original string for valid pointers.

    `parse` and `toString` are inverses for syntactically valid pointers.
    -/
theorem JsonPointer.parse_toString_roundtrip (s : String) (p : JsonPointer)
    (h : JsonPointer.parse s = .ok p) : p.toString = s := by
  sorry

/-- Theorem: Serializing then parsing returns original pointer.

    `toString` and `parse` are inverses.
    -/
theorem JsonPointer.toString_parse_roundtrip (p : JsonPointer) :
    JsonPointer.parse p.toString = .ok p := by
  sorry

/-- Theorem: Resolution is compositional.

    If pointer `p` resolves to value `v` in document `d`,
    and pointer `q` resolves within `v` to value `w`,
    then the concatenated pointer `p ++ q` resolves in `d` to `w`.
    -/
theorem JsonPointer.resolve_append (p q : JsonPointer) (d : Json) (v w : Json)
    (hp : p.resolve d = .ok v) (hq : q.resolve v = .ok w) :
    (⟨p.tokens ++ q.tokens⟩ : JsonPointer).resolve d = .ok w := by
  unfold resolve at hp hq |-
  rw [resolveAux_append]
  rw [hp]
  simp [Except.bind]
  exact hq

end SWELib.Basics
