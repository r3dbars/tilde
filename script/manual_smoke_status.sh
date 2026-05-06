#!/usr/bin/env bash
set -euo pipefail

REPORT_PATH="${AUTOCOMPLETE_LAB_MANUAL_SMOKE_REPORT:-docs/product/manual-smoke-runs.md}"
SCORECARD_PATH="${AUTOCOMPLETE_LAB_SCORECARD:-docs/product/deep-dive-scorecard-2026-05-06.md}"
MODE=""
REQUIRE_ALL=0

for arg in "$@"; do
  case "$arg" in
    -h | --help)
      MODE="help"
      ;;
    --require-all | --strict)
      REQUIRE_ALL=1
      ;;
    *)
      echo "unknown option: $arg" >&2
      exit 2
      ;;
  esac
done

if [[ "$MODE" == "help" ]]; then
  cat <<'EOF'
Usage: script/manual_smoke_status.sh [--require-all|--strict]

Shows which target apps have real manual smoke proof in
docs/product/manual-smoke-runs.md and lists remaining sub-10 scorecard gaps.

Use --require-all or --strict when you want the command to fail until every
target app has at least one recorded pass with two or more verified accepts.
EOF
  exit 0
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
  "Claude desktop|Claude|com.anthropic.claudefordesktop|full|default"
)

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

print_scorecard_gaps() {
  echo
  if [[ ! -f "$SCORECARD_PATH" ]]; then
    echo "Remaining non-10 scorecard gaps: no scorecard found ($SCORECARD_PATH)"
    return
  fi

  echo "Remaining non-10 scorecard gaps: $SCORECARD_PATH"

  local found=0
  local line area rating why score
  while IFS= read -r line; do
    [[ "$line" == \|* ]] || continue
    [[ "$line" != *"| Area |"* ]] || continue
    [[ "$line" != *"| --- |"* ]] || continue

    IFS='|' read -r _ area rating why _ <<<"$line"
    area="$(trim "$area")"
    rating="$(trim "$rating")"
    why="$(trim "$why")"

    if [[ "$rating" =~ ^([0-9]+)/10$ ]]; then
      score="${BASH_REMATCH[1]}"
      if (( score < 10 )); then
        echo "- $area: $rating - $why"
        found=1
      fi
    fi
  done <"$SCORECARD_PATH"

  if (( found == 0 )); then
    echo "- none"
  fi
}

if [[ ! -f "$REPORT_PATH" ]]; then
  echo "Manual smoke status: no report yet ($REPORT_PATH)"
else
  echo "Manual smoke status: $REPORT_PATH"
fi

missing=0
declare -a pending_apps=()

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
    pending_apps+=("$display_name")
  fi
done

if (( missing > 0 )); then
  echo
  echo "Required proof gaps:"
  for app_name in "${pending_apps[@]}"; do
    echo "- $app_name"
  done

  echo
  echo "$missing target app pass(es) still need real manual smoke proof."
else
  echo
  echo "All required target proofs are covered."
fi

print_scorecard_gaps

if (( missing > 0 && REQUIRE_ALL == 1 )); then
  exit 1
fi
