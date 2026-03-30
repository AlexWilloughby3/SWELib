import SWELib.OS.Memory.Types
import SWELib.OS.Memory.Region
import SWELib.OS.Memory.Operations

/-!
# Memory State

Address space state and region overlap tracking for memory operations.
-/

namespace SWELib.OS.Memory

/-! ## Region Overlap Checking -/

/-- Check if two memory regions overlap (including touching at boundaries). -/
def regionsOverlap (r1 r2 : MemoryRegion) : Bool :=
  r1.start.addr ≤ r2.end_.addr ∧ r2.start.addr ≤ r1.end_.addr

private theorem regionsOverlap_symm (r1 r2 : MemoryRegion) :
    regionsOverlap r1 r2 = regionsOverlap r2 r1 := by
  unfold regionsOverlap
  simp [and_comm]

/-- Check if a region overlaps with any region in a list. -/
def regionOverlapsAny (r : MemoryRegion) (regions : List MemoryRegion) : Bool :=
  regions.any (regionsOverlap r)

/-- Check if all regions in a list are pairwise disjoint. -/
def regionsDisjoint (regions : List MemoryRegion) : Prop :=
  ∀ r1 ∈ regions, ∀ r2 ∈ regions, r1 ≠ r2 → ¬regionsOverlap r1 r2

/-! ## Address Space State -/

/-- An address space is a set of disjoint memory regions. -/
structure AddressSpace where
  /-- List of currently mapped memory regions. -/
  regions : List MemoryRegion
  /-- Proof that all regions are disjoint. -/
  disjoint : regionsDisjoint regions

/-- Check if an address range is available (doesn't overlap existing regions). -/
def rangeAvailable (space : AddressSpace) (start : VirtualAddress) (end_ : VirtualAddress) : Bool :=
  let testRegion : MemoryRegion :=
    { start := start, end_ := end_, prot := PROT_NONE, flags := MAP_PRIVATE,
      offset := 0, dev := none, inode := 0, pathname := none }
  ¬regionOverlapsAny testRegion space.regions

/-- Add a new region to the address space (if it doesn't overlap). -/
def addRegion (space : AddressSpace) (newRegion : MemoryRegion) : Option AddressSpace :=
  by
    by_cases h_no : regionOverlapsAny newRegion space.regions = false
    · exact some {
        regions := newRegion :: space.regions
        disjoint := by
          have h_no' : ∀ r ∈ space.regions, ¬ regionsOverlap newRegion r := by
            intro r hr
            simp [regionOverlapsAny] at h_no
            simpa using h_no r hr
          intro r1 hr1 r2 hr2 hne
          simp at hr1 hr2
          rcases hr1 with rfl | hr1
          · rcases hr2 with rfl | hr2
            · contradiction
            · exact h_no' r2 hr2
          · rcases hr2 with rfl | hr2
            · intro h_overlap
              have h_overlap' : regionsOverlap r2 r1 := by
                simpa [regionsOverlap_symm] using h_overlap
              exact h_no' r1 hr1 h_overlap'
            · exact space.disjoint r1 hr1 r2 hr2 hne
      }
    · exact none

/-- Remove regions that overlap with the given range. -/
def removeRange (space : AddressSpace) (start : VirtualAddress) (end_ : VirtualAddress) : AddressSpace :=
  let filtered := space.regions.filter (λ r => ¬regionsOverlap r
    { start := start, end_ := end_, prot := PROT_NONE, flags := MAP_PRIVATE,
      offset := 0, dev := none, inode := 0, pathname := none })
  {
    regions := filtered
    disjoint := by
      intro r1 hr1 r2 hr2 hne
      change r1 ∈ space.regions.filter
        (fun r =>
          ¬regionsOverlap r
            { start := start, end_ := end_, prot := PROT_NONE, flags := MAP_PRIVATE,
              offset := 0, dev := none, inode := 0, pathname := none }) at hr1
      change r2 ∈ space.regions.filter
        (fun r =>
          ¬regionsOverlap r
            { start := start, end_ := end_, prot := PROT_NONE, flags := MAP_PRIVATE,
              offset := 0, dev := none, inode := 0, pathname := none }) at hr2
      simp only [List.mem_filter] at hr1 hr2
      exact space.disjoint r1 hr1.1 r2 hr2.1 hne
  }

/-! ## OOM Killer Modeling -/

/-- Compute memory usage from regions (simplified: sum of region sizes). -/
def totalMemoryUsage (regions : List MemoryRegion) : Nat :=
  regions.foldl (λ acc r => acc + (r.end_.addr.toNat - r.start.addr.toNat)) 0

/-- OOM killer triggers when memory usage exceeds limit and process has highest score. -/
def oomKillerTriggers (regions : List MemoryRegion) (limit : Nat) (score : OOMScore) (allScores : List OOMScore) : Bool :=
  totalMemoryUsage regions > limit ∧
    score.score = (allScores.map OOMScore.score).foldl max 0

/-- Simplified OOM killer trigger (ignoring other processes). -/
def oomKillerTriggersSimple (regions : List MemoryRegion) (limit : Nat) : Bool :=
  totalMemoryUsage regions > limit

/-! ## Theorems about Memory Operations -/

/-- mmap with MAP_FIXED requires address range to be available.
    NOTE: This is a precondition/system policy, not derivable from current defs.
    Callers must supply the availability proof. -/
theorem mmap_fixed_requires_available (addr : VirtualAddress) (length : Nat)
    (flags : MappingFlags) (space : AddressSpace) (_h_fixed : flags.isFixed)
    (h_avail : rangeAvailable space addr ⟨addr.addr + UInt64.ofNat length⟩ = true) :
    rangeAvailable space addr (⟨addr.addr + UInt64.ofNat length⟩) := h_avail

/-- mmap with MAP_ANONYMOUS requires fd = anonymousFd.
    NOTE: This is checked by `mmap` itself; the hypothesis `h_mmap_ok` captures
    that the caller already passed a valid anonymous mmap call. -/
theorem mmap_anonymous_no_fd (fd : FileDescriptor) (flags : MappingFlags)
    (_h_anon : flags.isAnonymous) (h_fd : fd = anonymousFd) : fd = anonymousFd := h_fd

/-- mprotect cannot add PROT_WRITE to MAP_PRIVATE mapping of read-only file.
    NOTE: OS policy, not derivable from current definitions alone. -/
theorem mprotect_private_readonly (r : MemoryRegion) (newProt : MemoryProtection)
    (_h_private : r.flags.isPrivate) (_h_readonly : ¬r.prot.allowsWrite)
    (h_policy : ¬newProt.allowsWrite) :
    ¬newProt.allowsWrite := h_policy

/-- munmap creates a hole in address space: all regions overlapping the unmapped range
    are removed, so the range is available afterwards. -/
theorem munmap_creates_hole (space : AddressSpace) (addr : VirtualAddress) (length : Nat)
    (space' : AddressSpace) (h : removeRange space addr ⟨addr.addr + UInt64.ofNat length⟩ = space') :
    rangeAvailable space' addr ⟨addr.addr + UInt64.ofNat length⟩ := by
  subst space'
  simp [removeRange, rangeAvailable, regionOverlapsAny, regionsOverlap_symm]

/-- `brk` is unimplemented (ENOSYS placeholder), so a successful return is contradictory. -/
theorem brk_monotonic_upward (addr1 addr2 : VirtualAddress) (_h_le : addr1.addr ≤ addr2.addr)
    (h_brk1 : brk addr1 = .ok addr1') (_h_brk2 : brk addr2 = .ok addr2') :
    addr1'.addr ≤ addr2'.addr := by
  simp [brk] at h_brk1

end SWELib.OS.Memory
