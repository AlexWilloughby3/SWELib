/-
Copyright (c) 2024 SWELib Contributors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: SWELib Contributors
-/

import SWELib.Cloud.OciImage.Descriptor
import SWELib.Cloud.OciImage.Annotations
import SWELib.Cloud.OciImage.MediaType
import SWELib.Cloud.OciImage.Platform

namespace SWELib.Cloud.OciImage

/-!
# OCI Image Index

Multi-platform image index for selecting platform-specific manifests.

## Structure

Contains list of manifest descriptors, each with platform metadata.
Used for multi-architecture images (e.g., linux/amd64, linux/arm64).

## Constraints

- Schema version must be 2
- Must have at least one manifest
- All manifests must have platform field

## References

- [OCI Image Index](https://github.com/opencontainers/image-spec/blob/main/image-index.md)
-/

/-- Multi-platform image index. -/
structure ImageIndex where
  /-- Schema version (must be 2). -/
  schemaVersion : Nat
  /-- Media type (must be index media type). -/
  mediaType : MediaType
  /-- Manifest descriptors with platform info. -/
  manifests : List Descriptor
  /-- Optional annotations. -/
  annotations : Option Annotations := none

  /-- Proof: schema version is 2. -/
  h_schema : schemaVersion = 2
  /-- Proof: media type is index type. -/
  h_media : mediaType = mediaTypeImageIndex
  /-- Proof: at least one manifest. -/
  h_manifests_nonempty : manifests ≠ []
  /-- Proof: all manifests have media type. -/
  h_manifests_media : ∀ d ∈ manifests, d.mediaType = mediaTypeImageManifest
  /-- Proof: all manifests have platform. -/
  h_manifests_platform : ∀ d ∈ manifests, d.platform.isSome

/-- Find first manifest matching platform. -/
def ImageIndex.selectManifest (idx : ImageIndex) (p : Platform) : Option Descriptor :=
  idx.manifests.find? (fun d =>
    match d.platform with
    | some plat => plat.matches p
    | none => false)

/-- STRUCTURAL: All indexes have schema version 2. -/
theorem ImageIndex.schema_is_v2 (idx : ImageIndex) :
    idx.schemaVersion = 2 := by
  exact idx.h_schema

/-- STRUCTURAL: All indexes have at least one manifest. -/
theorem ImageIndex.has_manifests (idx : ImageIndex) :
    idx.manifests ≠ [] := by
  exact idx.h_manifests_nonempty

/-- STRUCTURAL: All manifests have platform metadata. -/
theorem ImageIndex.manifests_have_platform (idx : ImageIndex) :
    ∀ d ∈ idx.manifests, d.platform.isSome := by
  exact idx.h_manifests_platform

/-- ALGEBRAIC: Selected manifest is from index. -/
theorem ImageIndex.selectManifest_in_list (idx : ImageIndex) (p : Platform) (d : Descriptor) :
    idx.selectManifest p = some d → d ∈ idx.manifests := by
  intro h
  unfold ImageIndex.selectManifest at h
  exact List.mem_of_find?_eq_some h

end SWELib.Cloud.OciImage
