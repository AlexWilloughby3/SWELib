/-!
# TLS 1.3 Specification

TLS 1.3 specific structures and operations (RFC 8446).
-/

import SWELib.Networking.Tls.Operations

namespace SWELib.Networking.Tls

/-- TLS 1.3 specific cipher suites (RFC 8446 Appendix B.4). -/
inductive CipherSuiteTls13 where
  /-- TLS_AES_128_GCM_SHA256 (RFC 8446 Appendix B.4) -/
  | tlsAes128GcmSha256 : CipherSuiteTls13
  /-- TLS_AES_256_GCM_SHA384 (RFC 8446 Appendix B.4) -/
  | tlsAes256GcmSha384 : CipherSuiteTls13
  /-- TLS_CHACHA20_POLY1305_SHA256 (RFC 8446 Appendix B.4) -/
  | tlsChacha20Poly1305Sha256 : CipherSuiteTls13
  /-- TLS_AES_128_CCM_SHA256 (RFC 8446 Appendix B.4) -/
  | tlsAes128CcmSha256 : CipherSuiteTls13
  /-- TLS_AES_128_CCM_8_SHA256 (RFC 8446 Appendix B.4) -/
  | tlsAes128Ccm8Sha256 : CipherSuiteTls13
  deriving DecidableEq, Repr

/-- Convert TLS 1.3 cipher suite to wire representation (RFC 8446 Appendix B.4). -/
def CipherSuiteTls13.toUInt16 : CipherSuiteTls13 → UInt16
  | .tlsAes128GcmSha256 => 0x1301
  | .tlsAes256GcmSha384 => 0x1302
  | .tlsChacha20Poly1305Sha256 => 0x1303
  | .tlsAes128CcmSha256 => 0x1304
  | .tlsAes128Ccm8Sha256 => 0x1305

/-- Parse TLS 1.3 cipher suite from wire representation (RFC 8446 Appendix B.4). -/
def CipherSuiteTls13.fromUInt16 : UInt16 → Option CipherSuiteTls13
  | 0x1301 => some .tlsAes128GcmSha256
  | 0x1302 => some .tlsAes256GcmSha384
  | 0x1303 => some .tlsChacha20Poly1305Sha256
  | 0x1304 => some .tlsAes128CcmSha256
  | 0x1305 => some .tlsAes128Ccm8Sha256
  | _ => none

/-- TLS 1.3 specific extensions (RFC 8446 Section 4.2). -/
inductive ExtensionTypeTls13 where
  /-- supported_versions (RFC 8446 Section 4.2.1) -/
  | supportedVersions : ExtensionTypeTls13
  /-- key_share (RFC 8446 Section 4.2.8) -/
  | keyShare : ExtensionTypeTls13
  /-- pre_shared_key (RFC 8446 Section 4.2.11) -/
  | preSharedKey : ExtensionTypeTls13
  /-- early_data (RFC 8446 Section 4.2.10) -/
  | earlyData : ExtensionTypeTls13
  /-- cookie (RFC 8446 Section 4.2.2) -/
  | cookie : ExtensionTypeTls13
  /-- psk_key_exchange_modes (RFC 8446 Section 4.2.9) -/
  | pskKeyExchangeModes : ExtensionTypeTls13
  deriving DecidableEq, Repr

/-- TLS 1.3 Client Hello structure (RFC 8446 Section 4.1.2). -/
structure ClientHelloTls13 where
  /-- Legacy version field (always 0x0303) -/
  legacyVersion : ProtocolVersion
  /-- Client random -/
  random : Random
  /-- Legacy session ID -/
  legacySessionId : SessionID
  /-- List of cipher suites -/
  cipherSuites : List CipherSuiteTls13
  /-- Legacy compression methods (always [null]) -/
  legacyCompressionMethods : List CompressionMethod
  /-- List of extensions -/
  extensions : List Extension
  deriving DecidableEq, Repr

/-- TLS 1.3 Server Hello structure (RFC 8446 Section 4.1.3). -/
structure ServerHelloTls13 where
  /-- Legacy version field (always 0x0303) -/
  legacyVersion : ProtocolVersion
  /-- Server random -/
  random : Random
  /-- Legacy session ID -/
  legacySessionId : SessionID
  /-- Selected cipher suite -/
  cipherSuite : CipherSuiteTls13
  /-- Legacy compression method (always null) -/
  legacyCompressionMethod : CompressionMethod
  /-- List of extensions -/
  extensions : List Extension
  deriving DecidableEq, Repr

/-- TLS 1.3 0-RTT early data (RFC 8446 Section 4.2.10). -/
structure EarlyDataTls13 where
  /-- Early application data -/
  data : ByteArray
  deriving DecidableEq, Repr

/-- TLS 1.3 PSK binder (RFC 8446 Section 4.2.11.2). -/
structure PskBinderTls13 where
  /-- Binder value -/
  binder : ByteArray
  deriving DecidableEq, Repr

/-- TLS 1.3 HKDF abstraction (RFC 8446 Section 7.1). -/
axiom hkdfExtractTls13 : ByteArray → ByteArray → ByteArray

/-- TLS 1.3 HKDF-Expand abstraction (RFC 8446 Section 7.1). -/
axiom hkdfExpandTls13 : ByteArray → ByteArray → Nat → ByteArray

/-- TLS 1.3 AEAD encryption abstraction (RFC 8446 Section 5.2). -/
axiom aeadEncryptTls13 : ByteArray → ByteArray → ByteArray → ByteArray → ByteArray

/-- TLS 1.3 AEAD decryption abstraction (RFC 8446 Section 5.2). -/
axiom aeadDecryptTls13 : ByteArray → ByteArray → ByteArray → ByteArray → Option ByteArray

/-- Convert TLS 1.3 Client Hello to generic Client Hello. -/
def ClientHelloTls13.toClientHello (ch : ClientHelloTls13) : ClientHello :=
  let cipherSuites := ch.cipherSuites.map (λ cs =>
    match cs with
    | .tlsAes128GcmSha256 => CipherSuite.tlsAes128GcmSha256
    | .tlsAes256GcmSha384 => CipherSuite.tlsAes256GcmSha384
    | .tlsChacha20Poly1305Sha256 => CipherSuite.tlsChacha20Poly1305Sha256
    | .tlsAes128CcmSha256 => CipherSuite.tlsAes128CcmSha256
    | .tlsAes128Ccm8Sha256 => CipherSuite.tlsAes128Ccm8Sha256)
  ⟨ch.legacyVersion, ch.random, ch.legacySessionId, cipherSuites,
   ch.legacyCompressionMethods, ch.extensions⟩

/-- Convert TLS 1.3 Server Hello to generic Server Hello. -/
def ServerHelloTls13.toServerHello (sh : ServerHelloTls13) : ServerHello :=
  let cipherSuite :=
    match sh.cipherSuite with
    | .tlsAes128GcmSha256 => CipherSuite.tlsAes128GcmSha256
    | .tlsAes256GcmSha384 => CipherSuite.tlsAes256GcmSha384
    | .tlsChacha20Poly1305Sha256 => CipherSuite.tlsChacha20Poly1305Sha256
    | .tlsAes128CcmSha256 => CipherSuite.tlsAes128CcmSha256
    | .tlsAes128Ccm8Sha256 => CipherSuite.tlsAes128Ccm8Sha256
  ⟨sh.legacyVersion, sh.random, sh.legacySessionId, cipherSuite,
   sh.legacyCompressionMethod, sh.extensions⟩

/-- TLS 1.3 handshake initiation. -/
def handshakeInitiateTls13 (supportedVersions : List ProtocolVersion)
    (cipherSuites : List CipherSuiteTls13)
    (extensions : List Extension) : ClientHelloTls13 :=
  let random : Random := ⟨ByteArray.empty⟩
  let sessionId : SessionID := ⟨ByteArray.empty⟩
  let legacyVersion : ProtocolVersion := .tls12  -- Always 0x0303 for compatibility
  let compressionMethods : List CompressionMethod := [.null]
  ⟨legacyVersion, random, sessionId, cipherSuites, compressionMethods, extensions⟩

/-- TLS 1.3 handshake response. -/
def handshakeRespondTls13 (clientHello : ClientHelloTls13)
    (selectedCipherSuite : CipherSuiteTls13)
    (extensions : List Extension) : ServerHelloTls13 :=
  let random : Random := ⟨ByteArray.empty⟩
  let sessionId : SessionID := clientHello.legacySessionId
  let legacyVersion : ProtocolVersion := .tls12  -- Always 0x0303 for compatibility
  let compressionMethod : CompressionMethod := .null
  ⟨legacyVersion, random, sessionId, selectedCipherSuite, compressionMethod, extensions⟩

/-- TLS 1.3 HKDF-Extract for key derivation (RFC 8446 Section 7.1). -/
def hkdfExtractTls13KeyDerivation (salt : ByteArray) (ikm : ByteArray) : ByteArray :=
  hkdfExtractTls13 salt ikm

/-- TLS 1.3 HKDF-Expand for key derivation (RFC 8446 Section 7.1). -/
def hkdfExpandTls13KeyDerivation (prk : ByteArray) (info : ByteArray) (length : Nat) : ByteArray :=
  hkdfExpandTls13 prk info length

/-- TLS 1.3 AEAD encryption (RFC 8446 Section 5.2). -/
def aeadEncryptTls13Record (key : ByteArray) (nonce : ByteArray) (plaintext : ByteArray)
    (additionalData : ByteArray) : ByteArray :=
  aeadEncryptTls13 key nonce plaintext additionalData

/-- TLS 1.3 AEAD decryption (RFC 8446 Section 5.2). -/
def aeadDecryptTls13Record (key : ByteArray) (nonce : ByteArray) (ciphertext : ByteArray)
    (additionalData : ByteArray) : Option ByteArray :=
  aeadDecryptTls13 key nonce ciphertext additionalData

/-- Validate TLS 1.3 Client Hello. -/
def ClientHelloTls13.validate : ClientHelloTls13 → Bool
  | ⟨legacyVersion, random, legacySessionId, cipherSuites, legacyCompressionMethods, extensions⟩ =>
    legacyVersion = .tls12 &&  -- Must be 0x0303
    random.validate &&
    legacySessionId.validate &&
    cipherSuites.length > 0 &&
    legacyCompressionMethods = [.null] &&
    hasRequiredExtensionsTls13 extensions

/-- Validate TLS 1.3 Server Hello. -/
def ServerHelloTls13.validate : ServerHelloTls13 → Bool
  | ⟨legacyVersion, random, legacySessionId, cipherSuite, legacyCompressionMethod, extensions⟩ =>
    legacyVersion = .tls12 &&  -- Must be 0x0303
    random.validate &&
    legacySessionId.validate &&
    legacyCompressionMethod = .null

/-- Check if TLS 1.3 cipher suite uses AES-GCM. -/
def CipherSuiteTls13.usesAesGcm : CipherSuiteTls13 → Bool
  | .tlsAes128GcmSha256
  | .tlsAes256GcmSha384 => true
  | _ => false

/-- Check if TLS 1.3 cipher suite uses ChaCha20-Poly1305. -/
def CipherSuiteTls13.usesChaCha20Poly1305 : CipherSuiteTls13 → Bool
  | .tlsChacha20Poly1305Sha256 => true
  | _ => false

/-- Check if TLS 1.3 cipher suite uses AES-CCM. -/
def CipherSuiteTls13.usesAesCcm : CipherSuiteTls13 → Bool
  | .tlsAes128CcmSha256
  | .tlsAes128Ccm8Sha256 => true
  | _ => false

/-- Get key length for TLS 1.3 cipher suite. -/
def CipherSuiteTls13.keyLength : CipherSuiteTls13 → Nat
  | .tlsAes128GcmSha256 => 16
  | .tlsAes256GcmSha384 => 32
  | .tlsChacha20Poly1305Sha256 => 32
  | .tlsAes128CcmSha256 => 16
  | .tlsAes128Ccm8Sha256 => 16

/-- Get IV length for TLS 1.3 cipher suite. -/
def CipherSuiteTls13.ivLength : CipherSuiteTls13 → Nat
  | .tlsAes128GcmSha256 => 12
  | .tlsAes256GcmSha384 => 12
  | .tlsChacha20Poly1305Sha256 => 12
  | .tlsAes128CcmSha256 => 12
  | .tlsAes128Ccm8Sha256 => 12

instance : ToString CipherSuiteTls13 where
  toString cs := match cs with
    | .tlsAes128GcmSha256 => "TLS_AES_128_GCM_SHA256"
    | .tlsAes256GcmSha384 => "TLS_AES_256_GCM_SHA384"
    | .tlsChacha20Poly1305Sha256 => "TLS_CHACHA20_POLY1305_SHA256"
    | .tlsAes128CcmSha256 => "TLS_AES_128_CCM_SHA256"
    | .tlsAes128Ccm8Sha256 => "TLS_AES_128_CCM_8_SHA256"

instance : ToString ExtensionTypeTls13 where
  toString et := match et with
    | .supportedVersions => "supported_versions"
    | .keyShare => "key_share"
    | .preSharedKey => "pre_shared_key"
    | .earlyData => "early_data"
    | .cookie => "cookie"
    | .pskKeyExchangeModes => "psk_key_exchange_modes"

/-- Theorem: TLS 1.3 requires supported_versions extension. -/
theorem tls13_requires_supported_versions_ext (ch : ClientHelloTls13) :
    ch.validate → ch.extensions.any (λ ext => ext.getType = .supportedVersions) := by
  sorry

/-- Theorem: TLS 1.3 Server Hello must select TLS 1.3 cipher suite. -/
theorem tls13_server_hello_cipher_suite (sh : ServerHelloTls13) :
    sh.validate → sh.cipherSuite.isTls13 := by
  sorry

/-- Theorem: TLS 1.3 handshake completes with Finished messages. -/
theorem tls13_handshake_completion (state : FullTlsState) :
    state.connectionState.securityParameters.cipherSuite.isTls13 →
    state.protocolState = .connected →
    state.connectionState.handshakeState.isComplete := by
  sorry

end SWELib.Networking.Tls