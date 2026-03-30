# Basics

Data formats, serialization standards, and encoding specifications.

## Modules

### Data Formats

| File | Spec Source | Key Types | Status |
|------|-----------|-----------|--------|
| `Csv.lean` | RFC 4180 | `CsvField`, `CsvRecord`, `CsvFile` | Complete |
| `Protobuf.lean` | Protocol Buffers (proto3) | `WireType`, field tags/values | Complete |
| `Regex.lean` | IEEE 1003.1 (POSIX ERE) | `CharClass`, `Regex` AST | Complete |
| `Semver.lean` | Semantic Versioning 2.0.0 | `PreReleaseId`, `Semver` | Complete |
| `Toml.lean` | TOML v1.0.0 | `TomlValue`, tables | Complete |
| `Uri.lean` | RFC 3986 | `UriAuthority`, `Uri` | Complete |
| `Uuid.lean` | RFC 9562 | `UuidVariant`, `UuidVersion`, 128-bit structure | Complete |
| `Xml.lean` | XML 1.0 / XML Infoset | `XmlName`, `XmlNode` tree | Complete |
| `Yaml.lean` | YAML 1.2.2 | `YamlTag`, `YamlNode` (scalar/sequence/mapping) | Complete |
| `Time.lean` | RFC 7519 (NumericDate) | Unix epoch seconds, `Std.Time.Timestamp` conversion | Complete |

### JSON Ecosystem

| File | Spec Source | Key Types | Status |
|------|-----------|-----------|--------|
| `JsonPointer.lean` | RFC 6901 | `JsonPointer`, parse/resolve ops | Complete |
| `JsonPatch.lean` | RFC 6902 | `JsonPatchOp` (add/remove/replace/move/copy/test) | Complete |
| `JsonSchema.lean` | JSON Schema | Type checking, validation predicates | Complete |
| `JsonMergePatch.lean` | RFC 7386 | Object-level merge with null deletion | Complete |

### Encoding and Streams

| File | Spec Source | Key Types | Status |
|------|-----------|-----------|--------|
| `Base64url.lean` | RFC 4648 | Encode/decode for base64url alphabet | Complete |
| `ByteStream.lean` | (Internal) | `ByteStream`, `StreamPair`, `MessageStream`, `FramingProtocol` | Complete |
| `Bytes.lean` | - | Byte utilities | Stub |
| `Strings.lean` | - | String utilities | Stub |

## Design Decisions

- JSON values use `Lean.Data.Json` from the standard library (see [D-002](representation-decisions.md))
- YAML models the representation graph only; anchors/aliases are serialization concerns (see [D-007](representation-decisions.md))
- UUID uses a pair of `UInt64` for efficient 128-bit representation (see [D-010](representation-decisions.md))
- Regex models abstract syntax only; matching semantics belong in the impl layer (see [D-009](representation-decisions.md))
