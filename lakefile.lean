import Lake
open Lake DSL

package SWELib

require mathlib from git
  "https://github.com/leanprover-community/mathlib4" @ "v4.0.0"

lean_lib SWELib where
  srcDir := "spec"
  roots := #[`SWELib]

lean_lib SWELibBridge where
  srcDir := "bridge"
  roots := #[`SWELibBridge]

lean_lib SWELibCode where
  srcDir := "code"
  roots := #[`SWELibCode]
  moreLinkArgs := #["-lssl", "-lcrypto", "-lpq", "-lcurl"]
