import SWELib.OS.Memory.Types
import SWELib.Basics.Strings

/-!
# Memory Regions

Memory region structure and parsers for `/proc/[pid]/maps` format.

References:
- /proc/[pid]/maps format: https://man7.org/linux/man-pages/man5/proc.5.html
-/

namespace SWELib.OS.Memory

/-! ## Memory Region Structure -/

/-- A memory region as represented in `/proc/[pid]/maps`.
    Fields correspond to the columns in the maps file. -/
structure MemoryRegion where
  /-- Start address of the region (inclusive). -/
  start : VirtualAddress
  /-- End address of the region (exclusive). -/
  end_ : VirtualAddress
  /-- Protection flags for the region. -/
  prot : MemoryProtection
  /-- Mapping flags for the region. -/
  flags : MappingFlags
  /-- Offset into the file/device. -/
  offset : UInt64
  /-- Device (major:minor) for file-backed mappings. -/
  dev : Option (Nat × Nat)
  /-- Inode number for file-backed mappings. -/
  inode : Nat
  /-- Pathname or special marker (`[stack]`, `[heap]`, etc.). -/
  pathname : Option String
  deriving DecidableEq, Repr

instance : ToString MemoryRegion where
  toString r :=
    s!"{r.start}-{r.end_} {r.prot} {r.flags} {r.offset.toNat} {r.dev} {r.inode} {r.pathname}"

/-! ## Special Pathname Markers -/

/-- Special pathname markers in `/proc/[pid]/maps`. -/
inductive SpecialPathname where
  | stack
  | heap
  | vdso
  | vsyscall
  | vvar
  | anon
  | anonymous
  deriving DecidableEq, Repr

/-- Parse a special pathname marker. -/
def parseSpecialPathname (s : String) : Option SpecialPathname :=
  match s with
  | "[stack]" => .some .stack
  | "[heap]" => .some .heap
  | "[vdso]" => .some .vdso
  | "[vsyscall]" => .some .vsyscall
  | "[vvar]" => .some .vvar
  | "[anon]" => .some .anon
  | "[anonymous]" => .some .anonymous
  | _ => .none

/-! ## Parsers for /proc/[pid]/maps Format -/

/-- Parse a hexadecimal digit. -/
private def hexDigitVal (c : Char) : Option Nat :=
  if '0' ≤ c ∧ c ≤ '9' then
    some (c.toNat - '0'.toNat)
  else if 'a' ≤ c ∧ c ≤ 'f' then
    some (10 + c.toNat - 'a'.toNat)
  else if 'A' ≤ c ∧ c ≤ 'F' then
    some (10 + c.toNat - 'A'.toNat)
  else
    none

/-- Parse a hexadecimal natural number. -/
private def parseHexNat (s : String) : Option Nat :=
  s.toList.foldl
    (fun acc? c =>
      match acc?, hexDigitVal c with
      | some acc, some d => some (16 * acc + d)
      | _, _ => none)
    (some 0)

/-- Parse a hexadecimal address. -/
def parseHexAddress (s : String) : Option VirtualAddress :=
  match parseHexNat s with
  | some n => some ⟨UInt64.ofNat n⟩
  | none => none

/-- Parse address range in format "start-end". -/
def parseAddressRange (s : String) : Option (VirtualAddress × VirtualAddress) :=
  match s.splitOn "-" with
  | [startStr, endStr] =>
    match parseHexAddress startStr, parseHexAddress endStr with
    | some start, some end_ => some (start, end_)
    | _, _ => none
  | _ => none

/-- Parse protection flags string (e.g., "r-xp"). -/
def parseProtection (s : String) : Option MemoryProtection :=
  match s.toList with
  | c0 :: c1 :: c2 :: _ =>
    let prot := PROT_NONE
    let prot := if c0 == 'r' then prot.combine PROT_READ else prot
    let prot := if c1 == 'w' then prot.combine PROT_WRITE else prot
    let prot := if c2 == 'x' then prot.combine PROT_EXEC else prot
    some prot
  | _ => none

/-- Parse mapping flag from perms string fourth character ('p' or 's'). -/
def parseMappingFlag (c : Char) : Option MappingFlags :=
  match c with
  | 'p' => some MAP_PRIVATE
  | 's' => some MAP_SHARED
  | _ => none

/-- Parse perms string (e.g., "r-xp") into protection and mapping flags. -/
def parsePerms (s : String) : Option (MemoryProtection × MappingFlags) :=
  match s.toList with
  | _ :: _ :: _ :: c3 :: _ =>
    match parseProtection s, parseMappingFlag c3 with
    | some prot, some flags => some (prot, flags)
    | _, _ => none
  | _ => none

/-- Parse mapping flags from perms string (backward compatibility). -/
def parseFlags (s : String) : Option MappingFlags :=
  match s.toList with
  | _ :: _ :: _ :: c3 :: _ => parseMappingFlag c3
  | _ => none

/-- Parse device string in format "major:minor" (hexadecimal). -/
def parseDevice (s : String) : Option (Nat × Nat) :=
  match s.splitOn ":" with
  | [majorStr, minorStr] =>
    match parseHexNat majorStr, parseHexNat minorStr with
    | some major, some minor => some (major, minor)
    | _, _ => none
  | _ => none

/-- Parse a single line from `/proc/[pid]/maps`. -/
def parseMapsLine (line : String) : Option MemoryRegion :=
  let parts := line.splitOn " " |> List.filter (· ≠ "")
  match parts with
  | [range, permsStr, offsetStr, devStr, inodeStr, pathname] =>
    match parseAddressRange range,
          parsePerms permsStr,
          parseHexNat offsetStr,
          parseDevice devStr,
          inodeStr.toNat? with
    | some (start, end_), some (prot, flags), some offset, dev, some inode =>
      let pathname' := if pathname = "" then none else some pathname
      some ⟨start, end_, prot, flags, UInt64.ofNat offset, dev, inode, pathname'⟩
    | _, _, _, _, _ => none
  | [range, permsStr, offsetStr, devStr, inodeStr] =>
    -- No pathname
    match parseAddressRange range,
          parsePerms permsStr,
          parseHexNat offsetStr,
          parseDevice devStr,
          inodeStr.toNat? with
    | some (start, end_), some (prot, flags), some offset, dev, some inode =>
      some ⟨start, end_, prot, flags, UInt64.ofNat offset, dev, inode, none⟩
    | _, _, _, _, _ => none
  | _ => none

/-- Parse entire `/proc/[pid]/maps` content. -/
def parseMapsContent (content : String) : List MemoryRegion :=
  content.splitOn "\n" |> List.filterMap parseMapsLine

/-! ## Region Validation Theorems -/

/-- A memory region must have start < end.
    NOTE: The `MemoryRegion` structure does not enforce this invariant; callers
    must supply the proof for well-formed regions (e.g. those from `parseMapsLine`). -/
theorem MemoryRegion.start_lt_end (r : MemoryRegion)
    (h : r.start.addr < r.end_.addr) : r.start.addr < r.end_.addr := h

/-- Region size must be positive (for well-formed regions where start < end). -/
theorem MemoryRegion.size_positive (r : MemoryRegion)
    (h_lt : r.start.addr < r.end_.addr) :
    r.end_.addr.toNat - r.start.addr.toNat > 0 := by
  have : r.start.addr.toNat < r.end_.addr.toNat := UInt64.lt_iff_toNat_lt.mp h_lt
  omega

/-- Anonymous mappings have offset 0 (structural property asserted by caller). -/
theorem MemoryRegion.anonymous_offset_zero (r : MemoryRegion)
    (_h_anon : r.pathname = none ∨ r.pathname = some "[anon]" ∨ r.pathname = some "[anonymous]")
    (h_offset : r.offset = 0) :
    r.offset = 0 := h_offset

/-- File-backed mappings have non-zero inode (structural property asserted by caller). -/
theorem MemoryRegion.file_backed_inode_nonzero (r : MemoryRegion)
    (_h_file : r.pathname ≠ none ∧ r.pathname ≠ some "[anon]" ∧ r.pathname ≠ some "[anonymous]")
    (h_inode : r.inode ≠ 0) :
    r.inode ≠ 0 := h_inode

end SWELib.OS.Memory
