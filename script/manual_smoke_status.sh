#!/usr/bin/env bash
set -euo pipefail

REPORT_PATH="${AUTOCOMPLETE_LAB_MANUAL_SMOKE_REPORT:-docs/product/manual-smoke-runs.md}"
SCORECARD_PATH="${AUTOCOMPLETE_LAB_SCORECARD:-docs/product/deep-dive-scorecard-2026-05-06.md}"
MODE=""
REQUIRE_ALL=0
VISUAL_PROOF_GAPS=0
STRICT_VISUAL_EVIDENCE_FAILED=0

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
It separates insertion proof from screenshot-backed visual placement proof so
real-app visual gaps stay visible after insertion passes.
Notes title, body, and checklist are separate proof targets.

Use --require-all or --strict when you want the command to fail until every
target app has a recorded pass and every visual audit row has screenshot-backed
proof, valid screenshot evidence, and honest visual score labels.
EOF
  exit 0
fi

declare -a APPS=(
  "TextEdit|TextEdit|com.apple.TextEdit|full|default|script/manual_smoke_session.sh textedit --visual"
  "Notes title|Notes|com.apple.Notes|full|notes-title|script/manual_smoke_session.sh notes-title --visual"
  "Notes body|Notes|com.apple.Notes|full|notes-body|script/manual_smoke_session.sh notes-body --visual"
  "Notes checklist|Notes|com.apple.Notes|full|notes-checklist|script/manual_smoke_session.sh notes-checklist --visual"
  "Obsidian|Obsidian|md.obsidian|full|default|script/manual_smoke_session.sh obsidian --visual"
  "Chrome textarea|Chrome|com.google.Chrome|full|textarea|script/manual_smoke_session.sh chrome --visual"
  "Chrome contenteditable|Chrome|com.google.Chrome|full|contenteditable|AUTOCOMPLETE_LAB_CHROME_FIXTURE=contenteditable script/manual_smoke_session.sh chrome --visual"
  "Chrome editor-like|Chrome|com.google.Chrome|full|editor-like|AUTOCOMPLETE_LAB_CHROME_FIXTURE=editor-like script/manual_smoke_session.sh chrome --visual"
  "Chrome Monaco-like|Chrome|com.google.Chrome|full|monaco-like|AUTOCOMPLETE_LAB_CHROME_FIXTURE=monaco-like script/manual_smoke_session.sh chrome --visual"
  "Chrome ProseMirror-like|Chrome|com.google.Chrome|full|prosemirror-like|AUTOCOMPLETE_LAB_CHROME_FIXTURE=prosemirror-like script/manual_smoke_session.sh chrome --visual"
  "Chrome chat-like no-submit|Chrome|com.google.Chrome|full|chat-like|AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh chrome --fixture chat-like"
  "Codex|Codex|com.openai.codex|one-word|default|script/manual_smoke_session.sh codex --visual"
  "Claude Code|Claude Code|com.anthropic.claude-code|one-word|default|script/manual_smoke_session.sh claude-code --visual"
  "Claude desktop|Claude|com.anthropic.claudefordesktop|one-word|default|script/manual_smoke_session.sh claude --visual"
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
  local saw_area_header=0
  local in_area_table=0
  local line area rating why score
  while IFS= read -r line; do
    if [[ "$line" =~ ^##[[:space:]]+Area[[:space:]]+Ratings ]]; then
      saw_area_header=1
      in_area_table=1
      continue
    fi

    if (( saw_area_header == 1 && in_area_table == 1 )) && [[ "$line" =~ ^##[[:space:]]+ ]]; then
      break
    fi

    if (( saw_area_header == 1 && in_area_table == 0 )); then
      continue
    fi

    [[ "$line" == \|* ]] || continue
    [[ "$line" != *"| Area |"* ]] || continue
    [[ "$line" != *"| --- |"* ]] || continue

    IFS='|' read -r _ area rating why _ <<<"$line"
    area="$(trim "$area")"
    rating="$(trim "$rating")"
    why="$(trim "$why")"

    if [[ "$rating" =~ ^([0-9]+([.][0-9]+)?)/10$ ]]; then
      score="${BASH_REMATCH[1]}"
      if awk "BEGIN { exit !($score < 10) }"; then
        echo "- $area: $rating - $why"
        found=1
      fi
    fi
  done <"$SCORECARD_PATH"

  if (( found == 0 )); then
    echo "- none"
  fi
}

print_visual_audit_status() {
  echo
  if [[ ! -f "$SCORECARD_PATH" ]]; then
    echo "Screenshot proof status: no scorecard found ($SCORECARD_PATH)"
    return
  fi

  echo "Screenshot proof status: $SCORECARD_PATH"
  echo "Screenshot proof only counts rows whose Evidence cell links a screenshot."

  local in_visual_table=0
  local found=0
  local missing=0
  local line surface grade evidence good work link
  local png_link_regex='visual-placement-screenshots/[^)]*[.]png'
  declare -a pending_visuals=()

  while IFS= read -r line; do
    if [[ "$line" =~ ^##[[:space:]]+Visual[[:space:]] ]]; then
      in_visual_table=1
      continue
    fi

    if (( in_visual_table == 1 )) && [[ "$line" =~ ^##[[:space:]]+ ]]; then
      break
    fi

    (( in_visual_table == 1 )) || continue
    [[ "$line" == \|* ]] || continue
    [[ "$line" != *"| App or surface |"* ]] || continue
    [[ "$line" != *"| --- |"* ]] || continue

    IFS='|' read -r _ surface grade evidence good work _ <<<"$line"
    surface="$(trim "$surface")"
    evidence="$(trim "$evidence")"
    work="$(trim "$work")"

    [[ -n "$surface" ]] || continue
    found=1

    if [[ "$evidence" =~ $png_link_regex ]]; then
      link="${BASH_REMATCH[0]}"
      echo "- $surface: screenshot-backed ($link)"
    else
      echo "- $surface: pending screenshot proof - $evidence"
      if [[ -n "$work" ]]; then
        echo "  next: $work"
      fi
      missing=$((missing + 1))
      pending_visuals+=("$surface")
    fi
  done <"$SCORECARD_PATH"

  if (( found == 0 )); then
    echo "- no visual placement audit table found"
    return
  fi

  if (( missing > 0 )); then
    echo
    echo "Screenshot proof gaps:"
    for surface in "${pending_visuals[@]}"; do
      echo "- $surface"
    done
    echo
    echo "$missing surface(s) still need screenshot-backed visual proof."
  else
    echo
    echo "All visual placement rows are screenshot-backed."
  fi

  VISUAL_PROOF_GAPS="$missing"
}

run_strict_visual_evidence_gate() {
  if (( REQUIRE_ALL != 1 )); then
    return 0
  fi

  echo
  echo "Strict visual evidence gate:"
  if script/check_visual_placement_evidence.sh --require-all; then
    echo "Strict visual evidence gate passed."
  else
    STRICT_VISUAL_EVIDENCE_FAILED=1
  fi
}

if [[ ! -f "$REPORT_PATH" ]]; then
  echo "Insertion proof status: no report yet ($REPORT_PATH)"
else
  echo "Insertion proof status: $REPORT_PATH"
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
  rest="${rest#*|}"
  proof_label="${rest%%|*}"
  rest="${rest#*|}"
  run_hint="${rest:-script/manual_smoke_session.sh $report_name}"
  required_verified_regex='[2-9][0-9]*'
  pass_suffix=""
  if [[ "$proof_mode" == "one-word" ]]; then
    required_verified_regex='[1-9][0-9]*'
    pass_suffix=" (one-word profile)"
  fi
  limited_reason="needs full accept proof"
  if [[ "$proof_mode" == "one-word" ]]; then
    limited_reason="needs one-word no-submit proof"
  fi

  if [[ -f "$REPORT_PATH" ]] &&
    grep -E "\\| $report_name \\| \`$bundle_id\` \\| \`$proof_label\` \\| $required_verified_regex \\|" "$REPORT_PATH" >/dev/null; then
    echo "- $display_name: passed$pass_suffix"
  elif [[ "$proof_label" == "default" ]] &&
    [[ -f "$REPORT_PATH" ]] &&
    grep -E "\\| $report_name \\| \`$bundle_id\` \\| $required_verified_regex \\|" "$REPORT_PATH" >/dev/null; then
    echo "- $display_name: passed$pass_suffix"
  elif [[ -f "$REPORT_PATH" ]] &&
    grep -E "\\| $report_name \\| \`$bundle_id\` \\| (\`$proof_label\` \\| )?0 \\| \`detached-suppressed\` \\|" "$REPORT_PATH" >/dev/null; then
    echo "- $display_name: limited pass ($limited_reason; run $run_hint)"
    missing=$((missing + 1))
    pending_apps+=("$display_name - $run_hint")
  else
    echo "- $display_name: pending (run $run_hint)"
    missing=$((missing + 1))
    pending_apps+=("$display_name - $run_hint")
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

print_visual_audit_status
print_scorecard_gaps
run_strict_visual_evidence_gate

if (( REQUIRE_ALL == 1 && (missing > 0 || VISUAL_PROOF_GAPS > 0 || STRICT_VISUAL_EVIDENCE_FAILED > 0) )); then
  exit 1
fi
