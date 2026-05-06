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
at least one recorded pass with two or more verified accepts.
EOF
  exit 0
fi

if [[ -n "$MODE" && "$MODE" != "--require-all" ]]; then
  echo "unknown option: $MODE" >&2
  exit 2
fi

declare -a APPS=(
  "TextEdit|com.apple.TextEdit|full"
  "Notes|com.apple.Notes|full"
  "Obsidian|md.obsidian|limited"
  "Chrome|com.google.Chrome|full"
  "Codex|com.openai.codex|full"
  "Claude Code|com.anthropic.claude-code|full"
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
  proof_mode="${app_entry##*|}"

  if [[ "$proof_mode" == "limited" ]] &&
    [[ -f "$REPORT_PATH" ]] &&
    grep -E "\\| $display_name \\| \`$bundle_id\` \\| 0 \\| \`detached-suppressed\` \\|" "$REPORT_PATH" >/dev/null; then
    echo "- $display_name: limited pass"
  elif [[ -f "$REPORT_PATH" ]] &&
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

  if [[ "$MODE" == "--require-all" ]]; then
    exit 1
  fi
fi
