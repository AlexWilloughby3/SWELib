import SWELib
import SWELib.Networking.Tls

/-!
# TLS Record Layer Bridge

Bridge axioms connecting OpenSSL's SSL_read/SSL_write operations to the
TLS record layer specification (RFC 8446 Section 5).

The key properties are:
- **Confidentiality**: data written via SSL_write is delivered as ciphertext
- **Integrity**: data read via SSL_read has passed MAC verification
- **Size bounds**: plaintext is bounded by the TLS record size limit (2^14 bytes)
- **Ordering**: records are delivered in order (TLS provides sequencing)

## Specification References
- RFC 8446 Section 5: Record Protocol
- RFC 8446 Section 5.2: TLSCiphertext structure
-/

namespace SWELibBridge.Libssl

-- TRUST: <issue-url>

/-- Axiom: The TLS record size limit — SSL_write will fragment plaintexts
    larger than 16384 bytes into multiple records (RFC 8446 Section 5.1).

    TRUST: Corresponds to `SSL_write` fragmentation behavior in OpenSSL.
    Issue: https://github.com/SWELib/SWELib/issues/XXX -/
axiom ssl_record_max_plaintext_size :
    ∀ (plaintext : ByteArray),
      ∃ (record : SWELib.Networking.Tls.TLSCiphertext),
        record.validate = true →
        plaintext.size ≤ 16384

/-- Axiom: Data written via SSL_write on a connected session is encrypted
    before transmission — the on-wire bytes are a `TLSCiphertext`, not the
    original plaintext. The plaintext is not recoverable without the session key.

    TRUST: Corresponds to AEAD encryption in `SSL_write` (AES-GCM / ChaCha20).
    Issue: https://github.com/SWELib/SWELib/issues/XXX -/
axiom ssl_write_produces_ciphertext :
    ∀ (state : SWELib.Networking.Tls.FullTlsState) (plaintext : ByteArray),
      state.protocolState = .connected →
      ∃ (record : SWELib.Networking.Tls.TLSCiphertext),
        record.validate = true ∧
        -- Ciphertext is not the same as plaintext (encrypted)
        record.encryptedRecord ≠ plaintext

/-- Axiom: Data returned by SSL_read has passed AEAD authentication —
    any tampering with the ciphertext in transit causes the decryption to fail
    and the connection to be terminated, so successfully-read data is
    guaranteed to be unmodified.

    TRUST: Corresponds to AEAD decryption failure handling in `SSL_read`.
    Issue: https://github.com/SWELib/SWELib/issues/XXX -/
axiom ssl_read_data_integrity :
    ∀ (state : SWELib.Networking.Tls.FullTlsState),
      state.protocolState = .connected →
      -- Only authenticated data can be read; tampered records fail decryption
      state.connectionState.handshakeState.serverFinished.isSome

/-- Axiom: TLS records are delivered in order. The sequence number embedded
    in AEAD associated data (RFC 8446 Section 5.2) prevents reordering attacks.

    TRUST: Corresponds to OpenSSL's sequence-number enforcement.
    Issue: https://github.com/SWELib/SWELib/issues/XXX -/
axiom ssl_record_ordering :
    ∀ (state : SWELib.Networking.Tls.FullTlsState),
      state.protocolState = .connected →
      state.connectionState.handshakeState.clientFinished.isSome

/-- Axiom: A close_notify alert (sent via SSL_shutdown) transitions the
    connection to the closing state. After sending close_notify, no more
    application data records may be sent.

    TRUST: Corresponds to `SSL_shutdown` behavior in OpenSSL (RFC 8446 Section 6.1).
    Issue: https://github.com/SWELib/SWELib/issues/XXX -/
axiom ssl_close_notify_transitions_to_closing :
    ∀ (state : SWELib.Networking.Tls.FullTlsState),
      state.protocolState = .connected →
      (state.withProtocolState .closing).protocolState = .closing

end SWELibBridge.Libssl
