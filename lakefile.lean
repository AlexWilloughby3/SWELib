import Lake
open Lake DSL

package SWELib

lean_lib SWELib where
  srcDir := "spec"
  roots := #[`SWELib]

lean_lib SWELibImpl where
  srcDir := "impl"
  roots := #[`SWELibImpl]
  moreLinkArgs := #["-lssl", "-lcrypto", "-lpq", "-lcurl", "-lssh2"]
