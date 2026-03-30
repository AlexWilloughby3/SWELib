import SWELib.Basics.Bytes

/-!
# TLS Protocol Types

Core type definitions for TLS protocol (RFC 8446 for TLS 1.3, RFC 5246 for TLS 1.2).
-/

namespace SWELib.Networking.Tls

/-- Protocol version identifier (RFC 8446 Appendix B.1). -/
inductive ProtocolVersion where
  /-- TLS 1.2 (RFC 5246) -/
  | tls12 : ProtocolVersion
  /-- TLS 1.3 (RFC 8446) -/
  | tls13 : ProtocolVersion
  deriving DecidableEq, Repr

/-- Convert protocol version to wire representation (RFC 8446 Appendix B.1). -/
def ProtocolVersion.toUInt16 : ProtocolVersion → UInt16
  | .tls12 => 0x0303
  | .tls13 => 0x0304

/-- Parse protocol version from wire representation (RFC 8446 Appendix B.1). -/
def ProtocolVersion.fromUInt16 : UInt16 → Option ProtocolVersion
  | 0x0303 => some .tls12
  | 0x0304 => some .tls13
  | _ => none

/-- Content type of TLS record layer (RFC 8446 Section 5.1). -/
inductive ContentType where
  /-- Change Cipher Spec (TLS 1.2 only, RFC 5246 Section 7.2) -/
  | changeCipherSpec : ContentType
  /-- Alert (RFC 8446 Section 6) -/
  | alert : ContentType
  /-- Handshake (RFC 8446 Section 4) -/
  | handshake : ContentType
  /-- Application Data (RFC 8446 Section 5.2) -/
  | applicationData : ContentType
  deriving DecidableEq, Repr

/-- Convert content type to wire representation (RFC 8446 Section 5.1). -/
def ContentType.toUInt8 : ContentType → UInt8
  | .changeCipherSpec => 20
  | .alert => 21
  | .handshake => 22
  | .applicationData => 23

/-- Parse content type from wire representation (RFC 8446 Section 5.1). -/
def ContentType.fromUInt8 : UInt8 → Option ContentType
  | 20 => some .changeCipherSpec
  | 21 => some .alert
  | 22 => some .handshake
  | 23 => some .applicationData
  | _ => none

/-- Handshake message type (RFC 8446 Section 4). -/
inductive HandshakeType where
  /-- Client Hello (RFC 8446 Section 4.1.2) -/
  | clientHello : HandshakeType
  /-- Server Hello (RFC 8446 Section 4.1.3) -/
  | serverHello : HandshakeType
  /-- New Session Ticket (RFC 8446 Section 4.6.1) -/
  | newSessionTicket : HandshakeType
  /-- End of Early Data (RFC 8446 Section 4.2.10) -/
  | endOfEarlyData : HandshakeType
  /-- Encrypted Extensions (RFC 8446 Section 4.3.1) -/
  | encryptedExtensions : HandshakeType
  /-- Certificate (RFC 8446 Section 4.4.2) -/
  | certificate : HandshakeType
  /-- Certificate Request (RFC 8446 Section 4.3.2) -/
  | certificateRequest : HandshakeType
  /-- Certificate Verify (RFC 8446 Section 4.4.3) -/
  | certificateVerify : HandshakeType
  /-- Finished (RFC 8446 Section 4.4.4) -/
  | finished : HandshakeType
  /-- Key Update (RFC 8446 Section 4.6.3) -/
  | keyUpdate : HandshakeType
  /-- Message Hash (RFC 8446 Section 4.4.1) -/
  | messageHash : HandshakeType
  deriving DecidableEq, Repr

/-- Convert handshake type to wire representation (RFC 8446 Section 4). -/
def HandshakeType.toUInt8 : HandshakeType → UInt8
  | .clientHello => 1
  | .serverHello => 2
  | .newSessionTicket => 4
  | .endOfEarlyData => 5
  | .encryptedExtensions => 8
  | .certificate => 11
  | .certificateRequest => 13
  | .certificateVerify => 15
  | .finished => 20
  | .keyUpdate => 24
  | .messageHash => 254

/-- Parse handshake type from wire representation (RFC 8446 Section 4). -/
def HandshakeType.fromUInt8 : UInt8 → Option HandshakeType
  | 1 => some .clientHello
  | 2 => some .serverHello
  | 4 => some .newSessionTicket
  | 5 => some .endOfEarlyData
  | 8 => some .encryptedExtensions
  | 11 => some .certificate
  | 13 => some .certificateRequest
  | 15 => some .certificateVerify
  | 20 => some .finished
  | 24 => some .keyUpdate
  | 254 => some .messageHash
  | _ => none

/-- Alert level (RFC 8446 Section 6). -/
inductive AlertLevel where
  /-- Warning (RFC 8446 Section 6.1) -/
  | warning : AlertLevel
  /-- Fatal (RFC 8446 Section 6.2) -/
  | fatal : AlertLevel
  deriving DecidableEq, Repr

/-- Convert alert level to wire representation (RFC 8446 Section 6). -/
def AlertLevel.toUInt8 : AlertLevel → UInt8
  | .warning => 1
  | .fatal => 2

/-- Parse alert level from wire representation (RFC 8446 Section 6). -/
def AlertLevel.fromUInt8 : UInt8 → Option AlertLevel
  | 1 => some .warning
  | 2 => some .fatal
  | _ => none

/-- Alert description (RFC 8446 Section 6). -/
inductive AlertDescription where
  /-- Close notify (RFC 8446 Section 6.1) -/
  | closeNotify : AlertDescription
  /-- Unexpected message (RFC 8446 Section 6.2) -/
  | unexpectedMessage : AlertDescription
  /-- Bad record MAC (RFC 8446 Section 6.2) -/
  | badRecordMac : AlertDescription
  /-- Handshake failure (RFC 8446 Section 6.2) -/
  | handshakeFailure : AlertDescription
  /-- Bad certificate (RFC 8446 Section 6.2) -/
  | badCertificate : AlertDescription
  /-- Unsupported certificate (RFC 8446 Section 6.2) -/
  | unsupportedCertificate : AlertDescription
  /-- Certificate revoked (RFC 8446 Section 6.2) -/
  | certificateRevoked : AlertDescription
  /-- Certificate expired (RFC 8446 Section 6.2) -/
  | certificateExpired : AlertDescription
  /-- Certificate unknown (RFC 8446 Section 6.2) -/
  | certificateUnknown : AlertDescription
  /-- Illegal parameter (RFC 8446 Section 6.2) -/
  | illegalParameter : AlertDescription
  /-- Decode error (RFC 8446 Section 6.2) -/
  | decodeError : AlertDescription
  /-- Access denied (RFC 8446 Section 6.2) -/
  | accessDenied : AlertDescription
  /-- Decrypt error (RFC 8446 Section 6.2) -/
  | decryptError : AlertDescription
  /-- Protocol version (RFC 8446 Section 6.2) -/
  | protocolVersion : AlertDescription
  /-- Insufficient security (RFC 8446 Section 6.2) -/
  | insufficientSecurity : AlertDescription
  /-- Internal error (RFC 8446 Section 6.2) -/
  | internalError : AlertDescription
  /-- User canceled (RFC 8446 Section 6.2) -/
  | userCanceled : AlertDescription
  /-- No renegotiation (RFC 8446 Section 6.2) -/
  | noRenegotiation : AlertDescription
  /-- Missing extension (RFC 8446 Section 6.2) -/
  | missingExtension : AlertDescription
  /-- Unsupported extension (RFC 8446 Section 6.2) -/
  | unsupportedExtension : AlertDescription
  /-- Certificate unobtainable (RFC 8446 Section 6.2) -/
  | certificateUnobtainable : AlertDescription
  deriving DecidableEq, Repr

/-- Convert alert description to wire representation (RFC 8446 Section 6). -/
def AlertDescription.toUInt8 : AlertDescription → UInt8
  | .closeNotify => 0
  | .unexpectedMessage => 10
  | .badRecordMac => 20
  | .handshakeFailure => 40
  | .badCertificate => 42
  | .unsupportedCertificate => 43
  | .certificateRevoked => 44
  | .certificateExpired => 45
  | .certificateUnknown => 46
  | .illegalParameter => 47
  | .decodeError => 50
  | .accessDenied => 49
  | .decryptError => 51
  | .protocolVersion => 70
  | .insufficientSecurity => 71
  | .internalError => 80
  | .userCanceled => 90
  | .noRenegotiation => 100
  | .missingExtension => 109
  | .unsupportedExtension => 110
  | .certificateUnobtainable => 111

/-- Parse alert description from wire representation (RFC 8446 Section 6). -/
def AlertDescription.fromUInt8 : UInt8 → Option AlertDescription
  | 0 => some .closeNotify
  | 10 => some .unexpectedMessage
  | 20 => some .badRecordMac
  | 40 => some .handshakeFailure
  | 42 => some .badCertificate
  | 43 => some .unsupportedCertificate
  | 44 => some .certificateRevoked
  | 45 => some .certificateExpired
  | 46 => some .certificateUnknown
  | 47 => some .illegalParameter
  | 50 => some .decodeError
  | 49 => some .accessDenied
  | 51 => some .decryptError
  | 70 => some .protocolVersion
  | 71 => some .insufficientSecurity
  | 80 => some .internalError
  | 90 => some .userCanceled
  | 100 => some .noRenegotiation
  | 109 => some .missingExtension
  | 110 => some .unsupportedExtension
  | 111 => some .certificateUnobtainable
  | _ => none

/-- Compression method (RFC 5246 Section 7.4.1.2, not used in TLS 1.3). -/
inductive CompressionMethod where
  /-- Null compression (RFC 5246 Section 7.4.1.2) -/
  | null : CompressionMethod
  deriving DecidableEq, Repr

/-- Convert compression method to wire representation (RFC 5246 Section 7.4.1.2). -/
def CompressionMethod.toUInt8 : CompressionMethod → UInt8
  | .null => 0

/-- Parse compression method from wire representation (RFC 5246 Section 7.4.1.2). -/
def CompressionMethod.fromUInt8 : UInt8 → Option CompressionMethod
  | 0 => some .null
  | _ => none

instance : ToString ProtocolVersion where
  toString v := match v with
    | .tls12 => "TLS 1.2"
    | .tls13 => "TLS 1.3"

instance : ToString ContentType where
  toString ct := match ct with
    | .changeCipherSpec => "change_cipher_spec"
    | .alert => "alert"
    | .handshake => "handshake"
    | .applicationData => "application_data"

instance : ToString HandshakeType where
  toString ht := match ht with
    | .clientHello => "client_hello"
    | .serverHello => "server_hello"
    | .newSessionTicket => "new_session_ticket"
    | .endOfEarlyData => "end_of_early_data"
    | .encryptedExtensions => "encrypted_extensions"
    | .certificate => "certificate"
    | .certificateRequest => "certificate_request"
    | .certificateVerify => "certificate_verify"
    | .finished => "finished"
    | .keyUpdate => "key_update"
    | .messageHash => "message_hash"

instance : ToString AlertLevel where
  toString al := match al with
    | .warning => "warning"
    | .fatal => "fatal"

instance : ToString AlertDescription where
  toString ad := match ad with
    | .closeNotify => "close_notify"
    | .unexpectedMessage => "unexpected_message"
    | .badRecordMac => "bad_record_mac"
    | .handshakeFailure => "handshake_failure"
    | .badCertificate => "bad_certificate"
    | .unsupportedCertificate => "unsupported_certificate"
    | .certificateRevoked => "certificate_revoked"
    | .certificateExpired => "certificate_expired"
    | .certificateUnknown => "certificate_unknown"
    | .illegalParameter => "illegal_parameter"
    | .decodeError => "decode_error"
    | .accessDenied => "access_denied"
    | .decryptError => "decrypt_error"
    | .protocolVersion => "protocol_version"
    | .insufficientSecurity => "insufficient_security"
    | .internalError => "internal_error"
    | .userCanceled => "user_canceled"
    | .noRenegotiation => "no_renegotiation"
    | .missingExtension => "missing_extension"
    | .unsupportedExtension => "unsupported_extension"
    | .certificateUnobtainable => "certificate_unobtainable"

instance : ToString CompressionMethod where
  toString cm := match cm with
    | .null => "null"

end SWELib.Networking.Tls
