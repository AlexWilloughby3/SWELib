#!/bin/bash

# audit-bridge.sh
# Verify that all axioms in bridge/ have tracking issues linked via TRUST comments.

set -e

BRIDGE_DIR="bridge"
TRUSTED_COMMENT_PATTERN="-- TRUST:"

echo "Auditing bridge/ axioms..."
echo ""

# Find all .lean files in bridge/
files=$(find "$BRIDGE_DIR" -name "*.lean" -type f)
total_files=0
axioms_with_trust=0
axioms_without_trust=0

for file in $files; do
    total_files=$((total_files + 1))

    # Count lines with TRUST comments
    trust_lines=$(grep -c "$TRUSTED_COMMENT_PATTERN" "$file" || true)

    if [ "$trust_lines" -gt 0 ]; then
        axioms_with_trust=$((axioms_with_trust + trust_lines))
        echo "✓ $file ($trust_lines TRUST comments)"
    else
        # Check if file contains axioms or theorems that should have TRUST
        if grep -q "axiom\|theorem\|lemma" "$file" 2>/dev/null; then
            axioms_without_trust=$((axioms_without_trust + 1))
            echo "✗ $file (contains axioms but no TRUST comments)"
        fi
    fi
done

echo ""
echo "Summary:"
echo "  Files scanned:           $total_files"
echo "  Axioms with TRUST:       $axioms_with_trust"
echo "  Axioms without TRUST:    $axioms_without_trust"
echo ""

if [ "$axioms_without_trust" -eq 0 ]; then
    echo "✓ All axioms have TRUST comments!"
    exit 0
else
    echo "✗ Some axioms are missing TRUST comments. Please add tracking issues."
    exit 1
fi
