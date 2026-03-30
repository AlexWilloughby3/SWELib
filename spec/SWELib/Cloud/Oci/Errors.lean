import SWELib.OS.Io
import SWELib.Cloud.Oci.Types

/-!
# OCI Runtime Errors

Error types for OCI runtime operations.
-/

namespace SWELib.Cloud.Oci

/-- OCI runtime operation errors. -/
inductive OciError where
  /-- Container not found. -/
  | containerNotFound
  /-- Container ID is not unique. -/
  | containerIdNotUnique
  /-- Invalid container state for operation. -/
  | invalidState
  /-- Invalid container configuration. -/
  | invalidConfig
  /-- Hook execution failed. -/
  | hookFailed (hookName : String) (error : String)
  /-- System error from underlying OS. -/
  | systemError (errno : SWELib.OS.Errno)
  deriving Repr, Inhabited

instance : ToString OciError where
  toString err :=
    match err with
    | .containerNotFound => "container not found"
    | .containerIdNotUnique => "container ID not unique"
    | .invalidState => "invalid container state"
    | .invalidConfig => "invalid container configuration"
    | .hookFailed hookName error => s!"hook '{hookName}' failed: {error}"
    | .systemError errno => s!"system error: {reprStr errno}"

/-- Convert an OCI error to a string error message. -/
def OciError.toErrorMessage (err : OciError) : String :=
  toString err

/-- Check if an error is a system error. -/
def OciError.isSystemError : OciError → Bool
  | .systemError _ => true
  | _ => false

/-- Check if an error is a configuration error. -/
def OciError.isConfigError : OciError → Bool
  | .invalidConfig => true
  | _ => false

/-- Check if an error is a state transition error. -/
def OciError.isStateError : OciError → Bool
  | .invalidState => true
  | _ => false

/-- Create a hook failed error. -/
def OciError.hookFailedError (hookName : String) (error : String) : OciError :=
  .hookFailed hookName error

/-- Create a system error from an Errno. -/
def OciError.fromErrno (errno : SWELib.OS.Errno) : OciError :=
  .systemError errno

end SWELib.Cloud.Oci
