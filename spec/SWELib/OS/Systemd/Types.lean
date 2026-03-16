import SWELib.OS.Io

/-!
# Systemd Types

Core types for the systemd unit/service lifecycle specification.

References:
- systemd.unit(5):    https://www.freedesktop.org/software/systemd/man/systemd.unit.html
- systemd.service(5): https://www.freedesktop.org/software/systemd/man/systemd.service.html
- systemctl(1):       https://www.freedesktop.org/software/systemd/man/systemctl.html
-/

namespace SWELib.OS

abbrev UnitId := Nat

inductive UnitType where
  | service | socket | device | mount | automount
  | swap | target | path | timer | slice | scope
  deriving DecidableEq, Repr

instance : ToString UnitType where
  toString u := match u with
    | .service => "service" | .socket => "socket" | .device => "device"
    | .mount => "mount" | .automount => "automount" | .swap => "swap"
    | .target => "target" | .path => "path" | .timer => "timer"
    | .slice => "slice" | .scope => "scope"

structure UnitName where
  name     : String
  unitType : UnitType
  deriving DecidableEq, Repr

instance : ToString UnitName where
  toString u := u.name ++ "." ++ toString u.unitType

inductive UnitLoadState where
  | loaded | notFound | badSetting | error | masked
  deriving DecidableEq, Repr

inductive UnitActiveState where
  | inactive | activating | active | reloading | deactivating | failed
  /-- A maintenance operation is in progress (e.g., fsck on a mount unit). -/
  | maintenance
  /-- Active and a new mount is being activated in its namespace. -/
  | refreshing
  deriving DecidableEq, Repr

inductive ServiceSubstate where
  | dead | startPre | start | startPost | running | exited
  | reload | stop | stopWatchdog | stopSigabrt | stopSigterm
  | stopSigkill | stopPost | finalWatchdog | finalSigterm
  | finalSigkill | failed | autoRestart | oomKill
  deriving DecidableEq, Repr

inductive ServiceType where
  | simple | exec | forking | oneshot | dbus
  | notify | notifyReload | idle
  deriving DecidableEq, Repr

inductive RestartPolicy where
  | no | onSuccess | onFailure | onAbnormal
  | onWatchdog | onAbort | always
  deriving DecidableEq, Repr

inductive DependencyKind where
  | wants | requires | requisite | bindsTo | partOf | upholds
  | conflicts | after | before | onSuccess | onFailure
  deriving DecidableEq, Repr

inductive UnitFileEnablementState where
  | enabled | enabledRuntime | linked | linkedRuntime
  | alias | masked | maskedRuntime | static | disabled
  | indirect | generated | transient | bad | unknown
  deriving DecidableEq, Repr

inductive OomPolicy where
  | continue | stop | kill
  deriving DecidableEq, Repr

inductive NotifyAccess where
  | none | main | exec | all
  deriving DecidableEq, Repr

inductive ServiceResult where
  | success | exitCode | signal | coreDump
  | watchdog | timeout | oomKill
  deriving DecidableEq, Repr

instance : BEq ServiceResult := inferInstance

/-- Signals used in systemd's stop/kill sequences. -/
inductive SystemdSignal where
  | SIGTERM | SIGKILL | SIGABRT
  deriving DecidableEq, Repr

end SWELib.OS
