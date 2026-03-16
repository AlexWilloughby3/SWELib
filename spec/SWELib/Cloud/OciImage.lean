/-
Copyright (c) 2024 SWELib Contributors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: SWELib Contributors
-/

import SWELib.Cloud.OciImage.Algorithm
import SWELib.Cloud.OciImage.MediaType
import SWELib.Cloud.OciImage.Platform
import SWELib.Cloud.OciImage.Annotations
import SWELib.Cloud.OciImage.Errors
import SWELib.Cloud.OciImage.Digest
import SWELib.Cloud.OciImage.Descriptor
import SWELib.Cloud.OciImage.Layer
import SWELib.Cloud.OciImage.ImageConfig
import SWELib.Cloud.OciImage.ImageManifest
import SWELib.Cloud.OciImage.ImageIndex
import SWELib.Cloud.OciImage.Validation
import SWELib.Cloud.OciImage.Resolution
import SWELib.Cloud.OciImage.Invariants

/-!
# OCI Image Format Specification

Formalization of the Open Container Initiative (OCI) Image Format Specification.

## Overview

The OCI Image Format defines:
- Content-addressable storage using cryptographic digests
- Image manifests (single-platform) and indexes (multi-platform)
- Layer filesystem semantics with whiteout files for deletions
- Platform matching for multi-architecture images
- Runtime configuration for containers

## Module Structure

- **Algorithm**: Hash algorithms (sha256, sha512, blake3)
- **MediaType**: Media type constants for blobs
- **Platform**: OS/architecture specifications
- **Annotations**: Key-value metadata
- **Digest**: Content-addressable identifiers
- **Descriptor**: Blob references with validation
- **Layer**: Filesystem changesets with whiteouts
- **ImageConfig**: Runtime configuration
- **ImageManifest**: Single-platform image
- **ImageIndex**: Multi-platform selector
- **Validation**: Cross-cutting validation logic
- **Resolution**: Platform matching algorithm
- **Invariants**: Global consistency properties

## Example Usage

```lean
-- Create a digest
def myDigest := Digest.sha256 "4e388ab32b10dc8dbc7e28144f552830adc74787c1e2c0824032078a79f227fb"

-- Create a descriptor
def configBlob : ByteArray := -- ... serialized config
def configDesc := Descriptor.forBlob mediaTypeImageConfig configBlob

-- Build a manifest
def layer1Blob : ByteArray := -- ... tar archive
def layer1Desc := Descriptor.forBlob mediaTypeLayerGzip layer1Blob
def manifest := ImageManifest.build configDesc [layer1Desc]

-- Select manifest for platform
def index : ImageIndex := -- ... multi-platform index
def selected := selectBestManifest index Platform.linuxAmd64
```

## References

- [OCI Image Format Specification](https://github.com/opencontainers/image-spec)
- [OCI Distribution Specification](https://github.com/opencontainers/distribution-spec) (future work)

## Related Modules

- **SWELib.Cloud.Oci**: OCI Runtime Specification (container execution)
- **SWELib.Basics.Time**: NumericDate for timestamps
- **SWELib.Basics.Uri**: URI parsing for descriptor URLs
-/

namespace SWELib.Cloud.OciImage

-- Re-export commonly used types
export Algorithm (Algorithm)
export MediaType (MediaType mediaTypeImageManifest mediaTypeImageIndex
                  mediaTypeImageConfig mediaTypeLayerTar mediaTypeLayerGzip mediaTypeLayerZstd)
export Platform (Platform)
export Annotations (Annotations)
export Digest (Digest)
export Descriptor (Descriptor)
export Layer (Layer WhiteoutType WhiteoutEntry)
export ImageConfig (ImageConfig RuntimeConfig RootFS History)
export ImageManifest (ImageManifest)
export ImageIndex (ImageIndex)
export Errors (ImageError)
export Resolution (MatchScore matchPlatform selectBestManifest)
export Validation (validateDescriptor validateManifest validateIndex)

end SWELib.Cloud.OciImage