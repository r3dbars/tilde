#!/usr/bin/env bash
set -euo pipefail

REPORT_PATH="${AUTOCOMPLETE_LAB_MANUAL_SMOKE_REPORT:-docs/product/manual-smoke-runs.md}"
MODE="${1:-}"

if [[ "$MODE" == "-h" || "$MODE" == "--help" ]]; then
  cat <<'EOF'
Usage: script/manual_smoke_status.sh [--require-all]

Shows which target apps have real manual smoke proof in
docs/product/manual-smoke-runs.md.

Use --require-all when you want the command to fail until every target app has
recorded proof. Supported apps need two or more verified accepts. Diagnostics
and unsupported apps need recorded blocking proof.
EOF
  exit 0
fi

if [[ -n "$MODE" && "$MODE" != "--require-all" ]]; then
  echo "unknown option: $MODE" >&2
  exit 2
fi

declare -a APPS=(
  "TextEdit|com.apple.TextEdit|full|passed"
  "Notes|com.apple.Notes|full|passed"
  "Obsidian|md.obsidian|limited|limited pass"
  "Chrome|com.google.Chrome|full|passed"
  "Codex|com.openai.codex|full|passed"
  "Mail|com.apple.mail|diagnostics|diagnostics-only blocked"
  "Safari|com.apple.Safari|diagnostics|diagnostics-only blocked"
  "Slack|com.tinyspeck.slackmacgap|diagnostics|diagnostics-only blocked"
  "VS Code|com.microsoft.VSCode|diagnostics|diagnostics-only blocked"
  "Cursor|com.todesktop.230313mzl4w4u92|diagnostics|diagnostics-only blocked"
  "Atlas|com.openai.atlas|unsupported|unsupported blocked"
  "Terminal|com.apple.Terminal|unsupported|unsupported blocked"
  "1Password|com.1password.1password|unsupported|unsupported blocked"
)

if [[ ! -f "$REPORT_PATH" ]]; then
  echo "Manual smoke status: no report yet ($REPORT_PATH)"
else
  echo "Manual smoke status: $REPORT_PATH"
fi

missing=0

for app_entry in "${APPS[@]}"; do
  display_name="${app_entry%%|*}"
  rest="${app_entry#*|}"
  bundle_id="${rest%%|*}"
  rest="${rest#*|}"
  proof_mode="${rest%%|*}"
  passed_label="${app_entry##*|}"

  if [[ "$proof_mode" == "limited" ]] &&
    [[ -f "$REPORT_PATH" ]] &&
    grep -E "\\| $display_name \\| \`$bundle_id\` \\| 0 \\| \`detached-suppressed\` \\|" "$REPORT_PATH" >/dev/null; then
    echo "- $display_name: $passed_label"
  elif [[ "$proof_mode" == "diagnostics" ]] &&
    [[ -f "$REPORT_PATH" ]] &&
    grep -F "| $display_name | \`$bundle_id\` | 0 | \`diagnostics-only-blocked\` |" "$REPORT_PATH" >/dev/null; then
    echo "- $display_name: $passed_label"
  elif [[ "$proof_mode" == "unsupported" ]] &&
    [[ -f "$REPORT_PATH" ]] &&
    grep -F "| $display_name | \`$bundle_id\` | 0 | \`unsupported-blocked\` |" "$REPORT_PATH" >/dev/null; then
    echo "- $display_name: $passed_label"
  elif [[ -f "$REPORT_PATH" ]] &&
    grep -E "\\| $display_name \\| \`$bundle_id\` \\| [2-9][0-9]* \\|" "$REPORT_PATH" >/dev/null; then
    echo "- $display_name: $passed_label"
  else
    echo "- $display_name: pending"
    missing=$((missing + 1))
  fi
done

if (( missing > 0 )); then
  echo
  echo "$missing target app pass(es) still need real manual smoke proof."

  if [[ "$MODE" == "--require-all" ]]; then
    exit 1
  fi
fi
