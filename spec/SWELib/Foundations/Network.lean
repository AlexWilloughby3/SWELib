import SWELib.Foundations.System

/-!
# Concrete Channel Instances

Standard channel processes that model common network link types.
Each is a concrete `Channel` with a specific state type (queue/bag)
and proved properties.

These validate the Foundations framework end-to-end: the abstract
`Channel` type + property predicates (`isReliable`, `isFIFO`, etc.)
become concrete state machines with proved guarantees.

References:
- TCP (reliable, FIFO) → `reliableFIFOChannel`
- UDP (lossy, unordered) → `lossyUnorderedChannel`
-/

namespace SWELib.Foundations

-- ═══════════════════════════════════════════════════════════
-- Reliable FIFO Channel (TCP-like)
-- ═══════════════════════════════════════════════════════════

/-- Transition relation for a reliable FIFO channel.
    State is `List α` (a queue, head = oldest message).
    - `enqueue msg`: append to back
    - `deliver msg`: pop from front (only if msg is at the head)
    No drop, reorder, partition, or heal transitions. -/
def reliableFIFOTr (α : Type) : List α → ChannelAction α → List α → Prop
  | buf, .enqueue msg, buf' => buf' = buf ++ [msg]
  | buf, .deliver msg, buf' => ∃ rest, buf = msg :: rest ∧ buf' = rest
  | _, .drop _, _ => False
  | _, .reorder, _ => False
  | _, .partition, _ => False
  | _, .heal, _ => False

/-- A reliable FIFO channel between two Nodes.
    Models TCP: messages are delivered exactly once, in order. -/
def reliableFIFOChannel (α : Type) (src dst : NodeId) : Channel α (List α) where
  lts := { Tr := reliableFIFOTr α, initial := [] }
  src := src
  dst := dst

/-- A reliable FIFO channel never drops messages. -/
theorem reliableFIFO_isReliable (α : Type) (src dst : NodeId) :
    (reliableFIFOChannel α src dst).isReliable := by
  intro s msg s'
  simp [reliableFIFOChannel, reliableFIFOTr]

/-- Helper: delivering through a prefix to reach the target element. -/
private theorem deliver_prefix {α : Type} (prefix_ : List α) (m₁ : α) (suffix_ : List α) :
    LTS.FiniteTrace
      { Tr := reliableFIFOTr α, initial := ([] : List α) }
      (prefix_ ++ m₁ :: suffix_)
      (m₁ :: suffix_) := by
  induction prefix_ with
  | nil => simp; exact .nil _
  | cons x xs ih =>
    apply LTS.FiniteTrace.cons (.deliver x)
    · unfold reliableFIFOTr
      exact ⟨xs ++ m₁ :: suffix_, rfl, rfl⟩
    · exact ih

/-- A reliable FIFO channel is FIFO: if m₁ is enqueued before m₂,
    then m₁ is deliverable before m₂. -/
theorem reliableFIFO_isFIFO (α : Type) (src dst : NodeId) :
    (reliableFIFOChannel α src dst).isFIFO := by
  intro s m₁ m₂ s₁ s₂ h_enq₁ h_enq₂ s₃ h_del₂
  -- Unfold channel to get raw transition relation facts
  simp only [reliableFIFOChannel] at h_enq₁ h_enq₂ h_del₂
  -- h_enq₁ : reliableFIFOTr α s (.enqueue m₁) s₁, i.e., s₁ = s ++ [m₁]
  -- h_enq₂ : reliableFIFOTr α s₁ (.enqueue m₂) s₂, i.e., s₂ = s₁ ++ [m₂]
  -- h_del₂ : reliableFIFOTr α s₂ (.deliver m₂) s₃, i.e., ∃ rest, s₂ = m₂ :: rest ∧ s₃ = rest
  unfold reliableFIFOTr at h_enq₁ h_enq₂ h_del₂
  -- After unfolding, h_enq₁ : s₁ = s ++ [m₁], h_enq₂ : s₂ = s₁ ++ [m₂]
  -- h_del₂ : ∃ rest, s₂ = m₂ :: rest ∧ s₃ = rest
  obtain ⟨rest, h_eq_s₂, h_eq_s₃⟩ := h_del₂
  -- s₂ = (s ++ [m₁]) ++ [m₂] = m₂ :: rest
  have h_s₂_def : s₂ = s ++ [m₁] ++ [m₂] := by rw [h_enq₂, h_enq₁]
  rw [h_s₂_def] at h_eq_s₂
  -- Now h_eq_s₂ : s ++ [m₁] ++ [m₂] = m₂ :: rest
  -- This means s ++ [m₁, m₂] = m₂ :: rest (since [m₁] ++ [m₂] = [m₁, m₂])
  simp only [List.append_assoc, List.singleton_append] at h_eq_s₂
  -- Need to show: ∃ s_mid, FiniteTrace from s₂ to s_mid ∧ ∃ s₄, Tr s_mid (deliver m₁) s₄
  -- s₂ = s ++ [m₁] ++ [m₂]
  -- We need to deliver everything before m₁, then deliver m₁
  rw [h_s₂_def]
  simp only [List.append_assoc, List.singleton_append, reliableFIFOChannel]
  -- Goal: ∃ s_mid, FiniteTrace (s ++ (m₁ :: [m₂])) s_mid ∧ ∃ s₄, reliableFIFOTr α s_mid (.deliver m₁) s₄
  refine ⟨m₁ :: [m₂], ?_, [m₂], ?_⟩
  · -- FiniteTrace from s ++ [m₁, m₂] to [m₁, m₂]
    exact deliver_prefix s m₁ [m₂]
  · -- Tr [m₁, m₂] (deliver m₁) [m₂]
    exact ⟨[m₂], rfl, rfl⟩

-- ═══════════════════════════════════════════════════════════
-- Lossy Unordered Channel (UDP-like)
-- ═══════════════════════════════════════════════════════════

/-- Transition relation for a lossy unordered channel.
    State is `List α` (a bag — order doesn't matter).
    - `enqueue msg`: prepend to buffer
    - `deliver msg`: remove from buffer (msg must be present)
    - `drop msg`: remove from buffer without delivering (msg must be present)
    No reorder action needed (delivery is already unordered).
    No partition/heal (link-level failures modeled as increased drop rate). -/
def lossyUnorderedTr {α : Type} [DecidableEq α] :
    List α → ChannelAction α → List α → Prop
  | buf, .enqueue msg, buf' => buf' = msg :: buf
  | buf, .deliver msg, buf' => msg ∈ buf ∧ buf' = buf.erase msg
  | buf, .drop msg, buf' => msg ∈ buf ∧ buf' = buf.erase msg
  | _, .reorder, _ => False
  | _, .partition, _ => False
  | _, .heal, _ => False

/-- A lossy unordered channel between two Nodes.
    Models UDP: messages may be dropped, delivered in any order. -/
def lossyUnorderedChannel {α : Type} [DecidableEq α] (src dst : NodeId) :
    Channel α (List α) where
  lts := { Tr := lossyUnorderedTr, initial := [] }
  src := src
  dst := dst

/-- A lossy unordered channel is not reliable (it can drop). -/
theorem lossyUnordered_isLossy {α : Type} [DecidableEq α] [Inhabited α]
    (src dst : NodeId) :
    Channel.isLossy (lossyUnorderedChannel (α := α) src dst) := by
  refine ⟨[default], default, [], ?_⟩
  simp [lossyUnorderedChannel, lossyUnorderedTr]

/-- A lossy unordered channel is not reliable. -/
theorem lossyUnordered_not_isReliable {α : Type} [DecidableEq α] [Inhabited α]
    (src dst : NodeId) :
    ¬ Channel.isReliable (lossyUnorderedChannel (α := α) src dst) := by
  intro h
  have ⟨s, msg, s', h_drop⟩ := lossyUnordered_isLossy (α := α) src dst
  exact h s msg s' h_drop

-- ═══════════════════════════════════════════════════════════
-- Partitionable Channel
-- ═══════════════════════════════════════════════════════════

/-- State for a channel that can partition and heal. -/
inductive LinkState where
  | up
  | down
  deriving DecidableEq, Repr

/-- Transition relation for a partitionable reliable FIFO channel.
    Like reliableFIFO but with partition/heal transitions.
    When partitioned, enqueued messages are silently lost. -/
def partitionableTr (α : Type) :
    (LinkState × List α) → ChannelAction α → (LinkState × List α) → Prop
  | (.up, buf), .enqueue msg, (.up, buf') => buf' = buf ++ [msg]
  | (.up, buf), .deliver msg, (.up, buf') =>
    ∃ rest, buf = msg :: rest ∧ buf' = rest
  | (.down, _buf), .enqueue _msg, (.down, buf') =>
    buf' = _buf  -- message silently lost (state unchanged)
  | (.down, _buf), .drop _msg, (.down, buf') =>
    buf' = []  -- when partitioned, can drop remaining buffered messages
  | (ls, buf), .partition, (.down, buf') => ls = .up ∧ buf' = buf
  | (ls, buf), .heal, (.up, buf') => ls = .down ∧ buf' = buf
  | _, _, _ => False

/-- A partitionable reliable FIFO channel.
    Reliable and FIFO when link is up; drops messages when partitioned. -/
def partitionableChannel (α : Type) (src dst : NodeId) :
    Channel α (LinkState × List α) where
  lts := { Tr := partitionableTr α, initial := (.up, []) }
  src := src
  dst := dst

/-- A partitionable channel can indeed partition. -/
theorem partitionable_canPartition (α : Type) (src dst : NodeId) :
    (partitionableChannel α src dst).canPartition := by
  refine ⟨(.up, []), (.down, []), ?_⟩
  simp [partitionableChannel, partitionableTr]

-- ═══════════════════════════════════════════════════════════
-- Network Constructors
-- ═══════════════════════════════════════════════════════════

/-- Build a network where every pair of nodes in `ids` is connected
    by the same channel constructor. -/
def Network.complete {α S : Type} (ids : List NodeId)
    (mkChannel : NodeId → NodeId → Channel α S) : Network α where
  channels := fun src dst =>
    if ids.contains src && ids.contains dst && (src != dst) then
      some ⟨S, mkChannel src dst⟩
    else
      none

/-- A complete network is fully connected over its node set. -/
theorem Network.complete_fullyConnected {α S : Type}
    (ids : List NodeId) (mkChannel : NodeId → NodeId → Channel α S) :
    (Network.complete ids mkChannel).fullyConnected ids := by
  intro n₁ n₂ h₁ h₂ h_ne
  show (Network.complete ids mkChannel).channels n₁ n₂ |>.isSome
  simp only [Network.complete]
  have h₁' : ids.contains n₁ = true := by
    simp only [List.contains]; exact List.elem_eq_true_of_mem h₁
  have h₂' : ids.contains n₂ = true := by
    simp only [List.contains]; exact List.elem_eq_true_of_mem h₂
  have h_ne' : (n₁ != n₂) = true := bne_iff_ne.mpr h_ne
  simp [h_ne']
  exact ⟨h₁, h₂⟩

/-- A complete network with reliable FIFO channels has all channels reliable. -/
theorem Network.complete_allReliable (α : Type) (ids : List NodeId) :
    (Network.complete ids (reliableFIFOChannel α)).allReliable := by
  intro src dst ch h_ch
  simp only [Network.complete] at h_ch
  split at h_ch <;> simp at h_ch
  obtain ⟨_, rfl⟩ := h_ch
  exact reliableFIFO_isReliable α src dst

end SWELib.Foundations
