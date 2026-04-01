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
  let flags := #[
    "-Wno-deprecated-declarations",
    "-Wno-int-conversion",
    "-I", leanIncDir.toString,
    "-I", "/opt/homebrew/opt/openssl@3/include",
    "-I", "/opt/homebrew/include/postgresql@14",
    "-I", "/opt/homebrew/opt/libssh2/include"
  ]
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
