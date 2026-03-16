/-
Copyright (c) 2024 SWELib Contributors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: SWELib Contributors
-/

namespace SWELib.Cloud.OciImage

/-!
# OCI Image Errors

Error conditions for OCI Image operations.

## Error Categories

- **Validation errors**: Digest mismatch, size mismatch, invalid schema
- **Resolution errors**: No platform match, missing platform
- **Layer errors**: Invalid whiteout, layer application failed
-/

/-- Error conditions for OCI Image operations. -/
inductive ImageError where
  | digestMismatch (expected : String) (actual : String)
  | sizeMismatch (expected : Int) (actual : Int)
  | invalidMediaType (mediaType : String)
  | invalidSchemaVersion (version : Nat)
  | missingPlatform (descriptor : String)
  | noPlatformMatch (platform : String)
  | invalidWhiteout (path : String)
  | layerApplicationFailed (reason : String)
  | manifestNotFound (digest : String)
  | invalidAnnotation (key : String) (reason : String)
  deriving Repr

instance : ToString ImageError where
  toString err := match err with
    | .digestMismatch exp act => s!"Digest mismatch: expected {exp}, got {act}"
    | .sizeMismatch exp act => s!"Size mismatch: expected {exp}, got {act}"
    | .invalidMediaType mt => s!"Invalid media type: {mt}"
    | .invalidSchemaVersion v => s!"Invalid schema version: {v} (expected 2)"
    | .missingPlatform d => s!"Missing platform in descriptor: {d}"
    | .noPlatformMatch p => s!"No manifest matches platform: {p}"
    | .invalidWhiteout path => s!"Invalid whiteout file: {path}"
    | .layerApplicationFailed reason => s!"Layer application failed: {reason}"
    | .manifestNotFound digest => s!"Manifest not found: {digest}"
    | .invalidAnnotation key reason => s!"Invalid annotation {key}: {reason}"

/-- Check if error is a validation error. -/
def ImageError.isValidationError (err : ImageError) : Bool :=
  match err with
  | .digestMismatch .. | .sizeMismatch .. | .invalidMediaType ..
  | .invalidSchemaVersion .. | .invalidAnnotation .. => true
  | _ => false

/-- Check if error is a resolution error. -/
def ImageError.isResolutionError (err : ImageError) : Bool :=
  match err with
  | .missingPlatform .. | .noPlatformMatch .. | .manifestNotFound .. => true
  | _ => false

/-- Check if error is a layer error. -/
def ImageError.isLayerError (err : ImageError) : Bool :=
  match err with
  | .invalidWhiteout .. | .layerApplicationFailed .. => true
  | _ => false

end SWELib.Cloud.OciImage