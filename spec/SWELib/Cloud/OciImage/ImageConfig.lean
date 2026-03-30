/-
Copyright (c) 2024 SWELib Contributors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: SWELib Contributors
-/

import SWELib.Cloud.OciImage.Platform
import SWELib.Cloud.OciImage.Annotations
import SWELib.Cloud.OciImage.Digest
import SWELib.Basics.Time

namespace SWELib.Cloud.OciImage

/-!
# OCI Image Configuration

Runtime configuration for container images.

## Components

- **RuntimeConfig**: User, environment, entrypoint, command, volumes, labels
- **RootFS**: Layer diff IDs (uncompressed digests)
- **History**: Layer creation history
- **ImageConfig**: Complete image configuration

## References

- [OCI Image Config](https://github.com/opencontainers/image-spec/blob/main/config.md)
-/

open SWELib.Basics

/-- Runtime configuration for container execution. -/
structure RuntimeConfig where
  /-- User/UID for process. -/
  User : Option String := none
  /-- Exposed ports (format: "80/tcp"). -/
  ExposedPorts : List String := []
  /-- Environment variables (format: "KEY=value"). -/
  Env : List String := []
  /-- Entrypoint executable and args. -/
  Entrypoint : List String := []
  /-- Default command or arguments. -/
  Cmd : List String := []
  /-- Volume mount points. -/
  Volumes : List String := []
  /-- Working directory. -/
  WorkingDir : Option String := none
  /-- Arbitrary labels. -/
  Labels : Annotations := []
  deriving Repr

/-- Root filesystem configuration. -/
structure RootFS where
  /-- Filesystem type (must be "layers"). -/
  fsType : String
  /-- Ordered list of layer diff IDs (uncompressed digests). -/
  diffIds : List Digest
  /-- Proof that type is "layers". -/
  h_type_valid : fsType = "layers"
  /-- Proof that at least one layer exists. -/
  h_nonempty : diffIds ≠ []
  deriving DecidableEq

/-- Layer history entry. -/
structure History where
  /-- Creation timestamp. -/
  created : Option NumericDate := none
  /-- Command that created layer. -/
  createdBy : Option String := none
  /-- Author. -/
  author : Option String := none
  /-- Comment. -/
  comment : Option String := none
  /-- True if layer has no filesystem changes. -/
  emptyLayer : Bool := false
  deriving DecidableEq, Repr

/-- Complete image configuration. -/
structure ImageConfig where
  /-- Creation timestamp. -/
  created : Option NumericDate := none
  /-- Image author. -/
  author : Option String := none
  /-- CPU architecture. -/
  architecture : String
  /-- Operating system. -/
  os : String
  /-- Runtime configuration. -/
  config : Option RuntimeConfig := none
  /-- Root filesystem. -/
  rootfs : RootFS
  /-- Layer history. -/
  history : List History := []

/-- Create RootFS from layer digests. -/
def RootFS.fromDigests (diffIds : List Digest) (h : diffIds ≠ []) : RootFS :=
  { fsType := "layers"
  , diffIds := diffIds
  , h_type_valid := rfl
  , h_nonempty := h }

/-- Get platform from image config. -/
def ImageConfig.platform (cfg : ImageConfig) : Platform :=
  { architecture := cfg.architecture, os := cfg.os }

/-- STRUCTURAL: RootFS type is always "layers". -/
theorem rootfs_type_is_layers (rootfs : RootFS) :
    rootfs.fsType = "layers" := by
  exact rootfs.h_type_valid

/-- STRUCTURAL: RootFS always has at least one layer. -/
theorem rootfs_nonempty (rootfs : RootFS) :
    rootfs.diffIds ≠ [] := by
  exact rootfs.h_nonempty

end SWELib.Cloud.OciImage
