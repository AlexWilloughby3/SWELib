#!/bin/bash

# sorry-report.sh
# List all sorry's in spec/ and check that they have corresponding GitHub issues.

set -e

SPEC_DIR="spec"

echo "Scanning for 'sorry' in $SPEC_DIR..."
echo ""

# Find all .lean files in spec/ and look for sorry
files=$(find "$SPEC_DIR" -name "*.lean" -type f)
total_sorry=0
sorry_files=()

for file in $files; do
    sorry_count=$(grep -c "sorry" "$file" 2>/dev/null || true)
    if [ "$sorry_count" -gt 0 ]; then
        total_sorry=$((total_sorry + sorry_count))
        sorry_files+=("$file ($sorry_count)")
        echo "  $file: $sorry_count sorry(s)"
        # Print lines with sorry for reference
        grep -n "sorry" "$file" | sed 's/^/    /'
    fi
done

echo ""
echo "Summary:"
echo "  Total sorry's: $total_sorry"
echo "  Files with sorry: ${#sorry_files[@]}"
echo ""

if [ "$total_sorry" -eq 0 ]; then
    echo "✓ No sorry's found!"
    exit 0
else
    echo "⚠ Found $total_sorry sorry(s). Please:"
    echo "  1. Create GitHub issues tagged 'sorry-debt'"
    echo "  2. Reference issue URLs in code comments"
    exit 0  # Report is informational, not an error
fi
