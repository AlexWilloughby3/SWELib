# Security

Authentication, authorization, and cryptographic primitives.

## Modules

### JWT (6 files)

JSON Web Tokens per RFC 7519.

| File | Key Content |
|------|-------------|
| `Jwt/Types.lean` | JWT types and claims |
| `Jwt/Algorithm.lean` | Signing algorithms (HMAC, RSA, ECDSA) |
| `Jwt/Key.lean` | Key handling |
| `Jwt/Parse.lean` | Token parsing |
| `Jwt/Validate.lean` | Token validation (expiry, audience, issuer) |
| `Jwt/Create.lean` | Token creation |

### PKI / X.509 (7 files)

Certificate infrastructure per RFC 5280, RFC 6960 (OCSP), RFC 5914 (Trust Anchor).

| File | Key Content |
|------|-------------|
| `Pki/Types.lean` | Certificate and chain types |
| `Pki/Extensions.lean` | X.509 extensions |
| `Pki/TrustAnchor.lean` | RFC 5914 trust anchor format |
| `Pki/Crl.lean` | Certificate Revocation Lists |
| `Pki/Operations.lean` | Chain validation operations |
| `Pki/Theorems.lean` | Validation theorems |

### Cryptography (6 files)

| File | Spec Source | Key Content |
|------|-----------|-------------|
| `Crypto/ModularArith.lean` | - | Modular arithmetic primitives |
| `Crypto/EllipticCurve.lean` | - | Elliptic curve structures |
| `Crypto/Ecdh.lean` | - | ECDH key agreement |
| `Crypto/Ecdsa.lean` | - | ECDSA signature scheme |
| `Crypto/Rsa.lean` | - | RSA cryptography |
| `Crypto/Montgomery.lean` | - | Montgomery curve arithmetic |

### Hashing

| File | Spec Source | Key Content |
|------|-----------|-------------|
| `Hashing.lean` | FIPS 180-4, RFC 2104 | `HashAlgorithm` (SHA-1/256/384/512), `HashParams`, HMAC |

### IAM (3 files)

| File | Key Content |
|------|-------------|
| `Iam/Gcp/Types.lean` | GCP IAM model types |
| `Iam/Gcp/Operations.lean` | IAM operations |
| `Iam/Gcp/Invariants.lean` | IAM invariants |

### Stubs

| File | Status |
|------|--------|
| `Oauth.lean` | TODO |
| `Rbac.lean` | TODO |
| `Encryption.lean` | TODO |
| `Cors.lean` | TODO |
