import SWELib

/-!
# Docker CLI FFI

Raw `@[extern]` declaration for executing Docker CLI commands.
Uses fork/exec to run the `docker` binary and capture output.
-/

namespace SWELibImpl.Ffi.Docker

/-- Execute a Docker CLI command.
    Runs the binary at `bin` with the given `args`.
    Returns `Except.ok stdout` on exit code 0,
    or `Except.error stderr` otherwise. -/
@[extern "swelib_docker_exec"]
opaque dockerExec (bin : @& String) (args : @& Array String) : IO (Except String String)

end SWELibImpl.Ffi.Docker
