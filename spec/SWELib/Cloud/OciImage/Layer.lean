/-
Copyright (c) 2024 SWELib Contributors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: SWELib Contributors
-/

import SWELib.Cloud.OciImage.Digest

namespace SWELib.Cloud.OciImage

/-!
# OCI Image Layer

Filesystem layer with whiteout semantics for file deletions.

## Whiteout Files

Layers use special tar entries for deletions:
- `.wh.<filename>`: Delete single file/directory
- `.wh..wh..opq`: Delete all files in directory (opaque whiteout)

## References

- [OCI Image Layer](https://github.com/opencontainers/image-spec/blob/main/layer.md)
-/

/-- Type of whiteout entry. -/
inductive WhiteoutType where
  | regular : WhiteoutType  -- Delete single file/directory (.wh.<name>)
  | opaque : WhiteoutType   -- Delete all directory contents (.wh..wh..opq)
  deriving DecidableEq, Repr

/-- Whiteout entry for file deletion. -/
structure WhiteoutEntry where
  /-- Path in tar archive. -/
  path : String
  /-- Type of whiteout. -/
  whiteoutType : WhiteoutType
  deriving DecidableEq, Repr

/-- Filesystem layer. -/
structure Layer where
  /-- Digest of compressed layer blob. -/
  digest : Digest
  /-- Digest of uncompressed layer. -/
  uncompressedDigest : Digest
  /-- Tar archive data (uncompressed). -/
  tarData : ByteArray
  /-- Whiteout entries extracted from tar. -/
  whiteouts : List WhiteoutEntry
  deriving DecidableEq

/-- Check if path is a whiteout file. -/
def isWhiteoutFile (path : String) : Bool :=
  path.contains ".wh."

/-- Check if path is an opaque whiteout. -/
def isOpaqueWhiteout (path : String) : Bool :=
  path.contains ".wh..wh..opq"

/-- Extract whiteout entry from tar path. -/
def extractWhiteout (path : String) : Option WhiteoutEntry :=
  if isOpaqueWhiteout path then
    some ⟨path, .opaque⟩
  else if isWhiteoutFile path then
    some ⟨path, .regular⟩
  else
    none

/-- AXIOM: Apply layer to filesystem state (requires tar library). -/
axiom applyLayer : ByteArray → Layer → ByteArray

/-- AXIOM: Extract whiteouts from tar archive. -/
axiom extractWhiteouts : ByteArray → List WhiteoutEntry

/-- AXIOM: Decompress gzip-compressed blob. -/
axiom decompressGzip : ByteArray → ByteArray

/-- AXIOM: Decompress zstd-compressed blob. -/
axiom decompressZstd : ByteArray → ByteArray

/-- STRUCTURAL: Opaque whiteouts are whiteout files. -/
axiom opaque_is_whiteout (path : String) :
    isOpaqueWhiteout path = true → isWhiteoutFile path = true

/-- REQUIRES_HUMAN: Layer application order matters. -/
axiom layer_order_matters :
  ∀ (fs : ByteArray) (l1 l2 : Layer),
  ∃ (_fs' : ByteArray), applyLayer (applyLayer fs l1) l2 ≠ applyLayer (applyLayer fs l2) l1

/-- REQUIRES_HUMAN: Whiteout files delete paths. -/
axiom whiteout_deletes_path :
  ∀ (fs : ByteArray) (layer : Layer) (entry : WhiteoutEntry),
  entry ∈ layer.whiteouts → entry.whiteoutType = .regular →
  ∃ (fileExists : ByteArray → String → Bool),
  fileExists (applyLayer fs layer) entry.path = false

end SWELib.Cloud.OciImage
