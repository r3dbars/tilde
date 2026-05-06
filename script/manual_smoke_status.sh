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
  "TextEdit|TextEdit|com.apple.TextEdit|full|default"
  "Notes|Notes|com.apple.Notes|full|default"
  "Obsidian|Obsidian|md.obsidian|limited|default"
  "Chrome textarea|Chrome|com.google.Chrome|full|textarea"
  "Chrome contenteditable|Chrome|com.google.Chrome|full|contenteditable"
  "Chrome editor-like|Chrome|com.google.Chrome|full|editor-like"
  "Chrome Monaco-like|Chrome|com.google.Chrome|full|monaco-like"
  "Chrome ProseMirror-like|Chrome|com.google.Chrome|full|prosemirror-like"
  "Codex|Codex|com.openai.codex|full|default"
  "Claude Code|Claude Code|com.anthropic.claude-code|full|default"
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
  report_name="${rest%%|*}"
  rest="${rest#*|}"
  bundle_id="${rest%%|*}"
  rest="${rest#*|}"
  proof_mode="${rest%%|*}"
  proof_label="${app_entry##*|}"

  if [[ "$proof_mode" == "limited" ]] &&
    [[ -f "$REPORT_PATH" ]] &&
    grep -E "\\| $report_name \\| \`$bundle_id\` \\| (\`$proof_label\` \\| )?0 \\| \`detached-suppressed\` \\|" "$REPORT_PATH" >/dev/null; then
    echo "- $display_name: limited pass"
  elif [[ -f "$REPORT_PATH" ]] &&
    grep -E "\\| $report_name \\| \`$bundle_id\` \\| \`$proof_label\` \\| [2-9][0-9]* \\|" "$REPORT_PATH" >/dev/null; then
    echo "- $display_name: passed"
  elif [[ "$proof_label" == "default" ]] &&
    [[ -f "$REPORT_PATH" ]] &&
    grep -E "\\| $report_name \\| \`$bundle_id\` \\| [2-9][0-9]* \\|" "$REPORT_PATH" >/dev/null; then
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
