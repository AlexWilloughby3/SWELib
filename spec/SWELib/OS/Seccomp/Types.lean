/-!
# Seccomp BPF Types

Core types for the Linux seccomp BPF filter evaluation model.

References:
- seccomp(2):         https://man7.org/linux/man-pages/man2/seccomp.2.html
- Linux BPF:          https://www.kernel.org/doc/html/latest/networking/filter.html
- seccomp_data struct: include/uapi/linux/seccomp.h
-/

namespace SWELib.OS.Seccomp

/-! ## BPF instruction class decomposition -/

/-- BPF instruction class (bits 0-2 of opcode). -/
inductive BpfInsnClass where
  | LD | LDX | ST | STX | ALU | JMP | RET | MISC
  deriving DecidableEq, Repr

/-- BPF data size for load instructions. -/
inductive BpfSize where
  | W | H | B
  deriving DecidableEq, Repr

/-- BPF addressing mode for load instructions. -/
inductive BpfMode where
  | IMM | ABS | IND | MEM | LEN | MSH
  deriving DecidableEq, Repr

/-- BPF ALU operations. -/
inductive BpfAluOp where
  | ADD | SUB | MUL | DIV | OR | AND | LSH | RSH | NEG | MOD | XOR
  deriving DecidableEq, Repr

/-- BPF jump operations. -/
inductive BpfJmpOp where
  | JA | JEQ | JGT | JGE | JSET
  deriving DecidableEq, Repr

/-- BPF source operand selector. -/
inductive BpfSrc where
  | K | X | A
  deriving DecidableEq, Repr

/-- BPF miscellaneous operations. -/
inductive BpfMiscOp where
  | TAX | TXA
  deriving DecidableEq, Repr

/-! ## Decoded opcode -/

/-- Decoded BPF opcode — structured representation of a raw UInt16 opcode field. -/
inductive BpfOpcode where
  | load (cls : BpfInsnClass) (sz : BpfSize) (mode : BpfMode)
  | alu  (op : BpfAluOp) (src : BpfSrc)
  | jmp  (op : BpfJmpOp) (src : BpfSrc)
  | ret  (src : BpfSrc)
  | misc (op : BpfMiscOp)
  deriving DecidableEq, Repr

/-! ## SockFilter -/

/-- A single BPF instruction (struct sock_filter). -/
structure SockFilter where
  code : UInt16
  jt   : UInt8
  jf   : UInt8
  k    : UInt32
  deriving DecidableEq, Repr

/-- Decode a raw UInt16 BPF opcode into a structured BpfOpcode.
    Returns `none` for unrecognized combinations.

    Bit layout of code field:
    - bits 0-2: instruction class
    - bits 3-4: size (LD/LDX) or source (ALU/JMP/RET)
    - bits 5-7: addressing mode (LD/LDX) or operation (ALU/JMP)

    Factored out from SockFilter so that decode lemmas for concrete
    opcodes can be proved via `native_decide` (no free variables). -/
def decodeCode (code : UInt16) : Option BpfOpcode :=
  let cls := code &&& 0x07
  match cls with
  | 0x00 => -- BPF_LD
    let sz := (code >>> 3) &&& 0x03
    let mode := (code >>> 5) &&& 0x07
    let sz' := match sz with | 0x00 => some BpfSize.W | 0x01 => some BpfSize.H
                             | 0x02 => some BpfSize.B | _ => none
    let mode' := match mode with
      | 0x00 => some BpfMode.IMM | 0x01 => some BpfMode.ABS
      | 0x02 => some BpfMode.IND | 0x03 => some BpfMode.MEM
      | 0x04 => some BpfMode.LEN | 0x05 => some BpfMode.MSH
      | _ => none
    match sz', mode' with
    | some s, some m => some (.load .LD s m)
    | _, _ => none
  | 0x01 => -- BPF_LDX
    let sz := (code >>> 3) &&& 0x03
    let mode := (code >>> 5) &&& 0x07
    let sz' := match sz with | 0x00 => some BpfSize.W | 0x01 => some BpfSize.H
                             | 0x02 => some BpfSize.B | _ => none
    let mode' := match mode with
      | 0x00 => some BpfMode.IMM | 0x01 => some BpfMode.ABS
      | 0x02 => some BpfMode.IND | 0x03 => some BpfMode.MEM
      | 0x04 => some BpfMode.LEN | 0x05 => some BpfMode.MSH
      | _ => none
    match sz', mode' with
    | some s, some m => some (.load .LDX s m)
    | _, _ => none
  | 0x02 => -- BPF_ST
    some (.load .ST .W .MEM)
  | 0x03 => -- BPF_STX
    some (.load .STX .W .MEM)
  | 0x04 => -- BPF_ALU
    let op := code &&& 0xf0
    let src := (code >>> 3) &&& 0x01
    let src' := if src == 0 then BpfSrc.K else BpfSrc.X
    let op' := match op with
      | 0x00 => some BpfAluOp.ADD | 0x10 => some BpfAluOp.SUB
      | 0x20 => some BpfAluOp.MUL | 0x30 => some BpfAluOp.DIV
      | 0x40 => some BpfAluOp.OR  | 0x50 => some BpfAluOp.AND
      | 0x60 => some BpfAluOp.LSH | 0x70 => some BpfAluOp.RSH
      | 0x80 => some BpfAluOp.NEG | 0x90 => some BpfAluOp.MOD
      | 0xa0 => some BpfAluOp.XOR
      | _ => none
    match op' with
    | some o => some (.alu o src')
    | none => none
  | 0x05 => -- BPF_JMP
    let op := code &&& 0xf0
    let src := (code >>> 3) &&& 0x01
    let src' := if src == 0 then BpfSrc.K else BpfSrc.X
    let op' := match op with
      | 0x00 => some BpfJmpOp.JA   | 0x10 => some BpfJmpOp.JEQ
      | 0x20 => some BpfJmpOp.JGT  | 0x30 => some BpfJmpOp.JGE
      | 0x40 => some BpfJmpOp.JSET
      | _ => none
    match op' with
    | some o => some (.jmp o src')
    | none => none
  | 0x06 => -- BPF_RET: RVAL field is bits 3-4 (BPF_RVAL mask = 0x18)
    -- BPF_K=0x00 → code=0x06 → rval=0; BPF_A=0x10 → code=0x16 → rval=2
    let rval := (code >>> 3) &&& 0x03
    match rval with
    | 0x00 => some (.ret .K)
    | 0x02 => some (.ret .A)
    | _ => none
  | 0x07 => -- BPF_MISC
    let miscOp := code &&& 0xf8
    match miscOp with
    | 0x00 => some (.misc .TAX)
    | 0x80 => some (.misc .TXA)
    | _ => none
  | _ => none

/-- Decode the opcode field of a SockFilter instruction.
    Delegates to `decodeCode` on the code field. -/
def SockFilter.decodeOpcode (f : SockFilter) : Option BpfOpcode :=
  decodeCode f.code

@[simp] theorem SockFilter.decodeOpcode_eq (f : SockFilter) :
    f.decodeOpcode = decodeCode f.code := rfl

/-- Decode lemmas for concrete opcodes used in theorems. -/
@[simp] theorem decodeCode_0x00 : decodeCode 0x00 = some (.load .LD .W .IMM) := by native_decide
@[simp] theorem decodeCode_0x20 : decodeCode 0x20 = some (.load .LD .W .ABS) := by native_decide
@[simp] theorem decodeCode_0x07 : decodeCode 0x07 = some (.misc .TAX) := by native_decide
@[simp] theorem decodeCode_0x34 : decodeCode 0x34 = some (.alu .DIV .K) := by native_decide
@[simp] theorem decodeCode_0x87 : decodeCode 0x87 = some (.misc .TXA) := by native_decide

/-! ## SockFprog -/

/-- A BPF filter program (struct sock_fprog).
    The `len` field is implicit via `filter.size`. -/
structure SockFprog where
  filter : Array SockFilter
  deriving Repr

/-! ## SeccompData -/

/-- The seccomp_data structure passed to BPF filters by the kernel.
    64 bytes total, representing syscall context.

    Layout (from include/uapi/linux/seccomp.h):
    - offset 0:  nr (syscall number, 4 bytes)
    - offset 4:  arch (AUDIT_ARCH_*, 4 bytes)
    - offset 8:  instruction_pointer (8 bytes)
    - offset 16: args[0..5] (6 x 8 bytes = 48 bytes)

    args uses `Fin 6 -> UInt64` as a total function (not Array). -/
structure SeccompData where
  nr                  : Int32
  arch                : UInt32
  instruction_pointer : UInt64
  args                : Fin 6 → UInt64

/-- Read a 32-bit word from the seccomp_data structure at the given byte offset.
    Returns `none` for offsets >= 64 or not 4-aligned.

    Byte layout:
    - 0: nr (as UInt32), 4: arch
    - 8: instruction_pointer low, 12: instruction_pointer high
    - 16,20: args[0] low,high ... 56,60: args[5] low,high -/
def SeccompData.readWord (d : SeccompData) (offset : UInt32) : Option UInt32 :=
  match offset with
  | 0  => some d.nr.toUInt32
  | 4  => some d.arch
  | 8  => some (d.instruction_pointer &&& 0xffffffff).toUInt32
  | 12 => some (d.instruction_pointer >>> 32).toUInt32
  | 16 => some (d.args ⟨0, by omega⟩ &&& 0xffffffff).toUInt32
  | 20 => some (d.args ⟨0, by omega⟩ >>> 32).toUInt32
  | 24 => some (d.args ⟨1, by omega⟩ &&& 0xffffffff).toUInt32
  | 28 => some (d.args ⟨1, by omega⟩ >>> 32).toUInt32
  | 32 => some (d.args ⟨2, by omega⟩ &&& 0xffffffff).toUInt32
  | 36 => some (d.args ⟨2, by omega⟩ >>> 32).toUInt32
  | 40 => some (d.args ⟨3, by omega⟩ &&& 0xffffffff).toUInt32
  | 44 => some (d.args ⟨3, by omega⟩ >>> 32).toUInt32
  | 48 => some (d.args ⟨4, by omega⟩ &&& 0xffffffff).toUInt32
  | 52 => some (d.args ⟨4, by omega⟩ >>> 32).toUInt32
  | 56 => some (d.args ⟨5, by omega⟩ &&& 0xffffffff).toUInt32
  | 60 => some (d.args ⟨5, by omega⟩ >>> 32).toUInt32
  | _  => none

/-! ## BPF machine state -/

/-- BPF virtual machine state.
    - A: accumulator register (32-bit)
    - X: index register (32-bit)
    - M: scratch memory (16 x 32-bit words, total function)
    - pc: program counter (instruction index) -/
structure BpfMachineState where
  A  : UInt32
  X  : UInt32
  M  : Fin 16 → UInt32
  pc : Nat

/-- Initial BPF machine state: all registers and memory zeroed. -/
def BpfMachineState.initial : BpfMachineState :=
  { A := 0, X := 0, M := fun _ => 0, pc := 0 }

/-! ## Return value types -/

/-- A seccomp filter return value (32-bit). -/
abbrev SeccompReturnValue := UInt32

/-- Mask for extracting the action from a return value (upper 16 bits). -/
def SECCOMP_RET_ACTION_FULL : UInt32 := 0xffff0000

/-- Mask for extracting the data from a return value (lower 16 bits). -/
def SECCOMP_RET_DATA : UInt32 := 0x0000ffff

/-- Seccomp filter actions, ordered by priority (KILL_PROCESS highest). -/
inductive SeccompAction where
  | KILL_PROCESS | KILL_THREAD | TRAP | ERRNO
  | USER_NOTIF | TRACE | LOG | ALLOW
  deriving DecidableEq, Repr

/-- Map a SeccompAction to its kernel return value (action bits only). -/
def SeccompAction.toUInt32 : SeccompAction → UInt32
  | .KILL_PROCESS => 0x80000000
  | .KILL_THREAD  => 0x00000000
  | .TRAP         => 0x00030000
  | .ERRNO        => 0x00050000
  | .USER_NOTIF   => 0x7fc00000
  | .TRACE        => 0x7ff00000
  | .LOG          => 0x7ffc0000
  | .ALLOW        => 0x7fff0000

/-- Extract a SeccompAction from a raw return value using the action mask.
    Returns `none` for unrecognized action values. -/
def SeccompAction.ofReturnValue (v : UInt32) : Option SeccompAction :=
  let action := v &&& SECCOMP_RET_ACTION_FULL
  match action with
  | 0x80000000 => some .KILL_PROCESS
  | 0x00000000 => some .KILL_THREAD
  | 0x00030000 => some .TRAP
  | 0x00050000 => some .ERRNO
  | 0x7fc00000 => some .USER_NOTIF
  | 0x7ff00000 => some .TRACE
  | 0x7ffc0000 => some .LOG
  | 0x7fff0000 => some .ALLOW
  | _          => none

/-- A chain of seccomp filters, evaluated in order.
    Head of list = most recently installed filter. -/
abbrev FilterChain := List SockFprog

end SWELib.OS.Seccomp
