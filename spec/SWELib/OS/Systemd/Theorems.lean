import SWELib.OS.Systemd.Operations

/-!
# Systemd Theorems

Properties of the systemd service manager state machine.
-/

namespace SWELib.OS

/-! ## substateToActiveState structural properties -/

/-- All stop/kill/final substates map to deactivating. -/
theorem stopSubstates_map_to_deactivating (sub : ServiceSubstate)
    (h : sub = .stop ∨ sub = .stopWatchdog ∨ sub = .stopSigabrt ∨
         sub = .stopSigterm ∨ sub = .stopSigkill ∨ sub = .stopPost ∨
         sub = .finalWatchdog ∨ sub = .finalSigterm ∨
         sub = .finalSigkill ∨ sub = .oomKill) :
    substateToActiveState sub = .deactivating := by
  rcases h with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl <;> rfl

/-- All start substates and autoRestart map to activating. -/
theorem startSubstates_map_to_activating (sub : ServiceSubstate)
    (h : sub = .startPre ∨ sub = .start ∨ sub = .startPost ∨ sub = .autoRestart) :
    substateToActiveState sub = .activating := by
  rcases h with rfl | rfl | rfl | rfl <;> rfl

/-- running and exited substates map to active. -/
theorem activeSubstates_map_to_active (sub : ServiceSubstate)
    (h : sub = .running ∨ sub = .exited) :
    substateToActiveState sub = .active := by
  rcases h with rfl | rfl <;> rfl

/-- dead substate maps to inactive. -/
theorem dead_maps_to_inactive : substateToActiveState .dead = .inactive := rfl

/-- failed substate maps to failed. -/
theorem failed_maps_to_failed : substateToActiveState .failed = .failed := rfl

/-! ## Masked unit invariants -/

/-- A masked unit cannot be started: start returns EPERM. -/
theorem maskedUnitCannotStart (s : SystemdState) (id : UnitId) (entry : UnitEntry)
    (h : s.unitTable.lookup id = some entry)
    (hm : entry.loadState = .masked) :
    (s.start id).2 = .error .EPERM := by
  simp [SystemdState.start, UnitTable.lookup] at *
  simp [h, hm]

/-! ## Stop transitions -/

/-- After stop, the unit reaches inactive (dead substate via runStopPost). -/
theorem inactiveUnitAfterStop (s : SystemdState) (id : UnitId) (entry : UnitEntry)
    (h : s.unitTable.lookup id = some entry)
    (hact : ¬ entry.activeState = .inactive) :
    let (s', _) := s.stop id
    match s'.unitTable.lookup id with
    | some e => e.activeState = .inactive
    | none => False := by
  simp only [SystemdState.stop, UnitTable.lookup] at *
  simp [h, hact, SystemdState.runStopPost, UnitTable.lookup, UnitTable.update,
        UnitEntry.mk', substateToActiveState]

/-! ## Start transitions -/

/-- A successful start transitions the unit to activating. -/
theorem startTransitionsToActivating (s : SystemdState) (id : UnitId) (entry : UnitEntry)
    (h : s.unitTable.lookup id = some entry)
    (hnm : ¬ entry.loadState = .masked)
    (hna : ¬ entry.activeState = .active) :
    match (s.start id).1.unitTable.lookup id with
    | some e => e.activeState = .activating
    | none => False := by
  simp only [SystemdState.start, UnitTable.lookup] at *
  simp [h, hnm, hna, UnitTable.update, UnitEntry.mk', substateToActiveState]

/-! ## Reload requires active -/

/-- Reload fails with EINVAL when the unit is not active. -/
theorem reloadRequiresActive (s : SystemdState) (id : UnitId) (entry : UnitEntry)
    (h : s.unitTable.lookup id = some entry)
    (hna : ¬ entry.activeState = .active) :
    (s.reload id).2 = .error .EINVAL := by
  simp only [SystemdState.reload, UnitTable.lookup] at *
  simp [h, hna]

/-! ## Restart policy -/

/-- Restart=always always restarts regardless of result. -/
theorem shouldRestart_always (r : ServiceResult) :
    shouldRestart r .always = true := by
  simp [shouldRestart]

/-- Restart=no never restarts. -/
theorem shouldRestart_no (r : ServiceResult) :
    shouldRestart r .no = false := by
  simp [shouldRestart]

/-- Restart=on-success restarts only on success. -/
theorem shouldRestart_onSuccess_iff (r : ServiceResult) :
    shouldRestart r .onSuccess = (r == .success) := by
  simp [shouldRestart]

/-- Restart=on-failure restarts on any non-success result. -/
theorem shouldRestart_onFailure_iff (r : ServiceResult) :
    shouldRestart r .onFailure = (r != .success) := by
  simp [shouldRestart]

/-! ## ExecStopPost unconditional -/

/-- runStopPost transitions a present unit to dead/inactive, preserving its result.
    Models the unconditional ExecStopPost guarantee. -/
theorem stopPost_unconditional (s : SystemdState) (id : UnitId) (entry : UnitEntry)
    (h : s.unitTable.lookup id = some entry) :
    match (s.runStopPost id).unitTable.lookup id with
    | some e => e.substate = .dead ∧ e.result = entry.result
    | none => False := by
  simp only [SystemdState.runStopPost, UnitTable.lookup] at *
  simp [h, UnitTable.update, UnitEntry.mk']

/-! ## Oneshot with RemainAfterExit -/

/-- A oneshot service with RemainAfterExit=true reaches exited on success. -/
theorem oneshotRemainAfterExitReachesExited (s : SystemdState) (id : UnitId)
    (entry : UnitEntry) (pid : Option Nat)
    (h : s.unitTable.lookup id = some entry)
    (ht : entry.config.serviceType = .oneshot)
    (hr : entry.config.remainAfterExit = true) :
    match (s.completeStart id pid true).unitTable.lookup id with
    | some e => e.substate = .exited
    | none => False := by
  simp only [SystemdState.completeStart, UnitTable.lookup] at *
  simp [h, ht, hr, UnitTable.update, UnitEntry.mk']

/-! ## Conflicts invariant -/

/-- An inductive predicate asserting that two units with a Conflicts dependency
    are never simultaneously active. -/
inductive ConflictsInvariant : SystemdState → Prop where
  | intro : (∀ id1 id2 : UnitId,
      ∀ e1 e2 : UnitEntry,
        s.unitTable.lookup id1 = some e1 →
        s.unitTable.lookup id2 = some e2 →
        (DependencyKind.conflicts, id2) ∈ e1.config.dependencies →
        ¬(e1.activeState = .active ∧ e2.activeState = .active)) →
    ConflictsInvariant s

/-- The empty state trivially satisfies the conflicts invariant. -/
theorem conflictsInvariant_empty : ConflictsInvariant SystemdState.empty := by
  constructor
  intro id1 _ _ _ h1
  simp [SystemdState.empty, UnitTable.empty, UnitTable.lookup] at h1

/-! ## Mask then start gives EPERM -/

/-- Masking a unit and then starting it returns EPERM. -/
theorem mask_then_start_eperm (s : SystemdState) (id : UnitId) (entry : UnitEntry)
    (h : s.unitTable.lookup id = some entry) :
    let (s', _) := s.mask id
    (s'.start id).2 = .error .EPERM := by
  simp only [SystemdState.mask, SystemdState.start, UnitTable.lookup] at *
  simp [h, UnitTable.update]

/-! ## resetFailed requires failed -/

/-- resetFailed on a non-failed unit returns EINVAL. -/
theorem resetFailed_requiresFailed (s : SystemdState) (id : UnitId) (entry : UnitEntry)
    (h : s.unitTable.lookup id = some entry)
    (hnf : ¬ entry.activeState = .failed) :
    (s.resetFailed id).2 = .error .EINVAL := by
  simp only [SystemdState.resetFailed, UnitTable.lookup] at *
  simp [h, hnf]

/-! ## Frame properties -/

/-- start does not modify other units. -/
theorem start_preserves_other (s : SystemdState) (id other : UnitId)
    (hne : other ≠ id) :
    (s.start id).1.unitTable.lookup other = s.unitTable.lookup other := by
  unfold SystemdState.start
  simp only [UnitTable.lookup]
  split
  · rfl
  · next entry heq =>
    split
    · rfl
    · split
      · rfl
      · simp [UnitTable.update, hne]

/-- stop does not modify other units. -/
theorem stop_preserves_other (s : SystemdState) (id other : UnitId)
    (hne : other ≠ id) :
    (s.stop id).1.unitTable.lookup other = s.unitTable.lookup other := by
  unfold SystemdState.stop
  simp only [UnitTable.lookup]
  split
  · rfl
  · next entry heq =>
    split
    · rfl
    · simp [SystemdState.runStopPost, UnitTable.lookup, UnitTable.update, hne]

end SWELib.OS
