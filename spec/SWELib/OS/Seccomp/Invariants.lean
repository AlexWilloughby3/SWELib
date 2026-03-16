import SWELib.OS.Seccomp.Operations

/-!
# Seccomp BPF Invariants

Structural invariants for valid BPF programs and key seccomp properties.

References:
- seccomp(2): https://man7.org/linux/man-pages/man2/seccomp.2.html
- Linux BPF:  https://www.kernel.org/doc/html/latest/networking/filter.html
-/

namespace SWELib.OS.Seccomp

/-! ## Valid program structure -/

/-- A valid seccomp BPF program satisfies the kernel's static verification checks:
    - At least 1 instruction
    - At most 4096 instructions
    - Ends with a RET instruction
    - All jumps land within the program
    - All ABS loads are 4-aligned and within the 64-byte seccomp_data
    - All MEM accesses use indices < 16 -/
structure ValidProgram (prog : SockFprog) : Prop where
  len_pos     : prog.filter.size ≥ 1
  len_bound   : prog.filter.size ≤ 4096
  ends_ret    : ∃ last, prog.filter[prog.filter.size - 1]? = some last ∧
                         (last.code &&& 0x07) = 0x06
  jumps_fwd   : ∀ i (h : i < prog.filter.size),
                  let insn := prog.filter[i]'h
                  (insn.code &&& 0x07) = 0x05 →
                  i + 1 + insn.jt.toNat < prog.filter.size ∧
                  i + 1 + insn.jf.toNat < prog.filter.size
  abs_aligned : ∀ i (h : i < prog.filter.size),
                  let insn := prog.filter[i]'h
                  (insn.code &&& 0xe0) = 0x20 →
                  insn.k % 4 = 0 ∧ insn.k.toNat + 4 ≤ 64
  mem_bounded : ∀ i (h : i < prog.filter.size),
                  let insn := prog.filter[i]'h
                  ((insn.code &&& 0x07) = 0x00 ∨ (insn.code &&& 0x07) = 0x01 ∨
                   (insn.code &&& 0x07) = 0x02 ∨ (insn.code &&& 0x07) = 0x03) →
                  (insn.code &&& 0xe0) = 0x60 →
                  insn.k.toNat < 16

/-! ## Priority ordering is not arithmetic on UInt32 -/

/-- The priority ordering of seccomp actions does not follow arithmetic
    ordering of their UInt32 representations. KILL_PROCESS (0x80000000)
    has higher priority than ALLOW (0x7fff0000) despite having a larger
    numeric value. -/
theorem priority_not_arithmetic :
    actionPriority (SeccompAction.toUInt32 .KILL_PROCESS) <
    actionPriority (SeccompAction.toUInt32 .ALLOW) := by
  native_decide

/-! ## Termination of valid programs -/

/-- A valid BPF program always terminates with a return value.
    This requires showing that fuel = prog.size is sufficient given
    that all jumps are forward and the program ends with RET. -/
theorem terminatesOnValid (prog : SockFprog) (d : SeccompData)
    (_ : ValidProgram prog) : ∃ v, bpfRun prog.filter d = some v := by
  sorry

/-! ## Chain inheritance -/

/-- Installing a new filter strictly extends the chain. -/
theorem chainInheritance (chain : FilterChain) (prog : SockFprog) :
    let chain' := prog :: chain
    chain.length < chain'.length := by
  simp

end SWELib.OS.Seccomp
