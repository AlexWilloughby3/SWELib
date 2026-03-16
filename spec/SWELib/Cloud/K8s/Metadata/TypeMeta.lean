/-
Copyright (c) 2024 SWELib Contributors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: SWELib Contributors
-/

import SWELib.Cloud.K8s.Primitives

namespace SWELib.Cloud.K8s.Metadata

open SWELib.Cloud.K8s.Primitives

/-- Type metadata for Kubernetes resources -/
structure TypeMeta where
  apiVersion : ApiVersion
  kind : String
  deriving DecidableEq

/-- TypeMeta for a Pod -/
def podTypeMeta : TypeMeta :=
  ⟨apiVersionV1, "Pod"⟩

/-- TypeMeta for a Service -/
def serviceTypeMeta : TypeMeta :=
  ⟨apiVersionV1, "Service"⟩

/-- TypeMeta for a Deployment -/
def deploymentTypeMeta : TypeMeta :=
  ⟨apiVersionAppsV1, "Deployment"⟩

/-- TypeMeta for a ConfigMap -/
def configMapTypeMeta : TypeMeta :=
  ⟨apiVersionV1, "ConfigMap"⟩

/-- TypeMeta for a Secret -/
def secretTypeMeta : TypeMeta :=
  ⟨apiVersionV1, "Secret"⟩

end SWELib.Cloud.K8s.Metadata