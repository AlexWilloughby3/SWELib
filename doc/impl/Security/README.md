# Security Implementations

Cryptographic operations backed by OpenSSL via FFI.

## Modules

| File | Description |
|------|-------------|
| `JwtValidator.lean` | JWT validation: Base64url decoding, HMAC/RSA/ECDSA signature verification via `@[extern]` |
| `HashOps.lean` | Hash functions: `sha256Impl`, `sha384Impl`, `sha512Impl`, HMAC via `@[extern]` |
