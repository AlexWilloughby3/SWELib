import SWELib
import SWELibImpl.Bridge
import SWELibImpl.Ffi.Memory

/-!
# MemoryOps

Typed wrappers around virtual memory syscalls and `/proc` filesystem reads.
Converts between spec types from `SWELib.OS.Memory` and the raw integers
consumed by the C shims in `SWELibImpl.Ffi.Memory`.

- `mmap`, `mmapAnonymous`: create virtual memory mappings.
- `munmap`: release mappings.
- `mprotect`: change protection on a mapped region.
- `brk`, `sbrk`: manipulate the program break.
- `readProcMaps`: parse `/proc/[pid]/maps` using the spec's own parser.
- `readOOMScore`: read `/proc/[pid]/oom_score`.
-/

namespace SWELibImpl.OS.MemoryOps

open SWELib.OS.Memory
open SWELib.OS (Errno FileDescriptor)

/-! ## Encoding helpers -/

/-- `MemoryProtection.bits : Nat` → `UInt32` for the C shim. -/
private def protToUInt32 (p : MemoryProtection) : UInt32 :=
  p.bits.toUInt32

/-- `MappingFlags.bits : Nat` → `UInt32` for the C shim. -/
private def flagsToUInt32 (f : MappingFlags) : UInt32 :=
  f.bits.toUInt32

/-- `VirtualAddress.addr : UInt64` — already the right type. -/
private def addrToUInt64 (va : VirtualAddress) : UInt64 := va.addr

/-- Wrap a `UInt64` from the kernel back into a `VirtualAddress`. -/
private def addrOfUInt64 (n : UInt64) : VirtualAddress := ⟨n⟩

/-- Convert a `FileDescriptor` to `Int32` for the C mmap shim.
    `anonymousFd` (fd = 0xFFFFFFFF…) becomes -1, normal fds are preserved. -/
private def fdToInt32 (fd : FileDescriptor) : Int32 :=
  fd.fd.toInt32

/-! ## mmap -/

/-- `mmap(2)`: create a new mapping in the virtual address space.
    - `addr = none`: kernel chooses the address.
    - `addr = some va`: used as a hint (or fixed address with `MAP_FIXED`).
    Returns the actual start address of the new mapping. -/
def mmap (addr : Option VirtualAddress) (length : Nat) (prot : MemoryProtection)
    (flags : MappingFlags) (fd : FileDescriptor) (offset : UInt64) :
    IO (Except Errno VirtualAddress) := do
  let rawAddr := match addr with
    | none    => 0
    | some va => addrToUInt64 va
  let result ← SWELibImpl.Ffi.Memory.mmap_
    rawAddr length.toUSize (protToUInt32 prot) (flagsToUInt32 flags) (fdToInt32 fd) offset
  return result.map addrOfUInt64

/-- `mmap` for the common case: anonymous private mapping with no hint address.
    Equivalent to `mmap(NULL, length, prot, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0)`. -/
def mmapAnonymous (length : Nat) (prot : MemoryProtection) :
    IO (Except Errno VirtualAddress) :=
  mmap none length prot (MAP_PRIVATE.combine MAP_ANONYMOUS) anonymousFd 0

/-! ## munmap -/

/-- `munmap(2)`: release the mapping starting at `addr` for `length` bytes.
    `addr` must be page-aligned; `length` is rounded up by the kernel. -/
def munmap (addr : VirtualAddress) (length : Nat) : IO (Except Errno Unit) :=
  SWELibImpl.Ffi.Memory.munmap_ (addrToUInt64 addr) length.toUSize

/-! ## mprotect -/

/-- `mprotect(2)`: change the access protection of a mapped region.
    `addr` must be page-aligned. -/
def mprotect (addr : VirtualAddress) (length : Nat) (prot : MemoryProtection) :
    IO (Except Errno Unit) :=
  SWELibImpl.Ffi.Memory.mprotect_ (addrToUInt64 addr) length.toUSize (protToUInt32 prot)

/-! ## brk and sbrk -/

/-- `brk(2)`: set the program break to `addr`.
    Returns the actual new program break (may differ due to page rounding). -/
def brk (addr : VirtualAddress) : IO (Except Errno VirtualAddress) := do
  let result ← SWELibImpl.Ffi.Memory.brk_ (addrToUInt64 addr)
  return result.map addrOfUInt64

/-- `sbrk(2)`: increment the program break by `increment` bytes.
    A negative `increment` shrinks the heap.
    Returns the new program break (= old break + increment). -/
def sbrk (increment : Int) : IO (Except Errno VirtualAddress) := do
  let result ← SWELibImpl.Ffi.Memory.sbrk_ increment.toInt64
  return result.map addrOfUInt64

/-! ## /proc filesystem -/

/-- Read `/proc/[pid]/maps` and parse it into a list of `MemoryRegion`s.
    Uses the spec's `parseMapsContent` parser — no C shim needed.
    Fails with `EIO` if the file cannot be read or the PID does not exist. -/
def readProcMaps (pid : Nat) : IO (Except Errno (List MemoryRegion)) := do
  try
    let content ← IO.FS.readFile s!"/proc/{pid}/maps"
    return .ok (parseMapsContent content)
  catch _ =>
    return .error .EIO

/-- Read `/proc/[pid]/oom_score` and parse the integer OOM score.
    Fails with `EIO` if the file cannot be read or contains unexpected content. -/
def readOOMScore (pid : Nat) : IO (Except Errno OOMScore) := do
  try
    let content ← IO.FS.readFile s!"/proc/{pid}/oom_score"
    match content.trimAscii.toString.toNat? with
    | some n => return .ok ⟨n⟩
    | none   => return .error .EIO
  catch _ =>
    return .error .EIO

end SWELibImpl.OS.MemoryOps
