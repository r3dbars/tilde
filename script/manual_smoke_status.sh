#!/usr/bin/env bash
set -euo pipefail

REPORT_PATH="${AUTOCOMPLETE_LAB_MANUAL_SMOKE_REPORT:-docs/product/manual-smoke-runs.md}"

declare -a APPS=(
  "TextEdit|com.apple.TextEdit"
  "Notes|com.apple.Notes"
  "Obsidian|md.obsidian"
  "Chrome|com.google.Chrome"
)

if [[ ! -f "$REPORT_PATH" ]]; then
  echo "Manual smoke status: no report yet ($REPORT_PATH)"
else
  echo "Manual smoke status: $REPORT_PATH"
fi

missing=0

for app_entry in "${APPS[@]}"; do
  display_name="${app_entry%%|*}"
  bundle_id="${app_entry##*|}"

  if [[ -f "$REPORT_PATH" ]] &&
    grep -E "\\| $display_name \\| \`$bundle_id\` \\| [2-9][0-9]* \\|" "$REPORT_PATH" >/dev/null; then
    echo "- $display_name: passed"
  else
    echo "- $display_name: pending"
    missing=$((missing + 1))
  fi
done

if (( missing > 0 )); then
  echo
  echo "$missing target app pass(es) still need real manual smoke proof."
fi

