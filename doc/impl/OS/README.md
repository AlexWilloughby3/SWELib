# OS Implementations

Operating system abstractions that convert spec-level types to kernel-level integers and call through FFI.

## Modules

| File | Description |
|------|-------------|
| `SocketOps.lean` | Socket type conversion: `AddressFamily`, `SocketType`, shutdown direction to `UInt32` |
| `FileOps.lean` | File flag encoding: `AccessMode`, `OpenFlags` to Linux O_ bitmask values |
| `ProcessOps.lean` | Process wrappers: `forkProcess`, `exitProcess`, `waitForChild`, `killProcess`, `getPid` |
| `SignalOps.lean` | Signal encoding: `Signal` to kernel number, `SigSet` to bitmask, signal disposition |
| `MemoryOps.lean` | Memory syscall wrappers: mmap, munmap, mprotect; `/proc/maps` parsing; OOM score reading |
