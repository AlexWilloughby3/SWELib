# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- Consolidated three-layer architecture (spec/bridge/code) into two layers (spec/impl)
- Bridge axioms moved to `impl/SWELibImpl/Bridge/`
- FFI bindings and executable code merged into `impl/`
- Removed `scripts/` directory (audit functionality handled by CI and tooling)
- Restructured `doc/sketches/` into `doc/systems-framework/`

### Added

- `spec/SWELib/Foundations/` — abstract systems framework (LTS, Node, Network, System)
- `spec/SWELib/Networking/Ssh/` — SSH protocol formalization
- `spec/SWELib/Networking/Dns/` — DNS formalization
- `spec/SWELib/OS/Systemd/` — systemd unit formalization
- `spec/SWELib/OS/Isolation/` — container/VM isolation formalization
- `spec/SWELib/Cicd/Migration/` — schema migration formalization
- `spec/SWELib/Security/Pki/` — PKI module
- `impl/SWELibImpl/Bridge/Libssh/` — libssh bridge axioms
- Multiple plan documents in `doc/`

## [0.1.0] - 2026-03-14

### Added

- Initial project structure with spec/ and impl/ layers
- Lean 4 project configuration
- Documentation templates
- CI/CD workflow structure
- Test infrastructure
