#!/usr/bin/env bash
# Prints one leveled section from a lab's hints.md.
# Usage: show-hint.sh <lab-dir> <level>
# hints.md is expected to use "## Level N" headings (N = 1, 2, 3, ...).
set -Eeuo pipefail

LAB_DIR="${1:?Usage: show-hint.sh <lab-dir> <level>}"
LEVEL="${2:?Usage: show-hint.sh <lab-dir> <level>}"
HINTS_FILE="${LAB_DIR}/hints.md"

[[ -f "$HINTS_FILE" ]] || { echo "No hints.md found in $LAB_DIR" >&2; exit 1; }

awk -v level="$LEVEL" '
  BEGIN { found=0 }
  /^## Level [0-9]+/ {
    if (found) exit
    if ($0 ~ ("^## Level " level "([^0-9]|$)")) { found=1; print; next }
    next
  }
  found { print }
' "$HINTS_FILE" > /tmp/ckne-hint.$$ || true

if [[ -s /tmp/ckne-hint.$$ ]]; then
  cat /tmp/ckne-hint.$$
else
  echo "No hint at level $LEVEL. Available levels:"
  grep '^## Level' "$HINTS_FILE" || echo "  (none defined)"
fi
rm -f /tmp/ckne-hint.$$
