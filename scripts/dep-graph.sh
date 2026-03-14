#!/bin/bash

# dep-graph.sh
# Generate a module dependency graph.

echo "Generating module dependency graph..."
echo ""

# Count imports in each layer
echo "Imports by layer:"
echo ""

echo "spec/ imports:"
grep -h "^import" spec/SWELib.lean | wc -l
echo "  (Mathlib + internal)"
echo ""

echo "bridge/ imports:"
grep -h "^import" bridge/SWELibBridge.lean | wc -l
echo "  (SWELib + internal)"
echo ""

echo "code/ imports:"
grep -h "^import" code/SWELibCode.lean | wc -l
echo "  (SWELib + SWELibBridge + internal)"
echo ""

echo "Dependency graph:"
echo ""
echo "┌────────┐"
echo "│ spec/  │  (Mathlib)"
echo "└───┬────┘"
echo "    │ imports"
echo "    ▼"
echo "┌────────┐"
echo "│bridge/ │  (spec/)"
echo "└───┬────┘"
echo "    │ imports"
echo "    ▼"
echo "┌────────┐"
echo "│ code/  │  (spec/ + bridge/ + C FFI)"
echo "└────────┘"
