import SWELib
import SWELibImpl.Bridge

/-!
# Memory Syscalls FFI

Raw `@[extern]` declarations for virtual memory syscalls.
These bind to C shims in `swelib_syscalls.c`.

References:
- mmap(2):     https://man7.org/linux/man-pages/man2/mmap.2.html
- munmap(2):   https://man7.org/linux/man-pages/man2/munmap.2.html
- mprotect(2): https://man7.org/linux/man-pages/man2/mprotect.2.html
- brk(2):      https://man7.org/linux/man-pages/man2/brk.2.html
-/

namespace SWELibImpl.Ffi.Memory

open SWELib.OS (Errno)

/-- Raw mmap(2) via C shim.
    `addr=0`: let kernel choose the address.
    `prot`:  PROT_* bitmask (PROT_NONE=0, PROT_READ=1, PROT_WRITE=2, PROT_EXEC=4).
    `flags`: MAP_* bitmask (MAP_SHARED=0x01, MAP_PRIVATE=0x02, MAP_ANONYMOUS=0x20, …).
    `fd`:    file descriptor; -1 (Int32.mk 0xFFFFFFFF) for MAP_ANONYMOUS.
    `offset`: file offset in bytes; must be page-aligned.
    Returns the mapped virtual address. -/
@[extern "swelib_mmap"]
opaque mmap_ (addr : UInt64) (length : USize) (prot : UInt32) (flags : UInt32)
    (fd : Int32) (offset : UInt64) : IO (Except Errno UInt64)

/-- Raw munmap(2) via C shim.
    `addr`: start of the region to unmap; must be page-aligned.
    `length`: size in bytes (rounded up to page boundary by the kernel). -/
@[extern "swelib_munmap"]
opaque munmap_ (addr : UInt64) (length : USize) : IO (Except Errno Unit)

/-- Raw mprotect(2) via C shim.
    `addr`: start of the region; must be page-aligned.
    `prot`: new PROT_* protection mask. -/
@[extern "swelib_mprotect"]
opaque mprotect_ (addr : UInt64) (length : USize) (prot : UInt32) : IO (Except Errno Unit)

/-- Raw brk(2) via C shim.
    Sets the program break to `addr`.
    Returns the actual new program break (may differ from `addr` due to page rounding). -/
@[extern "swelib_brk"]
opaque brk_ (addr : UInt64) : IO (Except Errno UInt64)

/-- Raw sbrk(2) via C shim.
    Increments the program break by `increment` bytes (may be negative).
    Returns the NEW program break (= old break + increment). -/
@[extern "swelib_sbrk"]
opaque sbrk_ (increment : Int64) : IO (Except Errno UInt64)

end SWELibImpl.Ffi.Memory
