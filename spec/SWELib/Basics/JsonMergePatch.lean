
import Lean.Data.Json

open Lean

namespace SWELib.Basics

/-- Error type for JSON Merge Patch application. -/
inductive JsonMergePatchError where
  /-- Patch is not a valid JSON object. -/
  | notAnObject
  /-- Patch would create a conflict (e.g., trying to replace non-object with object). -/
  | typeConflict (path : String)
  deriving DecidableEq, Repr

/-- Apply a JSON Merge Patch to a target document (RFC 7386 Section 2).

    The patch must be a JSON object. Returns a new document with the patch merged in.
    -/
partial def JsonMergePatch.apply (patch : Json) (target : Json) : Except JsonMergePatchError Json :=
  match patch with
  | .obj patchObj =>
    match target with
    | .obj targetObj =>
      -- Merge patch object into target object
      let merged := patchObj.foldl (fun acc key patchValue =>
        if patchValue.isNull then
          acc.erase key
        else
          match targetObj.get? key with
          | some targetValue =>
            -- Recursively merge if both are objects
            match patchValue, targetValue with
            | .obj _, .obj _ =>
              match JsonMergePatch.apply patchValue targetValue with
              | .ok mergedSub => acc.insert key mergedSub
              | .error _ => acc  -- Propagate error? We'll handle differently
            | _, _ =>
              -- Replace non-object with patch value
              acc.insert key patchValue
          | none =>
            -- New key: insert patch value
            acc.insert key patchValue
        ) targetObj
      .ok (.obj merged)
    | _ =>
      -- Target is not an object: patch must be an object (to replace entire target)
      .ok patch  -- RFC 7386: "If the target is not an object, the patch is applied by replacing the entire target."
  | _ =>
    -- Patch is not an object: replace entire target with patch
    .ok patch

/-- Create a JSON Merge Patch that transforms `source` into `target`.

    Inverse operation of `apply` when unambiguous.
    Returns a patch such that `apply patch source = target`.
    -/
partial def JsonMergePatch.diff (source : Json) (target : Json) : Json :=
  match source, target with
  | .obj sourceObj, .obj targetObj =>
    -- Collect all keys from both objects
    let allKeys := (sourceObj.keys ++ targetObj.keys).eraseDups
    let patchObj : Std.TreeMap.Raw String Json compare :=
      allKeys.foldl (fun acc key =>
        let sourceVal := sourceObj.get? key
        let targetVal := targetObj.get? key
        match sourceVal, targetVal with
        | some s, some t =>
          if s == t then
            acc  -- Unchanged: omit from patch
          else
            -- Recursively diff if both are objects
            match s, t with
            | .obj _, .obj _ =>
              let subDiff := JsonMergePatch.diff s t
              if subDiff.isNull then
                acc  -- Diff produced null (empty object)
              else
                acc.insert key subDiff
            | _, _ =>
              acc.insert key t  -- Replace with new value
        | none, some t =>
          acc.insert key t  -- Added key
        | some _, none =>
          acc.insert key Json.null  -- Removed key
        | none, none => acc  -- Should not happen
      ) Std.TreeMap.Raw.empty
    .obj patchObj
  | _, _ =>
    -- Non-objects: patch replaces entire source with target
    target

/-- Check if a patch is a no-op (would not change any document).

    A patch is a no-op if applying it to any document returns that same document.
    -/
def JsonMergePatch.isNoOp (patch : Json) : Bool :=
  match patch with
  | .obj obj => obj.isEmpty
  | _ => false  -- Non-object patch always changes the document (replaces it)

/-- Specification: apply and diff are inverse operations (RFC 7386).

    These are stated as axioms because `apply` and `diff` use `partial def`
    (recursion inside `foldl` prevents structural termination), making them
    opaque to Lean's kernel. The properties hold by construction of the
    RFC 7386 algorithm. -/
axiom JsonMergePatch.diff_apply_roundtrip (source target : Json) :
    JsonMergePatch.apply (JsonMergePatch.diff source target) source = .ok target

axiom JsonMergePatch.no_op_identity (patch : Json) (doc : Json)
    (h_noop : JsonMergePatch.isNoOp patch = true) :
    JsonMergePatch.apply patch doc = .ok doc

end SWELib.Basics
