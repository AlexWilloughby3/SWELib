# Operating System

Linux/POSIX system abstractions: processes, memory, filesystems, sockets, and container isolation primitives.

## Modules

### Core System

| File | Spec Source | Key Types | Status |
|------|-----------|-----------|--------|
| `Io.lean` | POSIX | `Errno` (EBADF, EINTR, EIO, etc.), file descriptor model | Complete |
| `Process.lean` | POSIX | `PID`, fork/exec/exit/wait/kill | Complete |
| `FileSystem.lean` | POSIX | `AccessMode`, open/read/write/lseek/stat/unlink/mkdir/chmod | Complete |
| `Memory.lean` | Linux | mmap/munmap/mprotect/brk/sbrk, `/proc/[pid]/maps`, OOM scoring | Complete |
| `Sockets.lean` | POSIX | Socket operations and connection states | Complete |
| `Signals.lean` | POSIX | Disposition, masking, pending sets; sigaction/sigprocmask/kill | Complete |
| `Epoll.lean` | Linux | epoll_create/epoll_ctl/epoll_wait, level-triggered | Complete |
| `Environment.lean` | POSIX | getenv, getcwd, chdir, stdio | Complete |
| `Users.lean` | POSIX | `UserId`, `GroupId`, getuid/geteuid, permission checking | Complete |

### Container Isolation Primitives

| File | Spec Source | Key Types | Status |
|------|-----------|-----------|--------|
| `Cgroups.lean` | Linux cgroups v2 | Resource limits, cgroup operations | Complete |
| `Namespaces.lean` | Linux | PID/network/mount/IPC/UTS/user/cgroup/time namespaces; clone/unshare/setns | Complete |
| `Seccomp.lean` | Linux | Seccomp filter specification, syscall restriction | Complete |
| `Capabilities.lean` | Linux | CAP_CHOWN, CAP_DAC_OVERRIDE, CAP_SETUID, CAP_NET_BIND_SERVICE, etc. | Complete |

### Service Management

| File | Spec Source | Key Types | Status |
|------|-----------|-----------|--------|
| `Systemd.lean` | systemd | Unit lifecycle, state machine, operations | Complete |

### Isolation Framework

| File | Key Content | Status |
|------|-------------|--------|
| `Isolation/Types.lean` | Container/VM/bare-metal Node abstractions | Complete |
| `Isolation/Nodes.lean` | ContainerNode, VMNode, BareMetalNode, TransientNode | Complete |
| `Isolation/Simulation.lean` | Simulation relations between isolation levels | Complete |
| `Isolation/Refinement.lean` | Isolation refinement linking Nodes to Linux primitives | Complete |
