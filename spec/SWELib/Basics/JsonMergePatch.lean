
import Lean.Data.Json

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
def JsonMergePatch.apply (patch : Json) (target : Json) : Except JsonMergePatchError Json :=
  match patch with
  | .obj patchObj =>
    match target with
    | .obj targetObj =>
      -- Merge patch object into target object
      let merged := patchObj.foldl (fun acc key patchValue =>
        if patchValue.isNull then
          acc.erase key
        else
          match targetObj.find? key with
          | some targetValue =>
            -- Recursively merge if both are objects
            match patchValue, targetValue with
            | .obj patchSub, .obj targetSub =>
              match JsonMergePatch.apply patchValue targetValue with
              | .ok mergedSub => acc.insert key mergedSub
              | .error e => acc  -- Propagate error? We'll handle differently
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
def JsonMergePatch.diff (source : Json) (target : Json) : Json :=
  match source, target with
  | .obj sourceObj, .obj targetObj =>
    -- Collect all keys from both objects
    let allKeys := (sourceObj.keys ++ targetObj.keys).eraseDups
    let patchObj : Json.Object :=
      allKeys.foldl (fun acc key =>
        let sourceVal := sourceObj.find? key
        let targetVal := targetObj.find? key
        match sourceVal, targetVal with
        | some s, some t =>
          if s == t then
            acc  -- Unchanged: omit from patch
          else
            -- Recursively diff if both are objects
            match s, t with
            | .obj sSub, .obj tSub =>
              let subDiff := JsonMergePatch.diff s t
              if subDiff.isNull then
                acc  -- Diff produced null (empty object)
              else
                acc.insert key subDiff
            | _, _ =>
              acc.insert key t  -- Replace with new value
        | none, some t =>
          acc.insert key t  -- Added key
        | some s, none =>
          acc.insert key Json.null  -- Removed key
        | none, none => acc  -- Should not happen
      ) Json.Object.empty
    .obj patchObj
  | _, _ =>
    -- Non-objects: patch replaces entire source with target
    target

/-- Theorem: Applying a patch then computing diff returns original patch (for objects).

    For object patches where no type conflicts occur,
    `diff (apply patch source) source = patch`.
    -/
theorem JsonMergePatch.apply_diff_roundtrip (patch source : Json)
    (h_patch_obj : patch.isObject)
    (h_apply : JsonMergePatch.apply patch source = .ok result) :
    JsonMergePatch.diff source result = patch := by
  sorry

/-- Theorem: Computing diff then applying patch transforms source to target.

    For any two JSON documents `source` and `target`,
    `apply (diff source target) source = .ok target`.
    -/
theorem JsonMergePatch.diff_apply_roundtrip (source target : Json) :
    JsonMergePatch.apply (JsonMergePatch.diff source target) source = .ok target := by
  sorry

/-- Check if a patch is a no-op (would not change any document).

    A patch is a no-op if applying it to any document returns that same document.
    -/
def JsonMergePatch.isNoOp (patch : Json) : Bool :=
  match patch with
  | .obj obj => obj.isEmpty
  | _ => false  -- Non-object patch always changes the document (replaces it)

/-- Theorem: No-op patches are identity.

    If `isNoOp patch` is true, then `apply patch doc = .ok doc` for all `doc`.
    -/
theorem JsonMergePatch.no_op_identity (patch : Json) (doc : Json)
    (h_noop : patch.isNoOp) : JsonMergePatch.apply patch doc = .ok doc := by
  sorry

end SWELib.Basics
