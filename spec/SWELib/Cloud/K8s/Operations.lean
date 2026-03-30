/-
Copyright (c) 2024 SWELib Contributors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: SWELib Contributors
-/

import SWELib.Cloud.K8s.Operations.Types
import SWELib.Cloud.K8s.Operations.Get
import SWELib.Cloud.K8s.Operations.List
import SWELib.Cloud.K8s.Operations.Create
import SWELib.Cloud.K8s.Operations.Update
import SWELib.Cloud.K8s.Operations.Delete
import SWELib.Cloud.K8s.Operations.Watch
import SWELib.Cloud.K8s.Operations.Patch

namespace SWELib.Cloud.K8s

-- Re-export operation types
export SWELib.Cloud.K8s.Operations (ListMeta ObjectList OperationError OperationResult
  GetParams podGet
  ListParams podList
  CreateParams podCreate
  UpdateParams podUpdate
  DeleteParams podDelete
  WatchParams EventType WatchEvent podWatch
  PatchParams PatchType podPatch)

end SWELib.Cloud.K8s
