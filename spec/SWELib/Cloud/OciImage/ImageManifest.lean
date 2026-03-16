/-
Copyright (c) 2024 SWELib Contributors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: SWELib Contributors
-/

import SWELib.Cloud.OciImage.Descriptor
import SWELib.Cloud.OciImage.Annotations
import SWELib.Cloud.OciImage.MediaType

namespace SWELib.Cloud.OciImage

/-!
# OCI Image Manifest

Single-platform container image manifest.

## Structure

References:
- One ImageConfig (runtime configuration)
- One or more Layers (filesystem changesets)
- Optional annotations

## Constraints

- Schema version must be 2
- Must have at least one layer
- Config must be ImageConfig media type
- Layers must be layer media types

## References

- [OCI Image Manifest](https://github.com/opencontainers/image-spec/blob/main/manifest.md)
-/

/-- Single-platform container image manifest. -/
structure ImageManifest where
  /-- Schema version (must be 2). -/
  schemaVersion : Nat
  /-- Media type (must be manifest media type). -/
  mediaType : MediaType
  /-- Configuration descriptor. -/
  config : Descriptor
  /-- Layer descriptors (ordered base to top). -/
  layers : List Descriptor
  /-- Optional annotations. -/
  annotations : Option Annotations := none

  /-- Proof: schema version is 2. -/
  h_schema : schemaVersion = 2
  /-- Proof: media type is manifest type. -/
  h_media : mediaType = mediaTypeImageManifest
  /-- Proof: config media type is correct. -/
  h_config_media : config.mediaType = mediaTypeImageConfig
  /-- Proof: at least one layer. -/
  h_layers_nonempty : layers ≠ []
  /-- Proof: all layers have layer media type. -/
  h_layers_media : ∀ d ∈ layers, isLayerType d.mediaType = true

/-- Build manifest with validation. -/
def ImageManifest.build (config : Descriptor) (layers : List Descriptor)
    (annotations : Option Annotations := none) : Option ImageManifest :=
  if h_nonempty : layers ≠ [] then
    if h_config : config.mediaType = mediaTypeImageConfig then
      if h_layers : ∀ d ∈ layers, isLayerType d.mediaType then
        some { schemaVersion := 2
             , mediaType := mediaTypeImageManifest
             , config := config
             , layers := layers
             , annotations := annotations
             , h_schema := rfl
             , h_media := rfl
             , h_config_media := h_config
             , h_layers_nonempty := h_nonempty
             , h_layers_media := h_layers }
      else none
    else none
  else none

/-- Get number of layers. -/
def ImageManifest.layerCount (m : ImageManifest) : Nat :=
  m.layers.length

/-- STRUCTURAL: All manifests have schema version 2. -/
theorem ImageManifest.schema_is_v2 (m : ImageManifest) :
    m.schemaVersion = 2 := by
  exact m.h_schema

/-- STRUCTURAL: All manifests have at least one layer. -/
theorem ImageManifest.has_layers (m : ImageManifest) :
    m.layers ≠ [] := by
  exact m.h_layers_nonempty

/-- STRUCTURAL: Manifest config has correct media type. -/
theorem ImageManifest.config_type_correct (m : ImageManifest) :
    m.config.mediaType = mediaTypeImageConfig := by
  exact m.h_config_media

end SWELib.Cloud.OciImage