import SWELib.OS.Signals.Operations

/-!
# Signals -- Invariants

Key theorems about sigaction, sigprocmask, sigpending, and kill.
-/

namespace SWELib.OS.Signals

/-! ## sigaction invariants -/

/-- sigaction on SIGKILL with a new disposition returns EINVAL. -/
theorem sigaction_kill_einval (act : SignalDisposition) (state : SignalState) :
    (sigaction .SIGKILL (some act) state).2 = .error .EINVAL := by
  simp [sigaction]

/-- sigaction on SIGSTOP with a new disposition returns EINVAL. -/
theorem sigaction_stop_einval (act : SignalDisposition) (state : SignalState) :
    (sigaction .SIGSTOP (some act) state).2 = .error .EINVAL := by
  simp [sigaction]

/-- Query (act = none) does not modify state. -/
theorem sigaction_query_no_change (signum : Signal) (state : SignalState) :
    (sigaction signum none state).1 = state := by
  simp [sigaction]

/-- After a successful sigaction, the new disposition is installed. -/
theorem sigaction_updates_disposition (signum : Signal) (act : SignalDisposition)
    (state : SignalState)
    (h_kill : signum ≠ .SIGKILL) (h_stop : signum ≠ .SIGSTOP) :
    (sigaction signum (some act) state).1.dispositions signum = act := by
  simp only [sigaction]
  have hk : (signum == Signal.SIGKILL) = false := by simp [h_kill]
  have hs : (signum == Signal.SIGSTOP) = false := by simp [h_stop]
  simp [hk, hs]

/-- sigaction returns the old disposition on success. -/
theorem sigaction_returns_old_disposition (signum : Signal) (act : SignalDisposition)
    (state : SignalState)
    (h_kill : signum ≠ .SIGKILL) (h_stop : signum ≠ .SIGSTOP) :
    (sigaction signum (some act) state).2 = .ok (state.dispositions signum) := by
  simp only [sigaction]
  have hk : (signum == Signal.SIGKILL) = false := by simp [h_kill]
  have hs : (signum == Signal.SIGSTOP) = false := by simp [h_stop]
  simp [hk, hs]

/-! ## sigprocmask invariants -/

/-- Query (set = none) does not modify state. -/
theorem sigprocmask_query_no_change (how : SigActionHow) (state : SignalState) :
    (sigprocmask how none state).1 = state := by
  simp [sigprocmask]

/-- sigprocmask always returns the previous blocked set. -/
theorem sigprocmask_returns_old_mask (how : SigActionHow) (set : SigSet)
    (state : SignalState) :
    (sigprocmask how (some set) state).2 = .ok state.blocked := by
  simp [sigprocmask]

/-! ## sigpending invariants -/

/-- sigpending always succeeds and returns the pending set. -/
theorem sigpending_returns_pending (state : SignalState) :
    sigpending state = .ok state.pending := by
  simp [sigpending]

/-! ## kill invariants -/

/-- kill with sig=none (signal 0) does not modify the process table. -/
theorem kill_null_sig_no_change (target : KillTarget) (callerPid : Nat)
    (t : SignalTable) :
    (kill target none callerPid t).1 = t := by
  simp [kill]

/-! ## effectiveMask invariants -/

/-- effectiveMask never contains SIGKILL. -/
theorem effectiveMask_no_sigkill (ss : SigSet) :
    SigSet.member .SIGKILL (effectiveMask ss) = false := by
  simp only [SigSet.member, effectiveMask]
  induction ss with
  | nil => simp
  | cons hd tl ih =>
    simp only [List.filter_cons]
    split
    · simp only [List.any_cons]
      rename_i h
      simp only [Bool.and_eq_true, bne_iff_ne, ne_eq] at h
      have hbeq : (Signal.SIGKILL == hd) = false := by
        rw [beq_eq_false_iff_ne]
        exact Ne.symm h.1
      rw [hbeq, Bool.false_or]
      exact ih
    · exact ih

/-- effectiveMask never contains SIGSTOP. -/
theorem effectiveMask_no_sigstop (ss : SigSet) :
    SigSet.member .SIGSTOP (effectiveMask ss) = false := by
  simp only [SigSet.member, effectiveMask]
  induction ss with
  | nil => simp
  | cons hd tl ih =>
    simp only [List.filter_cons]
    split
    · simp only [List.any_cons]
      rename_i h
      simp only [Bool.and_eq_true, bne_iff_ne, ne_eq] at h
      have hbeq : (Signal.SIGSTOP == hd) = false := by
        rw [beq_eq_false_iff_ne]
        exact Ne.symm h.2
      rw [hbeq, Bool.false_or]
      exact ih
    · exact ih

/-! ## Additional sigprocmask invariants -/

/-- SIGKILL is never in the blocked set after sigprocmask block or setmask. -/
theorem sigprocmask_block_setmask_no_sigkill (set : SigSet) (state : SignalState) :
    SigSet.member .SIGKILL (sigprocmask .block (some set) state).1.blocked = false ∧
    SigSet.member .SIGKILL (sigprocmask .setmask (some set) state).1.blocked = false := by
  simp only [sigprocmask]
  exact ⟨effectiveMask_no_sigkill _, effectiveMask_no_sigkill _⟩

/-- SIGSTOP is never in the blocked set after sigprocmask block or setmask. -/
theorem sigprocmask_block_setmask_no_sigstop (set : SigSet) (state : SignalState) :
    SigSet.member .SIGSTOP (sigprocmask .block (some set) state).1.blocked = false ∧
    SigSet.member .SIGSTOP (sigprocmask .setmask (some set) state).1.blocked = false := by
  simp only [sigprocmask]
  exact ⟨effectiveMask_no_sigstop _, effectiveMask_no_sigstop _⟩

/-! ## deliverSignal invariants -/

/-- deliverSignal with an ignored disposition does not modify pending. -/
theorem deliverSignal_ignore_no_pending (sig : Signal) (state : SignalState)
    (h : state.dispositions sig = .ignore) :
    (deliverSignal sig state).pending = state.pending := by
  simp only [deliverSignal]
  split
  · -- sig is blocked
    simp [h]
  · -- sig is not blocked
    rfl

/-- deliverSignal with a non-ignored disposition adds to pending when blocked. -/
private theorem member_insert_self (sig : Signal) (ss : SigSet) :
    SigSet.member sig (SigSet.insert sig ss) = true := by
  simp only [SigSet.insert]
  split
  · assumption
  · simp only [SigSet.member, List.any_cons, beq_self_eq_true, Bool.true_or]

theorem deliverSignal_blocked_adds_pending (sig : Signal) (state : SignalState)
    (h_blocked : SigSet.member sig state.blocked = true)
    (h_disp : state.dispositions sig ≠ .ignore) :
    SigSet.member sig (deliverSignal sig state).pending = true := by
  simp only [deliverSignal, h_blocked, ite_true]
  match h_match : state.dispositions sig with
  | .ignore => exact absurd h_match h_disp
  | .default => exact member_insert_self sig state.pending
  | .handler m f => exact member_insert_self sig state.pending

end SWELib.OS.Signals
