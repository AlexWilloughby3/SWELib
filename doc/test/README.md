# Test Documentation

Testing infrastructure for SWELib, covering both proof-level verification and executable conformance tests.

## Directory Structure

```
test/
├── Http_conformance.lean    # RFC 9110 conformance tests via #eval
```

## Test Categories

### Conformance Tests

Executable `#eval` tests that verify spec definitions match RFC examples and normative requirements. These import spec modules and evaluate concrete examples to check that definitions produce expected results.

**Existing:**
- `Http_conformance.lean` — 146 tests covering HTTP methods, status codes, headers, ETags, conditional requests, and proxy behavior per RFC 9110

### Proof Tests (Planned)

Lean `#check` and `example` blocks that verify theorems and type-level properties hold. These don't produce runtime output — they succeed if they type-check.

### Integration Tests (Planned)

End-to-end tests requiring running services (databases, networks). These exercise the impl layer against real infrastructure.

## Writing Conformance Tests

Conformance tests use `#eval` with `decide` to produce boolean pass/fail:

```lean
import SWELib.Networking.Http

-- Test that GET is safe (RFC 9110 Section 9.2.1)
#eval decide (Method.GET.isSafe = true)

-- Test that POST is not safe
#eval decide (Method.POST.isSafe = false)
```

## Running Tests

```bash
lake build        # Compiles everything including test files
lake test         # Runs the test suite
```

## Adding New Tests

1. Create a `.lean` file in `test/` named `{Module}_conformance.lean`
2. Import the relevant spec modules
3. Add `#eval decide (...)` checks for each RFC requirement
4. Run `lake build` to verify all tests pass
