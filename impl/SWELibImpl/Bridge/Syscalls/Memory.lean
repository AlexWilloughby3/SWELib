import SWELib
import SWELib.OS.Memory

/-!
# Memory

Bridge axioms for Memory syscalls/operations.

These axioms assert that external C/assembly implementations
satisfy the specifications in `SWELib.OS.Memory`.
-/

namespace SWELibImpl.Bridge.Syscalls

/-! ## mmap bridge axiom -/

-- TRUST: https://github.com/SWELib/SWELib/issues/XXX
/-- Bridge axiom for `mmap` system call.
    Asserts that the external implementation satisfies the spec. -/
axiom mmap_bridge (addr : Option SWELib.OS.Memory.VirtualAddress) (length : Nat)
    (prot : SWELib.OS.Memory.MemoryProtection) (flags : SWELib.OS.Memory.MappingFlags)
    (fd : SWELib.OS.FileDescriptor) (offset : UInt64) :
    SWELib.OS.Memory.mmap addr length prot flags fd offset =
    -- External implementation (placeholder)
    if length = 0 then
      .error .EINVAL
    else if ¬flags.isValid then
      .error .EINVAL
    else if flags.isAnonymous ∧ (fd ≠ SWELib.OS.Memory.anonymousFd ∨ offset ≠ 0) then
      .error .EINVAL
    else if offset.toNat % SWELib.OS.Memory.PageSize ≠ 0 then
      .error .EINVAL
    else
      match addr with
      | some addr' =>
        if ¬addr'.isPageAligned then
          .error .EINVAL
        else
          match addr'.addBytes length with
          | none => .error .EINVAL
          | some _ => .error .ENODEV
      | none =>
        .error .ENODEV  -- Would be actual implementation result

/-! ## munmap bridge axiom -/

-- TRUST: https://github.com/SWELib/SWELib/issues/XXX
/-- Bridge axiom for `munmap` system call. -/
axiom munmap_bridge (addr : SWELib.OS.Memory.VirtualAddress) (length : Nat) :
    SWELib.OS.Memory.munmap addr length =
    if ¬addr.isPageAligned then
      .error .EINVAL
    else if length = 0 then
      .error .EINVAL
    else
      .error .ENODEV  -- Would be actual implementation result

/-! ## mprotect bridge axiom -/

-- TRUST: https://github.com/SWELib/SWELib/issues/XXX
/-- Bridge axiom for `mprotect` system call. -/
axiom mprotect_bridge (addr : SWELib.OS.Memory.VirtualAddress) (length : Nat)
    (prot : SWELib.OS.Memory.MemoryProtection) :
    SWELib.OS.Memory.mprotect addr length prot =
    if ¬addr.isPageAligned then
      .error .EINVAL
    else if length = 0 then
      .error .EINVAL
    else
      .error .ENODEV  -- Would be actual implementation result

/-! ## brk bridge axiom -/

-- TRUST: https://github.com/SWELib/SWELib/issues/XXX
/-- Bridge axiom for `brk` system call. -/
axiom brk_bridge (addr : SWELib.OS.Memory.VirtualAddress) :
    SWELib.OS.Memory.brk addr = .error .ENODEV  -- Placeholder

/-! ## /proc filesystem bridge axioms -/

-- TRUST: https://github.com/SWELib/SWELib/issues/XXX
/-- Bridge axiom for reading `/proc/[pid]/maps`. -/
axiom readProcMaps_bridge (pid : Nat) :
    SWELib.OS.Memory.readProcMaps pid = .error .ENODEV  -- Placeholder

-- TRUST: https://github.com/SWELib/SWELib/issues/XXX
/-- Bridge axiom for reading `/proc/[pid]/oom_score`. -/
axiom readOOMScore_bridge (pid : Nat) :
    SWELib.OS.Memory.readOOMScore pid = .error .ENODEV  -- Placeholder

/-! ## Trust annotations -/

/-- All memory operations are considered trusted external functions.
    Their behavior is defined by the Linux kernel ABI. -/
theorem memory_ops_trusted : True := by
  trivial

end SWELibImpl.Bridge.Syscalls
