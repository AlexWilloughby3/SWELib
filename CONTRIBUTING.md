# Contributing to SWELib

Thank you for your interest in contributing to SWELib! This document provides guidelines and instructions for contributing.

## Code Organization

SWELib has three distinct layers:

### 1. spec/ — Formal Specifications

- Pure Lean definitions, theorems, and proofs
- No `@[extern]`, no IO, no FFI
- Must conform to Mathlib style
- Every `sorry` must have a corresponding GitHub issue tagged `sorry-debt`

### 2. bridge/ — Trust Boundary

- Axioms asserting external functions satisfy spec properties
- Explicitly documents all unproven real-world assumptions
- Every axiom must have a `-- TRUST: <issue-url>` comment
- Auditable as a single surface

### 3. code/ — Executable Implementations

- Imports spec/ for types and bridge/ for extern bindings
- Contains `@[extern]` declarations
- Links against C libraries via FFI

## Adding a New Module

### Naming Conventions

- Spec types: `SWELib.Domain.Concept`
- Bridge axioms: `SWELibBridge.Domain.concept_conforms`
- Code implementations: `SWELibCode.Domain.ConceptImpl`

### File Granularity

- Use one `.lean` file per sub-module (default)
- When a sub-module exceeds ~500 lines, split into a directory with the same name
- Example: `Json.lean` → `Json/Value.lean`, `Json/Parse.lean`, etc.

## Development Workflow

1. Create a branch for your changes
2. Make changes following the guidelines above
3. Run tests: `lake test`
4. Ensure no breaking changes
5. Submit a pull request with a clear description

## Trust Boundary Discipline

Every axiom in `bridge/` must:

1. Have a corresponding GitHub issue documenting the justification
2. Include a `-- TRUST: <issue-url>` comment
3. Be checked by the `scripts/audit-bridge.sh` script

## Sorry Tracking

Every `sorry` in `spec/` must:

1. Have a corresponding GitHub issue tagged `sorry-debt`
2. Be tracked by `scripts/sorry-report.sh`

## Style Guide

- Follow [Lean 4 style conventions](https://lean-lang.org/)
- Use meaningful variable names
- Include docstrings for public definitions
- Keep proofs readable and well-structured

## Questions?

Open an issue or discussion for questions about contributing.
