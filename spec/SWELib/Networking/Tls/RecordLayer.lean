import SWELib.Basics.Bytes
import SWELib.Networking.Tls.HandshakeMessages

/-!
# TLS Record Layer

Record layer structures for TLS protocol (RFC 8446 Section 5).
-/

namespace SWELib.Networking.Tls

/-- TLS Plaintext record (RFC 8446 Section 5.1). -/
structure TLSPlaintext where
  /-- Content type -/
  type : ContentType
  /-- Protocol version (legacy field) -/
  legacyRecordVersion : ProtocolVersion
  /-- Fragment data -/
  fragment : ByteArray
  deriving DecidableEq, Repr

/-- TLS Ciphertext record (RFC 8446 Section 5.2). -/
structure TLSCiphertext where
  /-- Opaque type (always 0x17 for application data in TLS 1.3) -/
  opaqueType : UInt8
  /-- Legacy version (always 0x0303 for TLS 1.3) -/
  legacyRecordVersion : ProtocolVersion
  /-- Length of encrypted record -/
  length : UInt16
  /-- Encrypted data -/
  encryptedRecord : ByteArray
  deriving DecidableEq, Repr

/-- Alert message (RFC 8446 Section 6). -/
structure Alert where
  /-- Alert level -/
  level : AlertLevel
  /-- Alert description -/
  description : AlertDescription
  deriving DecidableEq, Repr

/-- Change Cipher Spec message (RFC 5246 Section 7.2, TLS 1.2 only). -/
structure ChangeCipherSpec where
  /-- Always 1 -/
  type : UInt8
  deriving DecidableEq, Repr

/-- Application data (RFC 8446 Section 5.2). -/
abbrev ApplicationData := ByteArray

/-- Validate that a TLSPlaintext has valid fragment length (RFC 8446 Section 5.1). -/
def TLSPlaintext.validate : TLSPlaintext → Bool
  | ⟨_, _, fragment⟩ =>
    fragment.size ≤ 16384  -- Maximum TLS record size

/-- Validate that a TLSCiphertext has valid encrypted record length (RFC 8446 Section 5.2). -/
def TLSCiphertext.validate : TLSCiphertext → Bool
  | ⟨_, _, length, encryptedRecord⟩ =>
    encryptedRecord.size = length.toNat &&
    encryptedRecord.size ≤ 16384 + 256  -- Max plaintext + overhead

/-- Validate that an Alert has valid level and description. -/
def Alert.validate : Alert → Bool
  | ⟨_, _⟩ => true  -- All combinations are valid

/-- Validate that a ChangeCipherSpec has the correct type (RFC 5246 Section 7.2). -/
def ChangeCipherSpec.validate : ChangeCipherSpec → Bool
  | ⟨type⟩ => type = 1

/-- Create a TLSPlaintext from a handshake message. -/
def HandshakeMessage.toTLSPlaintext (msg : HandshakeMessage) : TLSPlaintext :=
  let _ := msg
  ⟨.handshake, .tls13, ByteArray.empty⟩  -- Placeholder, actual serialization would be needed

/-- Create a TLSPlaintext from application data. -/
def ApplicationData.toTLSPlaintext (data : ApplicationData) : TLSPlaintext :=
  ⟨.applicationData, .tls13, data⟩

/-- Create a TLSPlaintext from an alert. -/
def Alert.toTLSPlaintext (alert : Alert) : TLSPlaintext :=
  let _ := alert
  ⟨.alert, .tls13, ByteArray.empty⟩  -- Placeholder

/-- Create a TLSPlaintext from a ChangeCipherSpec (TLS 1.2 only). -/
def ChangeCipherSpec.toTLSPlaintext (ccs : ChangeCipherSpec) : TLSPlaintext :=
  let _ := ccs
  ⟨.changeCipherSpec, .tls12, ByteArray.empty⟩  -- Placeholder

/-- Check if a TLSPlaintext contains a handshake message. -/
def TLSPlaintext.isHandshake : TLSPlaintext → Bool
  | ⟨type, _, _⟩ => type = .handshake

/-- Check if a TLSPlaintext contains application data. -/
def TLSPlaintext.isApplicationData : TLSPlaintext → Bool
  | ⟨type, _, _⟩ => type = .applicationData

/-- Check if a TLSPlaintext contains an alert. -/
def TLSPlaintext.isAlert : TLSPlaintext → Bool
  | ⟨type, _, _⟩ => type = .alert

/-- Check if a TLSPlaintext contains a ChangeCipherSpec (TLS 1.2 only). -/
def TLSPlaintext.isChangeCipherSpec : TLSPlaintext → Bool
  | ⟨type, _, _⟩ => type = .changeCipherSpec

/-- Get the maximum fragment length for a given protocol version. -/
def maxFragmentLength : ProtocolVersion → Nat
  | .tls12 => 16384  -- RFC 5246 Section 6.2.1
  | .tls13 => 16384  -- RFC 8446 Section 5.1

/-- Check if a fragment length is valid for the protocol version. -/
def isValidFragmentLength (version : ProtocolVersion) (length : Nat) : Bool :=
  length ≤ maxFragmentLength version

/-- Create a close_notify alert. -/
def closeNotifyAlert : Alert :=
  ⟨.warning, .closeNotify⟩

/-- Create an unexpected_message alert. -/
def unexpectedMessageAlert : Alert :=
  ⟨.fatal, .unexpectedMessage⟩

/-- Create a bad_record_mac alert. -/
def badRecordMacAlert : Alert :=
  ⟨.fatal, .badRecordMac⟩

/-- Create a handshake_failure alert. -/
def handshakeFailureAlert : Alert :=
  ⟨.fatal, .handshakeFailure⟩

/-- Create a decode_error alert. -/
def decodeErrorAlert : Alert :=
  ⟨.fatal, .decodeError⟩

/-- Create a protocol_version alert. -/
def protocolVersionAlert : Alert :=
  ⟨.fatal, .protocolVersion⟩

/-- Create an internal_error alert. -/
def internalErrorAlert : Alert :=
  ⟨.fatal, .internalError⟩

end SWELib.Networking.Tls
