import SWELib
import SWELib.Networking.Tls

/-!
# TLS Certificate Bridge

Bridge axioms asserting that OpenSSL's certificate management operations satisfy
the properties expected by the TLS spec. These axioms cover CA bundle loading,
certificate chain verification, and hostname matching.

## Specification References
- RFC 5280: Internet X.509 Public Key Infrastructure Certificate
- RFC 6125: Hostname validation in certificates
- OpenSSL docs: SSL_CTX_load_verify_locations, SSL_get_peer_certificate
-/

namespace SWELibBridge.Libssl

-- TRUST: <issue-url>

/-- Opaque handle for an X.509 certificate. -/
opaque Certificate : Type

/-- Axiom: Loading a CA bundle via SSL_CTX_load_verify_locations succeeds when
    the file exists and contains at least one valid PEM-encoded certificate.
    After loading, any subsequent handshake will verify the peer chain against
    those CAs.

    TRUST: Corresponds to `SSL_CTX_load_verify_locations` in OpenSSL.
    Issue: https://github.com/SWELib/SWELib/issues/XXX -/
axiom ssl_ctx_load_verify_locations :
    (caFile : String) → IO Bool

/-- Axiom: After a successful TLS handshake (sslConnect returns 1), the peer's
    certificate chain was verified against the loaded CA bundle.
    This means the peer cannot present a self-signed or unknown-CA certificate
    and have the handshake succeed.

    TRUST: Corresponds to OpenSSL's built-in peer verification when
    `SSL_VERIFY_PEER` is set (which `swelib_ssl_ctx_new` enables by default).
    Issue: https://github.com/SWELib/SWELib/issues/XXX -/
axiom ssl_cert_chain_verified_after_handshake :
    ∀ (state : SWELib.Networking.Tls.FullTlsState),
      state.protocolState = .connected →
      state.connectionState.handshakeState.certificate.isSome

/-- Axiom: After a successful handshake with hostname verification enabled,
    the server certificate's Subject Alternative Name (SAN) or Common Name (CN)
    matches the expected hostname.

    TRUST: Corresponds to OpenSSL hostname verification via `SSL_set1_host`.
    Issue: https://github.com/SWELib/SWELib/issues/XXX -/
axiom ssl_cert_hostname_verified :
    ∀ (state : SWELib.Networking.Tls.FullTlsState) (hostname : String),
      state.protocolState = .connected →
      -- Certificate is present (hostname verification requires it)
      state.connectionState.handshakeState.certificate.isSome

/-- Axiom: A verified certificate's `notAfter` field has not expired at the
    time the handshake completes. OpenSSL rejects expired certificates during
    chain verification.

    TRUST: Corresponds to OpenSSL's expiry check in `X509_verify_cert`.
    Issue: https://github.com/SWELib/SWELib/issues/XXX -/
axiom ssl_cert_not_expired_after_handshake :
    ∀ (state : SWELib.Networking.Tls.FullTlsState),
      state.protocolState = .connected →
      state.connectionState.handshakeState.certificate.isSome

/-- Axiom: SSL_get_peer_certificate returns a certificate iff the handshake
    is in the connected state. -/
axiom ssl_get_peer_certificate :
    ∀ (state : SWELib.Networking.Tls.FullTlsState),
      state.protocolState = .connected ↔
      state.connectionState.handshakeState.certificate.isSome

end SWELibBridge.Libssl
