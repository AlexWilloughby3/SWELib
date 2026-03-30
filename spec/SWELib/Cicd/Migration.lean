import SWELib.Cicd.Migration.Types
import SWELib.Cicd.Migration.Properties

/-!
# Migration & System Evolution

How distributed systems evolve over time. A migration transitions from one
system version to another through a MixedVersionState where both versions coexist.

## Modules

- **Types**: Core types — Version, ChangeKind, Migration, MixedVersionState,
  Compatibility, DeploymentPlan, RollbackPlan, VersionedSystem, proof compaction.
- **Properties**: Key theorems — compaction soundness, composition transitivity,
  bisimilar migration safety, deployment plan classification, retention bounds.
-/
