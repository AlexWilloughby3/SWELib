import SWELib.OS.Io

/-!
# Memory Types

Core types for memory operations: addresses, protection flags, mapping flags,
and error codes.

References:
- mmap(2): https://man7.org/linux/man-pages/man2/mmap.2.html
- mprotect(2): https://man7.org/linux/man-pages/man2/mprotect.2.html
- brk(2): https://man7.org/linux/man-pages/man2/brk.2.html
-/

namespace SWELib.OS.Memory

/-! ## Virtual Addresses -/

/-- A 64-bit virtual address. Wraps `UInt64` for explicit representation. -/
structure VirtualAddress where
  addr : UInt64
  deriving DecidableEq, Repr

instance : ToString VirtualAddress where
  toString v := s!"0x{v.addr.toNat}"

/-- The system page size (typically 4096 bytes). -/
def PageSize : Nat := 4096

/-- Check if an address is page-aligned. -/
def VirtualAddress.isPageAligned (va : VirtualAddress) : Bool :=
  va.addr.toNat % PageSize = 0

/-- Add bytes to address, returning none if overflow occurs. -/
def VirtualAddress.addBytes (va : VirtualAddress) (bytes : Nat) : Option VirtualAddress :=
  let newAddr := va.addr.toNat + bytes
  if newAddr < va.addr.toNat then  -- overflow detection
    none
  else
    some ⟨UInt64.ofNat newAddr⟩

/-! ## Memory Protection Flags -/

/-- Memory protection flags for `mmap` and `mprotect`.
    Corresponds to the `PROT_*` constants in Linux. -/
structure MemoryProtection where
  /-- Bitmask of PROT_* flags. -/
  bits : Nat
  deriving DecidableEq, Repr

/-- No access allowed. -/
def PROT_NONE : MemoryProtection := ⟨0⟩
/-- Pages may be read. -/
def PROT_READ : MemoryProtection := ⟨1⟩
/-- Pages may be written. -/
def PROT_WRITE : MemoryProtection := ⟨2⟩
/-- Pages may be executed. -/
def PROT_EXEC : MemoryProtection := ⟨4⟩
/-- Pages may be used for atomic operations (Linux-specific). -/
def PROT_SEM : MemoryProtection := ⟨8⟩
/-- Strong atomic ordering (PowerPC-specific). -/
def PROT_SAO : MemoryProtection := ⟨16⟩
/-- Region grows upward (stack-like). -/
def PROT_GROWSUP : MemoryProtection := ⟨32⟩
/-- Region grows downward (stack-like). -/
def PROT_GROWSDOWN : MemoryProtection := ⟨64⟩

/-- Check if protection mask contains a specific flag. -/
def MemoryProtection.contains (prot : MemoryProtection) (flag : MemoryProtection) : Bool :=
  prot.bits &&& flag.bits ≠ 0

/-- Combine protection flags using bitwise OR. -/
def MemoryProtection.combine (p1 p2 : MemoryProtection) : MemoryProtection :=
  ⟨p1.bits ||| p2.bits⟩

/-- Check if protection allows reading. -/
def MemoryProtection.allowsRead (prot : MemoryProtection) : Bool :=
  prot.contains PROT_READ

/-- Check if protection allows writing. -/
def MemoryProtection.allowsWrite (prot : MemoryProtection) : Bool :=
  prot.contains PROT_WRITE

/-- Check if protection allows execution. -/
def MemoryProtection.allowsExec (prot : MemoryProtection) : Bool :=
  prot.contains PROT_EXEC

instance : ToString MemoryProtection where
  toString p :=
    let parts : List String :=
      (if p.allowsRead then ["r"] else []) ++
      (if p.allowsWrite then ["w"] else []) ++
      (if p.allowsExec then ["x"] else [])
    if parts.isEmpty then "---" else String.intercalate "" parts

/-! ## Mapping Flags -/

/-- Memory mapping flags for `mmap`.
    Corresponds to the `MAP_*` constants in Linux. -/
structure MappingFlags where
  /-- Bitmask of MAP_* flags. -/
  bits : Nat
  deriving DecidableEq, Repr

/-- Share changes with other processes. -/
def MAP_SHARED : MappingFlags := ⟨0x01⟩
/-- Changes are private to this process. -/
def MAP_PRIVATE : MappingFlags := ⟨0x02⟩
/-- Create an anonymous mapping (not backed by a file). -/
def MAP_ANONYMOUS : MappingFlags := ⟨0x20⟩
/-- Map fixed address (fail if address is unavailable). -/
def MAP_FIXED : MappingFlags := ⟨0x10⟩
/-- Don't reserve swap space for this mapping. -/
def MAP_NORESERVE : MappingFlags := ⟨0x4000⟩
/-- Lock the pages into memory. -/
def MAP_LOCKED : MappingFlags := ⟨0x2000⟩
/-- Populate (prefault) page tables. -/
def MAP_POPULATE : MappingFlags := ⟨0x8000⟩
/-- Allocate from huge TLB pool. -/
def MAP_HUGETLB : MappingFlags := ⟨0x40000⟩
/-- Validate mapping flags (Linux 4.15+). -/
def MAP_SHARED_VALIDATE : MappingFlags := ⟨0x03⟩  -- MAP_SHARED | MAP_SHARED_VALIDATE?
/-- Map fixed address, don't replace existing mapping. -/
def MAP_FIXED_NOREPLACE : MappingFlags := ⟨0x100000⟩
/-- Mapping is used for process stack. -/
def MAP_STACK : MappingFlags := ⟨0x20000⟩
/-- Create synchronous page faults. -/
def MAP_SYNC : MappingFlags := ⟨0x80000⟩
/-- Map into first 2GB of address space. -/
def MAP_32BIT : MappingFlags := ⟨0x40⟩
/-- Deny write access to underlying file. -/
def MAP_DENYWRITE : MappingFlags := ⟨0x0800⟩
/-- Mapping is executable. -/
def MAP_EXECUTABLE : MappingFlags := ⟨0x1000⟩
/-- Mapping is backed by a file (default). -/
def MAP_FILE : MappingFlags := ⟨0x00⟩  -- No bit, just for documentation
/-- Stack grows downward. -/
def MAP_GROWSDOWN : MappingFlags := ⟨0x0100⟩
/-- Do not block on page faults. -/
def MAP_NONBLOCK : MappingFlags := ⟨0x10000⟩
/-- Don't clear anonymous pages. -/
def MAP_UNINITIALIZED : MappingFlags := ⟨0x4000000⟩
/-- 2MB huge pages. -/
def MAP_HUGE_2MB : MappingFlags := ⟨0x08000000⟩
/-- 1GB huge pages. -/
def MAP_HUGE_1GB : MappingFlags := ⟨0x10000000⟩

/-- Check if flag set contains a specific flag. -/
def MappingFlags.contains (flags : MappingFlags) (flag : MappingFlags) : Bool :=
  flags.bits &&& flag.bits ≠ 0

/-- Combine mapping flags using bitwise OR. -/
def MappingFlags.combine (f1 f2 : MappingFlags) : MappingFlags :=
  ⟨f1.bits ||| f2.bits⟩

/-- Check if flags include `MAP_ANONYMOUS`. -/
def MappingFlags.isAnonymous (flags : MappingFlags) : Bool :=
  flags.contains MAP_ANONYMOUS

/-- Check if flags include `MAP_SHARED` or `MAP_SHARED_VALIDATE`. -/
def MappingFlags.isShared (flags : MappingFlags) : Bool :=
  flags.contains MAP_SHARED || flags.contains MAP_SHARED_VALIDATE

/-- Check if flags include `MAP_PRIVATE`. -/
def MappingFlags.isPrivate (flags : MappingFlags) : Bool :=
  flags.contains MAP_PRIVATE

/-- Check if flags include `MAP_FIXED`. -/
def MappingFlags.isFixed (flags : MappingFlags) : Bool :=
  flags.contains MAP_FIXED

/-- Check if flags are valid: exactly one of MAP_SHARED or MAP_PRIVATE must be set. -/
def MappingFlags.isValid (flags : MappingFlags) : Bool :=
  (flags.isShared && ¬flags.isPrivate) || (¬flags.isShared && flags.isPrivate)

instance : ToString MappingFlags where
  toString f :=
    let parts : List String :=
      (if f.isShared then ["shared"] else []) ++
      (if f.isPrivate then ["private"] else []) ++
      (if f.isAnonymous then ["anonymous"] else []) ++
      (if f.isFixed then ["fixed"] else [])
    if parts.isEmpty then "none" else String.intercalate "|" parts

/-! ## OOM Score -/

/-- OOM (Out-Of-Memory) score for a process.
    Higher score means more likely to be killed by OOM killer. -/
structure OOMScore where
  score : Nat
  deriving DecidableEq, Repr

instance : ToString OOMScore where
  toString s := s!"oom_score({s.score})"

/-! ## Memory-Specific Error Codes -/

/-- Memory-specific error codes (extending base `Errno`). -/
def MemoryErrno := Errno

/-- Anonymous file descriptor constant for `MAP_ANONYMOUS` mappings. -/
def anonymousFd : FileDescriptor := ⟨0xFFFFFFFFFFFFFFFF⟩  -- -1 as unsigned 64-bit

end SWELib.OS.Memory
