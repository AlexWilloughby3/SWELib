import SWELib.OS.Seccomp.Invariants

/-!
# Seccomp BPF Theorems

Properties of BPF filter evaluation and seccomp filter chain semantics.

References:
- seccomp(2): https://man7.org/linux/man-pages/man2/seccomp.2.html
-/

namespace SWELib.OS.Seccomp

/-! ## T-1: Action priority injectivity -/

/-- Each known seccomp action maps to a distinct priority value.
    This ensures the priority comparison in `evalFilterChain` is
    a total order on the action space. -/
theorem actionPriority_injective_on_actions (a b : SeccompAction)
    (h : actionPriority a.toUInt32 = actionPriority b.toUInt32) : a = b := by
  cases a <;> cases b <;> first | rfl | (exfalso; revert h; native_decide)

/-! ## T-2: KILL_PROCESS has priority 1 -/

/-- KILL_PROCESS is the highest priority action (priority 1). -/
theorem killProcess_priority_one :
    actionPriority (SeccompAction.toUInt32 .KILL_PROCESS) = 1 := by
  native_decide

/-! ## T-3: ALLOW has priority 8 -/

/-- ALLOW is the lowest priority action (priority 8). -/
theorem allow_priority_eight :
    actionPriority (SeccompAction.toUInt32 .ALLOW) = 8 := by
  native_decide

/-! ## T-4: Empty filter chain -/

/-- An empty filter chain returns SECCOMP_RET_KILL_PROCESS. -/
theorem evalFilterChain_empty (d : SeccompData) :
    evalFilterChain [] d = SeccompAction.toUInt32 .KILL_PROCESS := by
  simp [evalFilterChain]

/-! ## T-5: Singleton filter chain -/

/-- A single-filter chain returns that filter's result. -/
theorem evalFilterChain_singleton (prog : SockFprog) (d : SeccompData) (v : UInt32)
    (h : bpfRun prog.filter d = some v) :
    evalFilterChain [prog] d = v := by
  simp [evalFilterChain, List.filterMap, h]

/-! ## T-6: BPF LD IMM loads constant into accumulator -/

/-- A BPF_LD|BPF_W|BPF_IMM instruction (code=0x00) loads the immediate
    value k into the accumulator. -/
theorem bpfStep_ld_imm (s : BpfMachineState) (d : SeccompData) (k : UInt32) :
    bpfStep s { code := 0x00, jt := 0, jf := 0, k := k } d =
    some { s with A := k, pc := s.pc + 1 } := by
  simp [bpfStep, SockFilter.decodeOpcode]

/-! ## T-8: BPF LD ABS with unaligned offset returns none -/

/-- A BPF_LD|BPF_W|BPF_ABS instruction with an unaligned offset
    (not a multiple of 4, or >= 64) returns none. -/
theorem bpfStep_ld_abs_unaligned (s : BpfMachineState) (d : SeccompData) :
    bpfStep s { code := 0x20, jt := 0, jf := 0, k := 3 } d = none := by
  simp [bpfStep, SockFilter.decodeOpcode, SeccompData.readWord]

/-! ## T-9: BPF ALU DIV by zero returns none -/

/-- A BPF_ALU|BPF_DIV|BPF_K instruction with k=0 returns none
    (division by zero). -/
theorem bpfStep_alu_div_zero (s : BpfMachineState) (d : SeccompData) :
    bpfStep s { code := 0x34, jt := 0, jf := 0, k := 0 } d = none := by
  simp [bpfStep, SockFilter.decodeOpcode]

/-! ## T-10: BPF MISC TAX copies A to X -/

/-- A BPF_MISC|BPF_TAX instruction (code=0x07) copies the accumulator
    to the index register. -/
theorem bpfStep_misc_tax (s : BpfMachineState) (d : SeccompData) :
    bpfStep s { code := 0x07, jt := 0, jf := 0, k := 0 } d =
    some { s with X := s.A, pc := s.pc + 1 } := by
  simp [bpfStep, SockFilter.decodeOpcode]

/-! ## T-11: BPF step strictly advances pc -/

private theorem pc_lt_of_eq_step {pc pc' : Nat} (h : pc + 1 = pc') : pc < pc' := by
  omega

private theorem pc_lt_of_eq_jump {pc pc' n : Nat} (h : pc + 1 + n = pc') : pc < pc' := by
  omega

/-- Every successful bpfStep strictly advances the program counter.
    This is essential for the termination argument. -/
theorem bpfStep_pc_nondecreasing (s : BpfMachineState) (d : SeccompData)
    (insn : SockFilter) (s' : BpfMachineState)
    (h : bpfStep s insn d = some s') : s.pc < s'.pc := by
  have hpc : Option.map BpfMachineState.pc (bpfStep s insn d) = some s'.pc := by
    simp [h]
  cases h_op : insn.decodeOpcode with
  | none =>
    unfold bpfStep at hpc
    rw [h_op] at hpc
    contradiction
  | some op =>
    cases op with
    | load cls sz mode =>
      cases cls <;> cases sz <;> cases mode
      all_goals
        (unfold bpfStep at hpc
         rw [h_op] at hpc
         dsimp at hpc)
      all_goals (try contradiction)
      case LD.W.ABS =>
        cases h_read : d.readWord insn.k with
        | none =>
          simp [h_read] at hpc
        | some _ =>
          simp [h_read] at hpc
          exact pc_lt_of_eq_step hpc
      case LD.W.IND =>
        cases h_read : d.readWord (s.X + insn.k) with
        | none =>
          simp [h_read] at hpc
        | some _ =>
          simp [h_read] at hpc
          exact pc_lt_of_eq_step hpc
      case LD.W.MEM =>
        split at hpc
        · simp at hpc
          exact pc_lt_of_eq_step hpc
        · simp at hpc
      case LD.W.IMM =>
        simp at hpc
        exact pc_lt_of_eq_step hpc
      case LD.W.LEN =>
        simp at hpc
        exact pc_lt_of_eq_step hpc
      case LDX.W.MEM =>
        split at hpc
        · simp at hpc
          exact pc_lt_of_eq_step hpc
        · simp at hpc
      case LDX.W.IMM =>
        simp at hpc
        exact pc_lt_of_eq_step hpc
      case LDX.W.LEN =>
        simp at hpc
        exact pc_lt_of_eq_step hpc
      case LDX.B.MSH =>
        cases h_read : d.readWord (insn.k &&& 0xfffffffc) with
        | none =>
          simp [h_read] at hpc
        | some _ =>
          simp [h_read] at hpc
          exact pc_lt_of_eq_step hpc
      case ST.W.MEM =>
        split at hpc
        · simp at hpc
          exact pc_lt_of_eq_step hpc
        · simp at hpc
      case ST.H.MEM =>
        split at hpc
        · simp at hpc
          exact pc_lt_of_eq_step hpc
        · simp at hpc
      case ST.B.MEM =>
        split at hpc
        · simp at hpc
          exact pc_lt_of_eq_step hpc
        · simp at hpc
      case STX.W.MEM =>
        split at hpc
        · simp at hpc
          exact pc_lt_of_eq_step hpc
        · simp at hpc
      case STX.H.MEM =>
        split at hpc
        · simp at hpc
          exact pc_lt_of_eq_step hpc
        · simp at hpc
      case STX.B.MEM =>
        split at hpc
        · simp at hpc
          exact pc_lt_of_eq_step hpc
        · simp at hpc
      all_goals contradiction
    | alu aluOp src =>
      cases aluOp
      all_goals
        (unfold bpfStep at hpc
         rw [h_op] at hpc
         dsimp at hpc)
      case ADD =>
        simp at hpc
        exact pc_lt_of_eq_step hpc
      case SUB =>
        simp at hpc
        exact pc_lt_of_eq_step hpc
      case MUL =>
        simp at hpc
        exact pc_lt_of_eq_step hpc
      case DIV =>
        cases h_src : src
        case K =>
          simp [h_src] at hpc
          rcases hpc with ⟨a, ⟨_, ha⟩, hpc'⟩
          subst a
          exact pc_lt_of_eq_step (by simpa using hpc')
        case X =>
          simp [h_src] at hpc
          rcases hpc with ⟨a, ⟨_, ha⟩, hpc'⟩
          subst a
          exact pc_lt_of_eq_step (by simpa using hpc')
        case A =>
          simp [h_src] at hpc
          rcases hpc with ⟨a, ⟨_, ha⟩, hpc'⟩
          subst a
          exact pc_lt_of_eq_step (by simpa using hpc')
      case OR =>
        simp at hpc
        exact pc_lt_of_eq_step hpc
      case AND =>
        simp at hpc
        exact pc_lt_of_eq_step hpc
      case LSH =>
        simp at hpc
        exact pc_lt_of_eq_step hpc
      case RSH =>
        simp at hpc
        exact pc_lt_of_eq_step hpc
      case NEG =>
        simp at hpc
        exact pc_lt_of_eq_step hpc
      case MOD =>
        cases h_src : src
        case K =>
          simp [h_src] at hpc
          rcases hpc with ⟨a, ⟨_, ha⟩, hpc'⟩
          subst a
          exact pc_lt_of_eq_step (by simpa using hpc')
        case X =>
          simp [h_src] at hpc
          rcases hpc with ⟨a, ⟨_, ha⟩, hpc'⟩
          subst a
          exact pc_lt_of_eq_step (by simpa using hpc')
        case A =>
          simp [h_src] at hpc
          rcases hpc with ⟨a, ⟨_, ha⟩, hpc'⟩
          subst a
          exact pc_lt_of_eq_step (by simpa using hpc')
      case XOR =>
        simp at hpc
        exact pc_lt_of_eq_step hpc
    | jmp jmpOp src =>
      cases jmpOp <;> cases src
      all_goals
        (unfold bpfStep at hpc
         rw [h_op] at hpc
         dsimp at hpc
         simp at hpc
         exact pc_lt_of_eq_jump hpc)
    | ret _ =>
      unfold bpfStep at hpc
      rw [h_op] at hpc
      contradiction
    | misc miscOp =>
      cases miscOp
      all_goals
        (unfold bpfStep at hpc
         rw [h_op] at hpc
         dsimp at hpc
         simp at hpc
         exact pc_lt_of_eq_step hpc)

/-! ## T-12: installFilter extends cumulative count -/

/-- Installing a new filter adds its size + 4 to the cumulative
    instruction count of the chain. -/
private theorem foldl_add_init (xs : List SockFprog) (init : Nat) :
    List.foldl (fun acc p => acc + p.filter.size + 4) init xs =
    init + List.foldl (fun acc p => acc + p.filter.size + 4) 0 xs := by
  induction xs generalizing init with
  | nil => simp [List.foldl]
  | cons x xs ih =>
    simp only [List.foldl]
    rw [ih, ih (0 + x.filter.size + 4)]
    omega

/-- Installing a new filter adds its size + 4 to the cumulative
    instruction count of the chain. -/
theorem installFilter_extends_chain (chain : FilterChain) (prog : SockFprog) :
    cumulativeInstructions (prog :: chain) =
    cumulativeInstructions chain + prog.filter.size + 4 := by
  simp only [cumulativeInstructions, List.foldl]
  rw [foldl_add_init]
  omega

end SWELib.OS.Seccomp
