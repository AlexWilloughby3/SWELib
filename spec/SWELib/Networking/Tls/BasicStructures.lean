/-!
# TLS Basic Structures

Basic data structures for TLS protocol (RFC 8446 for TLS 1.3, RFC 5246 for TLS 1.2).
-/

import SWELib.Basics.Bytes
import SWELib.Networking.Tls.Types

namespace SWELib.Networking.Tls

/-- Client random value (RFC 8446 Section 4.1.3).
    In TLS 1.2: 32 bytes (4 bytes time + 28 random bytes)
    In TLS 1.3: 32 random bytes -/
structure Random where
  /-- The random bytes -/
  data : ByteArray
  deriving DecidableEq, Repr

/-- Session identifier (RFC 8446 Section 4.1.2).
    In TLS 1.2: 0-32 bytes
    In TLS 1.3: 0-255 bytes -/
structure SessionID where
  /-- Session identifier bytes -/
  data : ByteArray
  deriving DecidableEq, Repr

/-- Cipher suite identifier (RFC 8446 Appendix B.4). -/
inductive CipherSuite where
  /-- TLS_AES_128_GCM_SHA256 (RFC 8446 Appendix B.4) -/
  | tlsAes128GcmSha256 : CipherSuite
  /-- TLS_AES_256_GCM_SHA384 (RFC 8446 Appendix B.4) -/
  | tlsAes256GcmSha384 : CipherSuite
  /-- TLS_CHACHA20_POLY1305_SHA256 (RFC 8446 Appendix B.4) -/
  | tlsChacha20Poly1305Sha256 : CipherSuite
  /-- TLS_AES_128_CCM_SHA256 (RFC 8446 Appendix B.4) -/
  | tlsAes128CcmSha256 : CipherSuite
  /-- TLS_AES_128_CCM_8_SHA256 (RFC 8446 Appendix B.4) -/
  | tlsAes128Ccm8Sha256 : CipherSuite
  /-- TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256 (RFC 5246 Appendix A.5) -/
  | tlsEcdheRsaWithAes128GcmSha256 : CipherSuite
  /-- TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384 (RFC 5246 Appendix A.5) -/
  | tlsEcdheRsaWithAes256GcmSha384 : CipherSuite
  /-- TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256 (RFC 7905) -/
  | tlsEcdheRsaWithChacha20Poly1305Sha256 : CipherSuite
  deriving DecidableEq, Repr

/-- Convert cipher suite to wire representation (RFC 8446 Appendix B.4). -/
def CipherSuite.toUInt16 : CipherSuite → UInt16
  | .tlsAes128GcmSha256 => 0x1301
  | .tlsAes256GcmSha384 => 0x1302
  | .tlsChacha20Poly1305Sha256 => 0x1303
  | .tlsAes128CcmSha256 => 0x1304
  | .tlsAes128Ccm8Sha256 => 0x1305
  | .tlsEcdheRsaWithAes128GcmSha256 => 0xC02F
  | .tlsEcdheRsaWithAes256GcmSha384 => 0xC030
  | .tlsEcdheRsaWithChacha20Poly1305Sha256 => 0xCCA8

/-- Parse cipher suite from wire representation (RFC 8446 Appendix B.4). -/
def CipherSuite.fromUInt16 : UInt16 → Option CipherSuite
  | 0x1301 => some .tlsAes128GcmSha256
  | 0x1302 => some .tlsAes256GcmSha384
  | 0x1303 => some .tlsChacha20Poly1305Sha256
  | 0x1304 => some .tlsAes128CcmSha256
  | 0x1305 => some .tlsAes128Ccm8Sha256
  | 0xC02F => some .tlsEcdheRsaWithAes128GcmSha256
  | 0xC030 => some .tlsEcdheRsaWithAes256GcmSha384
  | 0xCCA8 => some .tlsEcdheRsaWithChacha20Poly1305Sha256
  | _ => none

/-- Named group for key exchange (RFC 8446 Section 4.2.7). -/
inductive NamedGroup where
  /-- secp256r1 (RFC 8446 Section 4.2.7) -/
  | secp256r1 : NamedGroup
  /-- secp384r1 (RFC 8446 Section 4.2.7) -/
  | secp384r1 : NamedGroup
  /-- secp521r1 (RFC 8446 Section 4.2.7) -/
  | secp521r1 : NamedGroup
  /-- x25519 (RFC 8446 Section 4.2.7) -/
  | x25519 : NamedGroup
  /-- x448 (RFC 8446 Section 4.2.7) -/
  | x448 : NamedGroup
  /-- ffdhe2048 (RFC 8446 Section 4.2.7) -/
  | ffdhe2048 : NamedGroup
  /-- ffdhe3072 (RFC 8446 Section 4.2.7) -/
  | ffdhe3072 : NamedGroup
  /-- ffdhe4096 (RFC 8446 Section 4.2.7) -/
  | ffdhe4096 : NamedGroup
  deriving DecidableEq, Repr

/-- Convert named group to wire representation (RFC 8446 Section 4.2.7). -/
def NamedGroup.toUInt16 : NamedGroup → UInt16
  | .secp256r1 => 0x0017
  | .secp384r1 => 0x0018
  | .secp521r1 => 0x0019
  | .x25519 => 0x001D
  | .x448 => 0x001E
  | .ffdhe2048 => 0x0100
  | .ffdhe3072 => 0x0101
  | .ffdhe4096 => 0x0102

/-- Parse named group from wire representation (RFC 8446 Section 4.2.7). -/
def NamedGroup.fromUInt16 : UInt16 → Option NamedGroup
  | 0x0017 => some .secp256r1
  | 0x0018 => some .secp384r1
  | 0x0019 => some .secp521r1
  | 0x001D => some .x25519
  | 0x001E => some .x448
  | 0x0100 => some .ffdhe2048
  | 0x0101 => some .ffdhe3072
  | 0x0102 => some .ffdhe4096
  | _ => none

/-- Signature scheme (RFC 8446 Section 4.2.3). -/
inductive SignatureScheme where
  /-- rsa_pkcs1_sha256 (RFC 8446 Section 4.2.3) -/
  | rsaPkcs1Sha256 : SignatureScheme
  /-- rsa_pkcs1_sha384 (RFC 8446 Section 4.2.3) -/
  | rsaPkcs1Sha384 : SignatureScheme
  /-- rsa_pkcs1_sha512 (RFC 8446 Section 4.2.3) -/
  | rsaPkcs1Sha512 : SignatureScheme
  /-- ecdsa_secp256r1_sha256 (RFC 8446 Section 4.2.3) -/
  | ecdsaSecp256r1Sha256 : SignatureScheme
  /-- ecdsa_secp384r1_sha384 (RFC 8446 Section 4.2.3) -/
  | ecdsaSecp384r1Sha384 : SignatureScheme
  /-- ecdsa_secp521r1_sha512 (RFC 8446 Section 4.2.3) -/
  | ecdsaSecp521r1Sha512 : SignatureScheme
  /-- ed25519 (RFC 8446 Section 4.2.3) -/
  | ed25519 : SignatureScheme
  /-- ed448 (RFC 8446 Section 4.2.3) -/
  | ed448 : SignatureScheme
  deriving DecidableEq, Repr

/-- Convert signature scheme to wire representation (RFC 8446 Section 4.2.3). -/
def SignatureScheme.toUInt16 : SignatureScheme → UInt16
  | .rsaPkcs1Sha256 => 0x0401
  | .rsaPkcs1Sha384 => 0x0501
  | .rsaPkcs1Sha512 => 0x0601
  | .ecdsaSecp256r1Sha256 => 0x0403
  | .ecdsaSecp384r1Sha384 => 0x0503
  | .ecdsaSecp521r1Sha512 => 0x0603
  | .ed25519 => 0x0807
  | .ed448 => 0x0808

/-- Parse signature scheme from wire representation (RFC 8446 Section 4.2.3). -/
def SignatureScheme.fromUInt16 : UInt16 → Option SignatureScheme
  | 0x0401 => some .rsaPkcs1Sha256
  | 0x0501 => some .rsaPkcs1Sha384
  | 0x0601 => some .rsaPkcs1Sha512
  | 0x0403 => some .ecdsaSecp256r1Sha256
  | 0x0503 => some .ecdsaSecp384r1Sha384
  | 0x0603 => some .ecdsaSecp521r1Sha512
  | 0x0807 => some .ed25519
  | 0x0808 => some .ed448
  | _ => none

instance : ToString CipherSuite where
  toString cs := match cs with
    | .tlsAes128GcmSha256 => "TLS_AES_128_GCM_SHA256"
    | .tlsAes256GcmSha384 => "TLS_AES_256_GCM_SHA384"
    | .tlsChacha20Poly1305Sha256 => "TLS_CHACHA20_POLY1305_SHA256"
    | .tlsAes128CcmSha256 => "TLS_AES_128_CCM_SHA256"
    | .tlsAes128Ccm8Sha256 => "TLS_AES_128_CCM_8_SHA256"
    | .tlsEcdheRsaWithAes128GcmSha256 => "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256"
    | .tlsEcdheRsaWithAes256GcmSha384 => "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384"
    | .tlsEcdheRsaWithChacha20Poly1305Sha256 => "TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256"

instance : ToString NamedGroup where
  toString ng := match ng with
    | .secp256r1 => "secp256r1"
    | .secp384r1 => "secp384r1"
    | .secp521r1 => "secp521r1"
    | .x25519 => "x25519"
    | .x448 => "x448"
    | .ffdhe2048 => "ffdhe2048"
    | .ffdhe3072 => "ffdhe3072"
    | .ffdhe4096 => "ffdhe4096"

instance : ToString SignatureScheme where
  toString ss := match ss with
    | .rsaPkcs1Sha256 => "rsa_pkcs1_sha256"
    | .rsaPkcs1Sha384 => "rsa_pkcs1_sha384"
    | .rsaPkcs1Sha512 => "rsa_pkcs1_sha512"
    | .ecdsaSecp256r1Sha256 => "ecdsa_secp256r1_sha256"
    | .ecdsaSecp384r1Sha384 => "ecdsa_secp384r1_sha384"
    | .ecdsaSecp521r1Sha512 => "ecdsa_secp521r1_sha512"
    | .ed25519 => "ed25519"
    | .ed448 => "ed448"

/-- Validate that a Random has the correct length (RFC 8446 Section 4.1.3). -/
def Random.validate : Random → Bool
  | ⟨data⟩ => data.size = 32

/-- Validate that a SessionID has valid length (RFC 8446 Section 4.1.2). -/
def SessionID.validate : SessionID → Bool
  | ⟨data⟩ => data.size ≤ 255  -- TLS 1.3 allows up to 255 bytes

/-- Check if a cipher suite is for TLS 1.3 (RFC 8446 Appendix B.4). -/
def CipherSuite.isTls13 : CipherSuite → Bool
  | .tlsAes128GcmSha256
  | .tlsAes256GcmSha384
  | .tlsChacha20Poly1305Sha256
  | .tlsAes128CcmSha256
  | .tlsAes128Ccm8Sha256 => true
  | _ => false

/-- Check if a cipher suite is for TLS 1.2 (RFC 5246 Appendix A.5). -/
def CipherSuite.isTls12 : CipherSuite → Bool
  | .tlsEcdheRsaWithAes128GcmSha256
  | .tlsEcdheRsaWithAes256GcmSha384
  | .tlsEcdheRsaWithChacha20Poly1305Sha256 => true
  | _ => false

end SWELib.Networking.Tls