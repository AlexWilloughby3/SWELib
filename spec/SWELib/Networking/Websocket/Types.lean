import Std
import SWELib.Basics

/-!
# WebSocket Types

Basic enumerations and type definitions for WebSocket protocol (RFC 6455).

## References
- RFC 6455 Section 4: Data Framing
- RFC 6455 Section 5.2: Base Framing Protocol
- RFC 6455 Section 7.4: Status Codes
- W3C WebSocket API: ReadyState, BinaryType
-/

namespace SWELib.Networking.Websocket

/-- WebSocket connection state (W3C WebSocket API Section 4.1). -/
inductive ReadyState where
  | CONNECTING
  | OPEN
  | CLOSING
  | CLOSED
  deriving DecidableEq, Repr

/-- Binary data type for WebSocket messages (W3C WebSocket API Section 4.2). -/
inductive BinaryType where
  | blob
  | arraybuffer
  deriving DecidableEq, Repr

/-- WebSocket frame opcodes (RFC 6455 Section 5.2). -/
inductive Opcode where
  | CONTINUATION  -- 0x0
  | TEXT          -- 0x1
  | BINARY        -- 0x2
  | CLOSE         -- 0x8
  | PING          -- 0x9
  | PONG          -- 0xA
  deriving DecidableEq, Repr

/-- Reserved opcode values (RFC 6455 Section 5.2). -/
def isReservedOpcode (n : Nat) : Bool :=
  n == 3 || n == 4 || n == 5 || n == 6 || n == 7 ||
  n == 0xB || n == 0xC || n == 0xD || n == 0xE || n == 0xF

/-- Valid close status codes (RFC 6455 Section 7.4). -/
inductive CloseCode where
  | NORMAL_CLOSURE               -- 1000
  | GOING_AWAY                   -- 1001
  | PROTOCOL_ERROR               -- 1002
  | UNSUPPORTED_DATA             -- 1003
  | NO_STATUS_RCVD               -- 1005
  | ABNORMAL_CLOSURE             -- 1006
  | INVALID_FRAME_PAYLOAD_DATA   -- 1007
  | POLICY_VIOLATION             -- 1008
  | MESSAGE_TOO_BIG              -- 1009
  | MANDATORY_EXTENSION          -- 1010
  | INTERNAL_ERROR               -- 1011
  | SERVICE_RESTART              -- 1012
  | TRY_AGAIN_LATER              -- 1013
  | BAD_GATEWAY                  -- 1014
  | TLS_HANDSHAKE                -- 1015
  deriving DecidableEq, Repr

/-- Map opcodes to their numeric values. -/
def opcodeToNat : Opcode → Nat
  | .CONTINUATION => 0x0
  | .TEXT => 0x1
  | .BINARY => 0x2
  | .CLOSE => 0x8
  | .PING => 0x9
  | .PONG => 0xA

/-- Map close codes to their numeric values. -/
def closeCodeToNat : CloseCode → Nat
  | .NORMAL_CLOSURE => 1000
  | .GOING_AWAY => 1001
  | .PROTOCOL_ERROR => 1002
  | .UNSUPPORTED_DATA => 1003
  | .NO_STATUS_RCVD => 1005
  | .ABNORMAL_CLOSURE => 1006
  | .INVALID_FRAME_PAYLOAD_DATA => 1007
  | .POLICY_VIOLATION => 1008
  | .MESSAGE_TOO_BIG => 1009
  | .MANDATORY_EXTENSION => 1010
  | .INTERNAL_ERROR => 1011
  | .SERVICE_RESTART => 1012
  | .TRY_AGAIN_LATER => 1013
  | .BAD_GATEWAY => 1014
  | .TLS_HANDSHAKE => 1015

/-- Check if a numeric opcode is valid (RFC 6455 Section 5.2). -/
def isValidOpcode (n : Nat) : Bool :=
  match n with
  | 0x0 => true    -- CONTINUATION
  | 0x1 => true    -- TEXT
  | 0x2 => true    -- BINARY
  | 0x8 => true    -- CLOSE
  | 0x9 => true    -- PING
  | 0xA => true    -- PONG
  | n => isReservedOpcode n

/-- Check if a numeric close code is valid (RFC 6455 Section 7.4). -/
def isValidCloseCode (n : Nat) : Bool :=
  match n with
  | 1000 => true   -- NORMAL_CLOSURE
  | 1001 => true   -- GOING_AWAY
  | 1002 => true   -- PROTOCOL_ERROR
  | 1003 => true   -- UNSUPPORTED_DATA
  | 1005 => true   -- NO_STATUS_RCVD
  | 1006 => true   -- ABNORMAL_CLOSURE
  | 1007 => true   -- INVALID_FRAME_PAYLOAD_DATA
  | 1008 => true   -- POLICY_VIOLATION
  | 1009 => true   -- MESSAGE_TOO_BIG
  | 1010 => true   -- MANDATORY_EXTENSION
  | 1011 => true   -- INTERNAL_ERROR
  | 1012 => true   -- SERVICE_RESTART
  | 1013 => true   -- TRY_AGAIN_LATER
  | 1014 => true   -- BAD_GATEWAY
  | 1015 => true   -- TLS_HANDSHAKE
  | n => (3000 ≤ n && n ≤ 4999)  -- Reserved for libraries, frameworks, applications

/-- Theorem: All defined opcodes are valid. -/
theorem opcode_valid (op : Opcode) : isValidOpcode (opcodeToNat op) = true := by
  cases op <;> simp [isValidOpcode, opcodeToNat]

/-- Theorem: All defined close codes are valid. -/
theorem closeCode_valid (code : CloseCode) : isValidCloseCode (closeCodeToNat code) = true := by
  cases code <;> simp [isValidCloseCode, closeCodeToNat]

/-- Control frames have opcodes ≥ 0x8 (RFC 6455 Section 5.5). -/
def isControlFrame (op : Opcode) : Bool :=
  match op with
  | .CLOSE | .PING | .PONG => true
  | _ => false

/-- Data frames have opcodes ≤ 0x2 (RFC 6455 Section 5.6). -/
def isDataFrame (op : Opcode) : Bool :=
  match op with
  | .CONTINUATION | .TEXT | .BINARY => true
  | _ => false

/-- Theorem: Control and data frames are disjoint sets. -/
theorem control_data_disjoint (op : Opcode) : ¬(isControlFrame op = true ∧ isDataFrame op = true) := by
  cases op <;> simp [isControlFrame, isDataFrame]

end SWELib.Networking.Websocket
