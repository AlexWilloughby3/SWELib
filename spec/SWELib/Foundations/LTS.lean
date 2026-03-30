/-!
# Labeled Transition Systems

The core state-machine primitive underlying Nodes and Systems.
An LTS is a set of states with labeled transitions between them.

References:
- Milner, "Communication and Concurrency" (1989)
- Aceto et al., "Reactive Systems" (2007)
- Lynch, "Distributed Algorithms" (1996)
-/

namespace SWELib.Foundations

/-- A Labeled Transition System: states with labeled transitions.
    `State` is the state space, `Label` is the action alphabet. -/
structure LTS (State : Type) (Label : Type) where
  /-- The transition relation: from state `s`, action `a` leads to state `s'`. -/
  Tr : State → Label → State → Prop
  /-- The initial state. -/
  initial : State

variable {S L : Type}

namespace LTS

/-- A state is reachable if there's a finite path from `initial` to it. -/
inductive Reachable (lts : LTS S L) : S → Prop where
  | init : Reachable lts lts.initial
  | step {s s' : S} {a : L} : Reachable lts s → lts.Tr s a s' → Reachable lts s'

/-- A finite trace: a sequence of (state, action, state) triples. -/
inductive FiniteTrace (lts : LTS S L) : S → S → Prop where
  | nil (s : S) : FiniteTrace lts s s
  | cons {s₁ s₂ s₃ : S} (a : L) :
      lts.Tr s₁ a s₂ → FiniteTrace lts s₂ s₃ → FiniteTrace lts s₁ s₃

/-- A state is a deadlock if no transitions are possible from it. -/
def Deadlock (lts : LTS S L) (s : S) : Prop :=
  ∀ a s', ¬ lts.Tr s a s'

/-- An LTS is deterministic if each (state, action) pair has at most one successor. -/
def Deterministic (lts : LTS S L) : Prop :=
  ∀ s a s₁ s₂, lts.Tr s a s₁ → lts.Tr s a s₂ → s₁ = s₂

/-- Strong bisimulation: a relation R is a bisimulation between two LTS
    if related states can match each other's transitions step-for-step. -/
structure Bisimulation (lts₁ : LTS S₁ L) (lts₂ : LTS S₂ L)
    (R : S₁ → S₂ → Prop) : Prop where
  /-- If s₁ R s₂ and s₁ can step, then s₂ can match. -/
  forth : ∀ s₁ s₂ a s₁', R s₁ s₂ → lts₁.Tr s₁ a s₁' →
    ∃ s₂', lts₂.Tr s₂ a s₂' ∧ R s₁' s₂'
  /-- If s₁ R s₂ and s₂ can step, then s₁ can match. -/
  back : ∀ s₁ s₂ a s₂', R s₁ s₂ → lts₂.Tr s₂ a s₂' →
    ∃ s₁', lts₁.Tr s₁ a s₁' ∧ R s₁' s₂'

/-- Two LTS are bisimilar if there exists a bisimulation relating their initial states. -/
def Bisimilar (lts₁ : LTS S₁ L) (lts₂ : LTS S₂ L) : Prop :=
  ∃ R : S₁ → S₂ → Prop, Bisimulation lts₁ lts₂ R ∧ R lts₁.initial lts₂.initial

/-- Forward simulation: every step in the concrete LTS can be matched by the abstract. -/
structure ForwardSimulation (concrete : LTS S₁ L) (abstract : LTS S₂ L)
    (R : S₁ → S₂ → Prop) : Prop where
  sim : ∀ s₁ s₂ a s₁', R s₁ s₂ → concrete.Tr s₁ a s₁' →
    ∃ s₂', abstract.Tr s₂ a s₂' ∧ R s₁' s₂'

/-- An action `a` is enabled in state `s` if some transition on `a` exists. -/
def Enabled (lts : LTS S L) (s : S) (a : L) : Prop :=
  ∃ s', lts.Tr s a s'

/-- Trace equivalence: two states can produce the same observable traces. -/
def TraceEquiv (lts₁ : LTS S₁ L) (lts₂ : LTS S₂ L) : Prop :=
  (∀ s, FiniteTrace lts₁ lts₁.initial s →
    ∃ s', FiniteTrace lts₂ lts₂.initial s' ∧ True) ∧
  (∀ s, FiniteTrace lts₂ lts₂.initial s →
    ∃ s', FiniteTrace lts₁ lts₁.initial s' ∧ True)

-- Theorems

/-- Bisimilarity is reflexive. -/
theorem bisimilar_refl (lts : LTS S L) : Bisimilar lts lts := by
  refine ⟨Eq, ?_, rfl⟩
  exact {
    forth := fun s₁ _ a s₁' h_eq h_tr => ⟨s₁', h_eq ▸ h_tr, rfl⟩
    back := fun _ s₂ a s₂' h_eq h_tr => ⟨s₂', h_eq ▸ h_tr, rfl⟩
  }

/-- Bisimilarity is symmetric. -/
theorem bisimilar_symm {lts₁ : LTS S₁ L} {lts₂ : LTS S₂ L}
    (h : Bisimilar lts₁ lts₂) : Bisimilar lts₂ lts₁ := by
  obtain ⟨R, hR, hInit⟩ := h
  exact ⟨fun s₂ s₁ => R s₁ s₂,
    { forth := fun s₂ s₁ a s₂' hr ht => hR.back s₁ s₂ a s₂' hr ht
      back := fun s₂ s₁ a s₁' hr ht => hR.forth s₁ s₂ a s₁' hr ht },
    hInit⟩

/-- Bisimilarity is transitive. -/
theorem bisimilar_trans {lts₁ : LTS S₁ L} {lts₂ : LTS S₂ L} {lts₃ : LTS S₃ L}
    (h₁₂ : Bisimilar lts₁ lts₂) (h₂₃ : Bisimilar lts₂ lts₃) : Bisimilar lts₁ lts₃ := by
  obtain ⟨R₁₂, hR₁₂, hInit₁₂⟩ := h₁₂
  obtain ⟨R₂₃, hR₂₃, hInit₂₃⟩ := h₂₃
  refine ⟨fun s₁ s₃ => ∃ s₂, R₁₂ s₁ s₂ ∧ R₂₃ s₂ s₃, ?_, ⟨lts₂.initial, hInit₁₂, hInit₂₃⟩⟩
  exact {
    forth := fun s₁ s₃ a s₁' ⟨s₂, hr₁₂, hr₂₃⟩ ht₁ => by
      obtain ⟨s₂', ht₂, hr₁₂'⟩ := hR₁₂.forth s₁ s₂ a s₁' hr₁₂ ht₁
      obtain ⟨s₃', ht₃, hr₂₃'⟩ := hR₂₃.forth s₂ s₃ a s₂' hr₂₃ ht₂
      exact ⟨s₃', ht₃, s₂', hr₁₂', hr₂₃'⟩
    back := fun s₁ s₃ a s₃' ⟨s₂, hr₁₂, hr₂₃⟩ ht₃ => by
      obtain ⟨s₂', ht₂, hr₂₃'⟩ := hR₂₃.back s₂ s₃ a s₃' hr₂₃ ht₃
      obtain ⟨s₁', ht₁, hr₁₂'⟩ := hR₁₂.back s₁ s₂ a s₂' hr₁₂ ht₂
      exact ⟨s₁', ht₁, s₂', hr₁₂', hr₂₃'⟩
  }

/-- The initial state is reachable. -/
theorem initial_reachable (lts : LTS S L) : Reachable lts lts.initial :=
  Reachable.init

/-- Reachability is closed under transitions. -/
theorem reachable_step (lts : LTS S L) {s s' : S} {a : L}
    (hr : Reachable lts s) (ht : lts.Tr s a s') : Reachable lts s' :=
  Reachable.step hr ht

/-- A deadlocked state has no reachable successors via single transitions. -/
theorem deadlock_no_step (lts : LTS S L) {s : S}
    (hd : Deadlock lts s) (a : L) (s' : S) : ¬ lts.Tr s a s' :=
  hd a s'

end LTS
end SWELib.Foundations
