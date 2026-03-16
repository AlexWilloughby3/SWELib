/-
Copyright (c) 2024 SWELib Contributors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: SWELib Contributors
-/

namespace SWELib.Cloud.OciImage

/-!
# OCI Image Media Types

Media type constants for OCI Image Format blobs.

## Standard Media Types

- Manifests: `application/vnd.oci.image.manifest.v1+json`
- Indexes: `application/vnd.oci.image.index.v1+json`
- Configs: `application/vnd.oci.image.config.v1+json`
- Layers: `application/vnd.oci.image.layer.v1.tar[+gzip|+zstd]`

## References

- [OCI Image Media Types](https://github.com/opencontainers/image-spec/blob/main/media-types.md)
-/

/-- Media type identifier for blobs. -/
def MediaType := String
deriving BEq, DecidableEq

/-- Image manifest media type. -/
def mediaTypeImageManifest : MediaType := "application/vnd.oci.image.manifest.v1+json"

/-- Image index media type (multi-platform). -/
def mediaTypeImageIndex : MediaType := "application/vnd.oci.image.index.v1+json"

/-- Image configuration media type. -/
def mediaTypeImageConfig : MediaType := "application/vnd.oci.image.config.v1+json"

/-- Uncompressed layer media type. -/
def mediaTypeLayerTar : MediaType := "application/vnd.oci.image.layer.v1.tar"

/-- Gzip-compressed layer media type. -/
def mediaTypeLayerGzip : MediaType := "application/vnd.oci.image.layer.v1.tar+gzip"

/-- Zstd-compressed layer media type. -/
def mediaTypeLayerZstd : MediaType := "application/vnd.oci.image.layer.v1.tar+zstd"

/-- Check if media type is a manifest type. -/
def isManifestType (mt : MediaType) : Bool :=
  mt == mediaTypeImageManifest

/-- Check if media type is an index type. -/
def isIndexType (mt : MediaType) : Bool :=
  mt == mediaTypeImageIndex

/-- Check if media type is a config type. -/
def isConfigType (mt : MediaType) : Bool :=
  mt == mediaTypeImageConfig

/-- Check if media type is a layer type. -/
def isLayerType (mt : MediaType) : Bool :=
  mt == mediaTypeLayerTar || mt == mediaTypeLayerGzip || mt == mediaTypeLayerZstd

/-- Check if layer is compressed. -/
def isCompressedLayer (mt : MediaType) : Bool :=
  mt == mediaTypeLayerGzip || mt == mediaTypeLayerZstd

/-- STRUCTURAL: Compressed layers are layers. -/
theorem compressed_layer_is_layer (mt : MediaType) :
    isCompressedLayer mt = true → isLayerType mt = true := by
  sorry  -- Deferred: Bool reasoning about || operations

end SWELib.Cloud.OciImage