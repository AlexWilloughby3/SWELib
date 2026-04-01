import Lake
open Lake DSL

package SWELib

lean_lib SWELib where
  srcDir := "spec"
  roots := #[`SWELib]

@[default_target]
lean_lib SWELibImpl where
  srcDir := "impl"
  roots := #[`SWELibImpl]
  moreLinkArgs := #["-lssl", "-lcrypto", "-lpq", "-lcurl", "-lssh2"]
  extraDepTargets := #[`swelib_ffi]

private def pkgConfigCflags (lib : String) : IO (Array String) := do
  let out ← IO.Process.output { cmd := "pkg-config", args := #["--cflags-only-I", lib] }
  if out.exitCode != 0 then return #[]
  return out.stdout.trim.splitOn " " |>.filter (· != "") |>.toArray

extern_lib swelib_ffi pkg := do
  let ffiDir := pkg.dir / "impl" / "ffi"
  let buildDir := pkg.buildDir / "ffi"
  let leanIncDir ← getLeanIncludeDir
  let cNames := #[
    "swelib_syscalls",
    "swelib_libssl",
    "swelib_libpq",
    "swelib_libcurl",
    "swelib_libssh",
    "swelib_docker"
  ]
  let sslInc ← pkgConfigCflags "openssl"
  let pqInc ← pkgConfigCflags "libpq"
  let ssh2Inc ← pkgConfigCflags "libssh2"
  let flags := #[
    "-Wno-deprecated-declarations",
    "-Wno-int-conversion",
    "-I", leanIncDir.toString
  ] ++ sslInc ++ pqInc ++ ssh2Inc
  let libFile := buildDir / "libswelib_ffi.a"
  Job.async do
    IO.FS.createDirAll buildDir
    let mut oFiles : Array System.FilePath := #[]
    for name in cNames do
      let src := ffiDir / s!"{name}.c"
      let obj := buildDir / s!"{name}.o"
      compileO obj src flags
      oFiles := oFiles.push obj
    compileStaticLib libFile oFiles
    return libFile
