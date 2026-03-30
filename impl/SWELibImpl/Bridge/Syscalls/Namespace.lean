import SWELib
import SWELib.OS.Namespaces.Types
import SWELib.OS.Namespaces.Operations
import SWELib.OS.Namespaces.Invariants

/-!
# Namespace

Bridge axioms for Namespace syscalls/operations.
-/


namespace SWELibImpl.Bridge.Syscalls

open SWELib.OS

-- TRUST: External implementation satisfies namespace specification
-- Bridge axioms for namespace operations

/-- Axiom: clone system call implementation. -/
axiom clone_impl (fn : Unit → Unit) (stack : ByteArray) (flags : CloneFlags)
  (arg : Unit) : Except NamespaceError (NamespacedPID × NamespacedPID)

/-- Axiom: unshare system call implementation. -/
axiom unshare_impl (flags : CloneFlags) : Except NamespaceError Unit

/-- Axiom: setns system call implementation. -/
axiom setns_impl (fd : NamespaceFD) (nstype : Option CloneFlags) : Except NamespaceError Unit

/-- Axiom: get_namespace_fd implementation. -/
axiom get_namespace_fd_impl (pid : NamespacedPID) (ns : Namespace) : Except NamespaceError NamespaceFD

/-- Bridge axiom: clone matches specification. -/
axiom clone_bridge (fn : Unit → Unit) (stack : ByteArray) (flags : CloneFlags) (arg : Unit) :
  clone fn stack flags arg = clone_impl fn stack flags arg

/-- Bridge axiom: unshare matches specification. -/
axiom unshare_bridge (flags : CloneFlags) :
  unshare flags = unshare_impl flags

/-- Bridge axiom: setns matches specification. -/
axiom setns_bridge (fd : NamespaceFD) (nstype : Option CloneFlags) :
  setns fd nstype = setns_impl fd nstype

/-- Bridge axiom: get_namespace_fd matches specification. -/
axiom get_namespace_fd_bridge (pid : NamespacedPID) (ns : Namespace) :
  get_namespace_fd pid ns = get_namespace_fd_impl pid ns

/-- Axiom: PID namespace isolation property. -/
axiom pid_namespace_isolation_axiom (p1 p2 : NamespacedPID)
  (h : p1.namespaceId ≠ p2.namespaceId) : p1.pid = p2.pid → False

/-- Axiom: Network namespace isolation property. -/
axiom network_namespace_isolation_axiom (ns1 ns2 : NamespaceFD)
  (h : ns1.nsType = .network ∧ ns2.nsType = .network ∧ ns1 ≠ ns2) :
  ¬ can_connect_localhost ns1 ns2

/-- Axiom: User namespace capabilities property. -/
axiom user_namespace_capabilities_axiom (pid : NamespacedPID)
  (h : pid.namespaceId ≠ 0) :
  has_all_capabilities_in_namespace pid

/-- Axiom: Clone flags compatibility. -/
axiom clone_flags_compatibility_axiom (flags : CloneFlags) :
  (flags.elem CloneFlag.NEWPID → flags.elem CloneFlag.NEWUSER) ∧
  (flags.elem CloneFlag.THREAD → flags.elem CloneFlag.VM ∧ flags.elem CloneFlag.SIGHAND)

end SWELibImpl.Bridge.Syscalls
