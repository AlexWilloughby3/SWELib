import SWELib.OS.Systemd.State

/-!
# Systemd Operations

Pure state-transition functions for the systemd service manager.

All operations follow the pattern:
  SystemdState -> args -> SystemdState x Except Errno Result

References:
- systemd.service(5): https://www.freedesktop.org/software/systemd/man/systemd.service.html
- systemctl(1): https://www.freedesktop.org/software/systemd/man/systemctl.html
-/

namespace SWELib.OS

/-! ## Smart constructor -/

/-- Build a UnitEntry with activeState computed from substate. -/
def UnitEntry.mk' (config : UnitConfig) (loadState : UnitLoadState)
    (substate : ServiceSubstate) (result : ServiceResult)
    (mainPid : Option Nat) : UnitEntry :=
  { config
    loadState
    activeState := substateToActiveState substate
    substate
    result
    mainPid }

/-! ## Restart policy -/

/-- Pure function: given a ServiceResult and RestartPolicy, should the service restart? -/
def shouldRestart (result : ServiceResult) (policy : RestartPolicy) : Bool :=
  match policy with
  | .no         => false
  | .always     => true
  | .onSuccess  => result == .success
  | .onFailure  => result != .success
  | .onAbnormal => result == .signal || result == .watchdog
                   || result == .coreDump || result == .timeout
  | .onWatchdog => result == .watchdog
  | .onAbort    => result == .signal || result == .coreDump

/-! ## ExecStopPost (unconditional) -/

/-- Internal helper: transition a unit to dead (inactive) via ExecStopPost.
    Models the systemd guarantee that ExecStopPost always runs, regardless of
    whether start succeeded. The prior `result` is preserved so failure
    information is not overwritten. -/
def SystemdState.runStopPost (s : SystemdState) (id : UnitId) : SystemdState :=
  match s.unitTable.lookup id with
  | none => s
  | some entry =>
    let entry' := UnitEntry.mk' entry.config entry.loadState .dead entry.result none
    { s with unitTable := s.unitTable.update id entry' }

/-! ## start -/

/-- `systemctl start`: attempt to activate a unit.
    Fails with EPERM if loadState = masked.
    Fails with EALREADY if already active.
    On success: transitions substate to startPre (activating). -/
def SystemdState.start (s : SystemdState) (id : UnitId) :
    SystemdState × Except Errno Unit :=
  match s.unitTable.lookup id with
  | none => (s, .error .ENOENT)
  | some entry =>
    if entry.loadState == .masked then (s, .error .EPERM)
    else if entry.activeState == .active then (s, .error .EALREADY)
    else
      let entry' := UnitEntry.mk' entry.config entry.loadState
                      .startPre entry.result entry.mainPid
      ({ s with unitTable := s.unitTable.update id entry' }, .ok ())

/-! ## completeStart -/

/-- Internal transition: mark a service as fully started.
    - simple/exec/notify/etc: substate = running with mainPid.
    - oneshot with RemainAfterExit=yes: substate = exited.
    - oneshot with RemainAfterExit=no: substate = dead (unit returns to inactive).
    - failure: substate = failed. -/
def SystemdState.completeStart (s : SystemdState) (id : UnitId)
    (newPid : Option Nat) (success : Bool) : SystemdState :=
  match s.unitTable.lookup id with
  | none => s
  | some entry =>
    let (sub, res) :=
      if !success then (.failed, ServiceResult.exitCode)
      else match entry.config.serviceType with
        | .oneshot =>
          if entry.config.remainAfterExit then (.exited, ServiceResult.success)
          else (.dead, ServiceResult.success)
        | _ => (.running, ServiceResult.success)
    let entry' := UnitEntry.mk' entry.config entry.loadState sub res newPid
    { s with unitTable := s.unitTable.update id entry' }

/-! ## stop -/

/-- `systemctl stop`: deactivate a unit.
    ExecStopPost runs unconditionally (modeled via runStopPost). -/
def SystemdState.stop (s : SystemdState) (id : UnitId) :
    SystemdState × Except Errno Unit :=
  match s.unitTable.lookup id with
  | none => (s, .error .ENOENT)
  | some entry =>
    if entry.activeState == .inactive then (s, .error .EINVAL)
    else
      let e' := UnitEntry.mk' entry.config entry.loadState .stop entry.result none
      let s1 := { s with unitTable := s.unitTable.update id e' }
      let s2 := s1.runStopPost id
      (s2, .ok ())

/-! ## restart -/

/-- `systemctl restart`: stop then start.
    Modeled as transitioning to autoRestart substate. -/
def SystemdState.restart (s : SystemdState) (id : UnitId) :
    SystemdState × Except Errno Unit :=
  match s.unitTable.lookup id with
  | none => (s, .error .ENOENT)
  | some entry =>
    if entry.loadState == .masked then (s, .error .EPERM)
    else
      let entry' := UnitEntry.mk' entry.config entry.loadState
                      .autoRestart entry.result entry.mainPid
      ({ s with unitTable := s.unitTable.update id entry' }, .ok ())

/-! ## reload -/

/-- `systemctl reload`: send reload signal to running unit.
    Only valid when activeState = active. -/
def SystemdState.reload (s : SystemdState) (id : UnitId) :
    SystemdState × Except Errno Unit :=
  match s.unitTable.lookup id with
  | none => (s, .error .ENOENT)
  | some entry =>
    if entry.activeState != .active then (s, .error .EINVAL)
    else
      let entry' := UnitEntry.mk' entry.config entry.loadState
                      .reload entry.result entry.mainPid
      ({ s with unitTable := s.unitTable.update id entry' }, .ok ())

/-! ## enable / disable -/

/-- `systemctl enable`: transition enablement state to enabled.
    Does not start the unit. Fails if masked. -/
def SystemdState.enable (s : SystemdState) (id : UnitId) :
    SystemdState × Except Errno Unit :=
  match s.unitTable.lookup id with
  | none => (s, .error .ENOENT)
  | some entry =>
    if entry.loadState == .masked then (s, .error .EPERM)
    else
      let cfg' := { entry.config with enablementState := .enabled }
      let entry' := { entry with config := cfg' }
      ({ s with unitTable := s.unitTable.update id entry' }, .ok ())

/-- `systemctl disable`: transition enablement state to disabled. -/
def SystemdState.disable (s : SystemdState) (id : UnitId) :
    SystemdState × Except Errno Unit :=
  match s.unitTable.lookup id with
  | none => (s, .error .ENOENT)
  | some entry =>
    let cfg' := { entry.config with enablementState := .disabled }
    let entry' := { entry with config := cfg' }
    ({ s with unitTable := s.unitTable.update id entry' }, .ok ())

/-! ## mask / unmask -/

/-- `systemctl mask`: prevent the unit from being started. -/
def SystemdState.mask (s : SystemdState) (id : UnitId) :
    SystemdState × Except Errno Unit :=
  match s.unitTable.lookup id with
  | none => (s, .error .ENOENT)
  | some entry =>
    let entry' := { entry with loadState := .masked }
    ({ s with unitTable := s.unitTable.update id entry' }, .ok ())

/-- `systemctl unmask`: restore a masked unit to loaded. -/
def SystemdState.unmask (s : SystemdState) (id : UnitId) :
    SystemdState × Except Errno Unit :=
  match s.unitTable.lookup id with
  | none => (s, .error .ENOENT)
  | some entry =>
    if entry.loadState != .masked then (s, .ok ())
    else
      let entry' := { entry with loadState := .loaded }
      ({ s with unitTable := s.unitTable.update id entry' }, .ok ())

/-! ## kill -/

/-- `systemctl kill`: record a signal delivery to a unit.
    Only valid when unit has a mainPid. -/
def SystemdState.kill (s : SystemdState) (id : UnitId) (sig : SystemdSignal) :
    SystemdState × Except Errno Unit :=
  match s.unitTable.lookup id with
  | none => (s, .error .ENOENT)
  | some entry =>
    match entry.mainPid with
    | none => (s, .error .ESRCH)
    | some _ =>
      let sub := match sig with
        | .SIGTERM => ServiceSubstate.stopSigterm
        | .SIGKILL => ServiceSubstate.stopSigkill
        | .SIGABRT => ServiceSubstate.stopSigabrt
      let entry' := UnitEntry.mk' entry.config entry.loadState
                      sub entry.result entry.mainPid
      ({ s with unitTable := s.unitTable.update id entry' }, .ok ())

/-! ## resetFailed -/

/-- `systemctl reset-failed`: clear a unit's failed state back to inactive. -/
def SystemdState.resetFailed (s : SystemdState) (id : UnitId) :
    SystemdState × Except Errno Unit :=
  match s.unitTable.lookup id with
  | none => (s, .error .ENOENT)
  | some entry =>
    if entry.activeState != .failed then (s, .error .EINVAL)
    else
      let entry' := UnitEntry.mk' entry.config entry.loadState .dead .success none
      ({ s with unitTable := s.unitTable.update id entry' }, .ok ())

end SWELib.OS
