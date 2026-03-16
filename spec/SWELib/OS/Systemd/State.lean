import SWELib.OS.Systemd.Types

/-!
# Systemd State

The systemd service manager state: substate mapping, unit configuration,
per-unit entries, and the global unit table.
-/

namespace SWELib.OS

/-- Total mapping from ServiceSubstate to UnitActiveState.
    Faithful to systemd's service_state_translation_table. -/
def substateToActiveState : ServiceSubstate → UnitActiveState
  | .dead          => .inactive
  | .startPre      => .activating
  | .start         => .activating
  | .startPost     => .activating
  | .running       => .active
  | .exited        => .active
  | .reload        => .reloading
  | .stop          => .deactivating
  | .stopWatchdog  => .deactivating
  | .stopSigabrt   => .deactivating
  | .stopSigterm   => .deactivating
  | .stopSigkill   => .deactivating
  | .stopPost      => .deactivating
  | .finalWatchdog => .deactivating
  | .finalSigterm  => .deactivating
  | .finalSigkill  => .deactivating
  | .failed        => .failed
  | .autoRestart   => .activating
  | .oomKill       => .deactivating

/-- Static configuration of a service unit. -/
structure UnitConfig where
  unitName        : UnitName
  serviceType     : ServiceType
  restartPolicy   : RestartPolicy
  notifyAccess    : NotifyAccess
  oomPolicy       : OomPolicy
  remainAfterExit : Bool
  timeoutStartSec : Option Nat
  timeoutStopSec  : Option Nat
  watchdogSec     : Option Nat
  /-- Dependencies: (kind, target UnitId) pairs declared in the unit file. -/
  dependencies    : List (DependencyKind × UnitId)
  enablementState : UnitFileEnablementState
  deriving Repr

/-- Runtime state of a single unit in the service manager. -/
structure UnitEntry where
  config      : UnitConfig
  loadState   : UnitLoadState
  /-- Derived from substate; stored for fast access. -/
  activeState : UnitActiveState
  substate    : ServiceSubstate
  result      : ServiceResult
  /-- Main PID of the service, if running. -/
  mainPid     : Option Nat
  deriving Repr

/-- The global unit table: maps UnitId to UnitEntry. -/
def UnitTable := Nat → Option UnitEntry

def UnitTable.empty : UnitTable := fun _ => none

def UnitTable.lookup (t : UnitTable) (id : UnitId) : Option UnitEntry :=
  t id

def UnitTable.update (t : UnitTable) (id : UnitId) (e : UnitEntry) : UnitTable :=
  fun n => if n = id then some e else t n

def UnitTable.remove (t : UnitTable) (id : UnitId) : UnitTable :=
  fun n => if n = id then none else t n

/-- Complete systemd manager state. -/
structure SystemdState where
  unitTable : UnitTable
  /-- Name-to-id index for reverse lookup. -/
  nameIndex : UnitName → Option UnitId

def SystemdState.empty : SystemdState :=
  { unitTable := UnitTable.empty
    nameIndex := fun _ => none }

end SWELib.OS
