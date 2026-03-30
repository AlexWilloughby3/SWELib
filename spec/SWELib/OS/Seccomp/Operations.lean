import SWELib.OS.Seccomp.Types

/-!
# Seccomp BPF Operations

Pure state-transition functions for BPF filter evaluation and seccomp
filter chain semantics.

References:
- seccomp(2):  https://man7.org/linux/man-pages/man2/seccomp.2.html
- Linux BPF:   https://www.kernel.org/doc/html/latest/networking/filter.html
-/

namespace SWELib.OS.Seccomp

/-! ## Action priority -/

/-- Priority of a seccomp return value action.
    Lower number = higher priority (more restrictive).
    1 = KILL_PROCESS (highest), 8 = ALLOW (lowest), 0 = unknown. -/
def actionPriority (v : UInt32) : Nat :=
  match v &&& SECCOMP_RET_ACTION_FULL with
  | 0x80000000 => 1
  | 0x00000000 => 2
  | 0x00030000 => 3
  | 0x00050000 => 4
  | 0x7fc00000 => 5
  | 0x7ff00000 => 6
  | 0x7ffc0000 => 7
  | 0x7fff0000 => 8
  | _          => 0

/-! ## Single instruction execution -/

/-- Execute a single BPF instruction, returning the updated machine state.
    Returns `none` on invalid instruction, out-of-bounds memory access,
    or division by zero.

    BPF_RET instructions are NOT handled here — they are detected by
    `bpfRun` before calling `bpfStep`. -/
def bpfStep (s : BpfMachineState) (insn : SockFilter) (d : SeccompData)
    : Option BpfMachineState :=
  match insn.decodeOpcode with
  | none => none
  -- Load instructions
  | some (.load .LD .W .ABS) =>
    d.readWord insn.k >>= fun w => some { s with A := w, pc := s.pc + 1 }
  | some (.load .LD .W .IND) =>
    d.readWord (s.X + insn.k) >>= fun w => some { s with A := w, pc := s.pc + 1 }
  | some (.load .LD .W .MEM) =>
    if h : insn.k.toNat < 16
    then some { s with A := s.M ⟨insn.k.toNat, h⟩, pc := s.pc + 1 }
    else none
  | some (.load .LD .W .IMM) =>
    some { s with A := insn.k, pc := s.pc + 1 }
  | some (.load .LD .W .LEN) =>
    some { s with A := 64, pc := s.pc + 1 }
  | some (.load .LDX .W .MEM) =>
    if h : insn.k.toNat < 16
    then some { s with X := s.M ⟨insn.k.toNat, h⟩, pc := s.pc + 1 }
    else none
  | some (.load .LDX .W .IMM) =>
    some { s with X := insn.k, pc := s.pc + 1 }
  | some (.load .LDX .W .LEN) =>
    some { s with X := 64, pc := s.pc + 1 }
  | some (.load .LDX .B .MSH) =>
    -- Read the word containing the byte at offset k (aligned down)
    let alignedOff := insn.k &&& 0xfffffffc
    match d.readWord alignedOff with
    | none => none
    | some w =>
      -- Extract the byte at position (k % 4) within the word
      let byteShift := (insn.k &&& 0x03) * 8
      let byte := (w >>> byteShift) &&& 0xff
      some { s with X := (byte &&& 0x0f) * 4, pc := s.pc + 1 }
  -- Store instructions
  | some (.load .ST _ .MEM) =>
    if h : insn.k.toNat < 16
    then some { s with M := fun i => if i = ⟨insn.k.toNat, h⟩ then s.A else s.M i, pc := s.pc + 1 }
    else none
  | some (.load .STX _ .MEM) =>
    if h : insn.k.toNat < 16
    then some { s with M := fun i => if i = ⟨insn.k.toNat, h⟩ then s.X else s.M i, pc := s.pc + 1 }
    else none
  -- ALU instructions
  | some (.alu op src) =>
    let srcVal := match src with | .K => insn.k | .X => s.X | .A => s.A
    match op with
    | .ADD => some { s with A := s.A + srcVal, pc := s.pc + 1 }
    | .SUB => some { s with A := s.A - srcVal, pc := s.pc + 1 }
    | .MUL => some { s with A := s.A * srcVal, pc := s.pc + 1 }
    | .DIV => if srcVal == 0 then none else some { s with A := s.A / srcVal, pc := s.pc + 1 }
    | .OR  => some { s with A := s.A ||| srcVal, pc := s.pc + 1 }
    | .AND => some { s with A := s.A &&& srcVal, pc := s.pc + 1 }
    | .LSH => some { s with A := s.A <<< srcVal, pc := s.pc + 1 }
    | .RSH => some { s with A := s.A >>> srcVal, pc := s.pc + 1 }
    | .NEG => some { s with A := (0 : UInt32) - s.A, pc := s.pc + 1 }
    | .MOD => if srcVal == 0 then none else some { s with A := s.A % srcVal, pc := s.pc + 1 }
    | .XOR => some { s with A := s.A ^^^ srcVal, pc := s.pc + 1 }
  -- Jump instructions
  | some (.jmp .JA .K) =>
    some { s with pc := s.pc + 1 + insn.k.toNat }
  | some (.jmp op src) =>
    let srcVal := match src with | .K => insn.k | .X => s.X | .A => s.A
    let cond := match op with
      | .JA   => true  -- unreachable due to pattern above, but needed for exhaustiveness
      | .JEQ  => s.A == srcVal
      | .JGT  => s.A > srcVal
      | .JGE  => s.A >= srcVal
      | .JSET => (s.A &&& srcVal) != 0
    some { s with pc := s.pc + 1 + (if cond then insn.jt.toNat else insn.jf.toNat) }
  -- RET — handled by bpfRun, not bpfStep
  | some (.ret _) => none
  -- MISC instructions
  | some (.misc .TAX) =>
    some { s with X := s.A, pc := s.pc + 1 }
  | some (.misc .TXA) =>
    some { s with A := s.X, pc := s.pc + 1 }
  -- Catch-all for unhandled load combinations
  | some (.load _ _ _) => none

/-! ## BPF program execution with fuel -/

/-- Run a BPF program with bounded fuel.
    Returns the seccomp return value on BPF_RET, or `none` on
    invalid instruction / out-of-bounds / fuel exhaustion. -/
private def bpfRunAux (prog : Array SockFilter) (d : SeccompData)
    (s : BpfMachineState) : Nat → Option UInt32
  | 0 => none  -- fuel exhausted
  | fuel + 1 =>
    if h : s.pc < prog.size then
      let insn := prog[s.pc]'h
      match insn.decodeOpcode with
      | some (.ret .K) => some insn.k
      | some (.ret .A) => some s.A
      | _ =>
        match bpfStep s insn d with
        | none    => none
        | some s' => bpfRunAux prog d s' fuel
    else none  -- pc out of bounds

/-- Run a BPF program to completion.
    Uses `prog.size` as the fuel bound (sufficient for valid programs
    that make forward progress). -/
def bpfRun (prog : Array SockFilter) (d : SeccompData) : Option UInt32 :=
  bpfRunAux prog d BpfMachineState.initial prog.size

/-! ## Filter chain evaluation -/

/-- Compare two return values; return the one with higher priority action
    (lower actionPriority number = higher priority).
    If equal priority, return the first (most-recently-installed). -/
private def higherPriority (a b : UInt32) : UInt32 :=
  if actionPriority a ≤ actionPriority b then a else b

/-- Evaluate a chain of seccomp filters against syscall data.
    Runs ALL filters, collects results (None entries skipped),
    returns the highest-priority result.
    Empty chain (or all-None) returns SECCOMP_RET_KILL_PROCESS defensively. -/
def evalFilterChain (chain : FilterChain) (d : SeccompData) : SeccompReturnValue :=
  let results := chain.filterMap (fun p => bpfRun p.filter d)
  match results with
  | []     => SeccompAction.toUInt32 .KILL_PROCESS
  | r :: rs => rs.foldl higherPriority r

/-! ## Cumulative instruction count -/

/-- Total instruction count across all filters in a chain.
    Each filter contributes `filter.size + 4` (overhead for
    seccomp filter wrapper instructions). -/
def cumulativeInstructions (chain : FilterChain) : Nat :=
  chain.foldl (fun acc p => acc + p.filter.size + 4) 0

/-! ## Install filter precondition -/

/-- Predicate for whether a new filter can be installed on a chain.
    Requires: privilege, non-empty program, program size <= 4096,
    cumulative instructions + new filter <= 32768. -/
def InstallFilterOk (chain : FilterChain) (prog : SockFprog) (hasPrivilege : Bool) : Prop :=
  hasPrivilege = true ∧
  prog.filter.size ≥ 1 ∧
  prog.filter.size ≤ 4096 ∧
  cumulativeInstructions chain + prog.filter.size + 4 ≤ 32768

end SWELib.OS.Seccomp
