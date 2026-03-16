import SWELib.OS.FileSystem

/-!
# Process Environment

Environment variables, stdio file descriptors, and working directory.

References:
- environ(7): https://man7.org/linux/man-pages/man7/environ.7.html
- getenv(3):  https://man7.org/linux/man-pages/man3/getenv.3.html
- getcwd(3):  https://man7.org/linux/man-pages/man3/getcwd.3.html
- chdir(2):   https://man7.org/linux/man-pages/man2/chdir.2.html
-/

namespace SWELib.OS

/-! ## Environment variables -/

/-- The process environment: a partial map from variable names to values. -/
def Environment := String → Option String

/-- The empty environment (no variables set). -/
def Environment.empty : Environment := fun _ => none

/-- Get an environment variable. -/
def Environment.get (env : Environment) (key : String) : Option String :=
  env key

/-- Set an environment variable. -/
def Environment.set (env : Environment) (key value : String) : Environment :=
  fun k => if k == key then some value else env k

/-- Unset (remove) an environment variable. -/
def Environment.unset (env : Environment) (key : String) : Environment :=
  fun k => if k == key then none else env k

/-! ## Standard I/O file descriptors -/

/-- stdin is fd 0. -/
def stdin : FileDescriptor := ⟨0⟩

/-- stdout is fd 1. -/
def stdout : FileDescriptor := ⟨1⟩

/-- stderr is fd 2. -/
def stderr : FileDescriptor := ⟨2⟩

/-- An fd table with stdin/stdout/stderr pre-opened as pipes. -/
def FdTable.withStdio : FdTable :=
  FdTable.empty
    |>.update 0 (.open .pipe)
    |>.update 1 (.open .pipe)
    |>.update 2 (.open .pipe)

/-! ## Working directory -/

/-- The current working directory, represented as path segments from root. -/
structure WorkingDir where
  pathSegs : List String
  deriving Repr

/-- The root directory as working directory. -/
def WorkingDir.root : WorkingDir := ⟨[]⟩

/-- `chdir(2)`: change the working directory.
    Succeeds only if the target path resolves to a directory. -/
def chdir (root : DirEntry) (pathSegs : List String) :
    Except Errno WorkingDir :=
  match root.resolve pathSegs with
  | some (.dir _ _ _) => .ok ⟨pathSegs⟩
  | some (.file _ _ _) => .error .ENOTDIR
  | none => .error .ENOENT

/-! ## Theorems -/

/-- setenv then getenv on the same key returns the value. -/
theorem Environment.setenv_getenv_roundtrip (env : Environment)
    (k v : String) :
    (env.set k v).get k = some v := by
  simp [Environment.get, Environment.set, BEq.beq]

/-- setenv does not affect other keys. -/
theorem Environment.setenv_preserves_other (env : Environment)
    (k1 k2 v : String) (h : k1 ≠ k2) :
    (env.set k1 v).get k2 = env.get k2 := by
  simp [Environment.get, Environment.set, beq_iff_eq, Ne.symm h]

/-- unsetenv removes the key. -/
theorem Environment.unsetenv_removes (env : Environment) (k : String) :
    (env.unset k).get k = none := by
  simp [Environment.get, Environment.unset, BEq.beq]

/-- unsetenv does not affect other keys. -/
theorem Environment.unsetenv_preserves_other (env : Environment)
    (k1 k2 : String) (h : k1 ≠ k2) :
    (env.unset k1).get k2 = env.get k2 := by
  simp [Environment.get, Environment.unset, beq_iff_eq, Ne.symm h]

/-- stdin is open in withStdio. -/
theorem FdTable.withStdio_stdin_open :
    FdTable.withStdio.isOpen stdin = true := by
  simp [FdTable.withStdio, FdTable.isOpen, FdTable.update, stdin]

/-- stdout is open in withStdio. -/
theorem FdTable.withStdio_stdout_open :
    FdTable.withStdio.isOpen stdout = true := by
  simp [FdTable.withStdio, FdTable.isOpen, FdTable.update, stdout]

/-- stderr is open in withStdio. -/
theorem FdTable.withStdio_stderr_open :
    FdTable.withStdio.isOpen stderr = true := by
  simp [FdTable.withStdio, FdTable.isOpen, FdTable.update, stderr]

/-- chdir to a non-existent path returns ENOENT. -/
theorem chdir_nonexistent_enoent (root : DirEntry) (pathSegs : List String)
    (h : root.resolve pathSegs = none) :
    chdir root pathSegs = .error .ENOENT := by
  simp [chdir, h]

/-- chdir to a file returns ENOTDIR. -/
theorem chdir_file_enotdir (root : DirEntry) (pathSegs : List String)
    (name : String) (contents : ByteArray) (perms : Permissions)
    (h : root.resolve pathSegs = some (.file name contents perms)) :
    chdir root pathSegs = .error .ENOTDIR := by
  simp [chdir, h]

end SWELib.OS
