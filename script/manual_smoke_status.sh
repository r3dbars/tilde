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
Obsidian default, theme, pane, and long-note lanes are separate proof targets.

Use --require-all or --strict when you want the command to fail until every
target app has a recorded pass and every visual audit row has screenshot-backed
proof, valid screenshot evidence, and honest visual score labels.
EOF
  exit 0
fi

declare -a APPS=(
  "TextEdit|TextEdit|com.apple.TextEdit|full|default|script/manual_smoke_session.sh textedit --visual"
  "Notes title|Notes|com.apple.Notes|full|notes-title|AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-title --manual-gate"
  "Notes body|Notes|com.apple.Notes|full|notes-body|AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-body --manual-gate"
  "Notes checklist|Notes|com.apple.Notes|full|notes-checklist|AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-checklist --manual-gate"
  "Obsidian|Obsidian|md.obsidian|full|default|script/manual_smoke_session.sh obsidian --visual"
  "Obsidian theme|Obsidian|md.obsidian|full|obsidian-theme|AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh obsidian-theme --manual-gate"
  "Obsidian panes|Obsidian|md.obsidian|full|obsidian-pane|AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh obsidian-pane --manual-gate"
  "Obsidian long note|Obsidian|md.obsidian|full|obsidian-long-note|AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh obsidian-long-note --manual-gate"
  "Chrome textarea|Chrome|com.google.Chrome|full|textarea|script/manual_smoke_session.sh chrome --visual"
  "Chrome contenteditable|Chrome|com.google.Chrome|full|contenteditable|AUTOCOMPLETE_LAB_CHROME_FIXTURE=contenteditable script/manual_smoke_session.sh chrome --visual"
  "Chrome production textarea|Chrome|com.google.Chrome|full|textarea-public|AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh chrome --fixture textarea-public"
  "Chrome production contenteditable|Chrome|com.google.Chrome|full|contenteditable-public|AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh chrome --fixture contenteditable-public"
  "Chrome editor-like|Chrome|com.google.Chrome|full|editor-like|AUTOCOMPLETE_LAB_CHROME_FIXTURE=editor-like script/manual_smoke_session.sh chrome --visual"
  "Chrome Monaco-like|Chrome|com.google.Chrome|full|monaco-like|AUTOCOMPLETE_LAB_CHROME_FIXTURE=monaco-like script/manual_smoke_session.sh chrome --visual"
  "Chrome ProseMirror-like|Chrome|com.google.Chrome|full|prosemirror-like|AUTOCOMPLETE_LAB_CHROME_FIXTURE=prosemirror-like script/manual_smoke_session.sh chrome --visual"
  "Chrome real Monaco|Chrome|com.google.Chrome|full|monaco-real|AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh chrome --fixture monaco-real"
  "Chrome real ProseMirror|Chrome|com.google.Chrome|full|prosemirror-real|AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh chrome --fixture prosemirror-real"
  "Chrome real Monaco default AX|Chrome|com.google.Chrome|full|monaco-real-default|AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh chrome --fixture monaco-real --chrome-accessibility default"
  "Chrome real ProseMirror default AX|Chrome|com.google.Chrome|full|prosemirror-real-default|AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh chrome --fixture prosemirror-real --chrome-accessibility default"
  "Chrome chat-like no-submit|Chrome|com.google.Chrome|full|chat-like|AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh chrome --fixture chat-like"
  "Codex|Codex|com.openai.codex|one-word|default|AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh codex --manual-gate"
  "Claude Code|Claude Code|com.anthropic.claude-code|one-word|default|AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh claude-code --manual-gate"
  "Claude desktop|Claude|com.anthropic.claudefordesktop|one-word|default|AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh claude --manual-gate"
  "Claude desktop empty composer|Claude|com.anthropic.claudefordesktop|one-word|claude-empty|AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh claude-empty --manual-gate"
  "Claude desktop long prompt|Claude|com.anthropic.claudefordesktop|one-word|claude-long|AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh claude-long --manual-gate"
  "Claude desktop wrapped prompt|Claude|com.anthropic.claudefordesktop|one-word|claude-wrapped|AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh claude-wrapped --manual-gate"
  "Claude desktop narrow window|Claude|com.anthropic.claudefordesktop|one-word|claude-narrow|AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh claude-narrow --manual-gate"
  "Claude desktop context layout|Claude|com.anthropic.claudefordesktop|one-word|claude-context|AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh claude-context --manual-gate"
  "Claude desktop light appearance|Claude|com.anthropic.claudefordesktop|one-word|claude-light|AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh claude-light --manual-gate"
  "Claude desktop dark appearance|Claude|com.anthropic.claudefordesktop|one-word|claude-dark|AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh claude-dark --manual-gate"
)

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

declare -a CURRENT_BUILD_PROOFS=()
CURRENT_COMMIT_PROOF=""
CURRENT_APP_PROOF=""
CURRENT_ARCHIVE_PROOF=""

collect_current_build_proofs() {
  if [[ -n "${AUTOCOMPLETE_LAB_SMOKE_BUILD_PROOF:-}" ]]; then
    CURRENT_BUILD_PROOFS+=("$AUTOCOMPLETE_LAB_SMOKE_BUILD_PROOF")
  fi

  local commit
  commit="$(git rev-parse --short=12 HEAD 2>/dev/null || true)"
  if [[ -n "$commit" ]]; then
    CURRENT_COMMIT_PROOF="commit:$commit"
    CURRENT_BUILD_PROOFS+=("$CURRENT_COMMIT_PROOF")
  fi

  local app_binary="${AUTOCOMPLETE_LAB_APP_BINARY:-dist/SteadyType.app/Contents/MacOS/SteadyType}"
  if [[ -s "$app_binary" ]]; then
    local app_sha
    app_sha="$(shasum -a 256 "$app_binary" | awk '{print $1}')"
    if [[ -n "$app_sha" ]]; then
      CURRENT_APP_PROOF="app-sha256:$app_sha"
      CURRENT_BUILD_PROOFS+=("$CURRENT_APP_PROOF")
    fi
  fi

  local archive_path="${AUTOCOMPLETE_LAB_ARCHIVE_PATH:-dist/SteadyType.zip}"
  if [[ -s "$archive_path" ]]; then
    local archive_sha
    archive_sha="$(shasum -a 256 "$archive_path" | awk '{print $1}')"
    if [[ -n "$archive_sha" ]]; then
      CURRENT_ARCHIVE_PROOF="archive-sha256:$archive_sha"
      CURRENT_BUILD_PROOFS+=("$CURRENT_ARCHIVE_PROOF")
    fi
  fi
}

current_build_proof_summary() {
  if (( ${#CURRENT_BUILD_PROOFS[@]} == 0 )); then
    printf 'none'
    return
  fi

  local IFS=', '
  printf '%s' "${CURRENT_BUILD_PROOFS[*]}"
}

line_has_current_build_proof() {
  local line="$1"

  if [[ "$line" == *"archive-sha256:"* ]]; then
    if [[ -n "$CURRENT_ARCHIVE_PROOF" && "$line" == *"$CURRENT_ARCHIVE_PROOF"* ]]; then
      return 0
    fi
  fi

  if [[ -n "$CURRENT_APP_PROOF" && "$line" == *"$CURRENT_APP_PROOF"* ]]; then
    return 0
  fi

  if line_has_source_compatible_commit_proof "$line"; then
    return 0
  fi

  if [[ "$line" == *"commit:"* || "$line" == *"archive-sha256:"* || "$line" == *"app-sha256:"* ]]; then
    return 1
  fi

  if [[ -n "$CURRENT_ARCHIVE_PROOF" && "$line" == *"$CURRENT_ARCHIVE_PROOF"* ]]; then
    return 0
  fi

  return 1
}

line_commit_proof_token() {
  local line="$1"

  if [[ "$line" =~ commit:([0-9a-fA-F]{7,40}) ]]; then
    printf '%s' "${BASH_REMATCH[1]}"
  fi
}

line_has_source_compatible_commit_proof() {
  local line="$1"
  local proof_token
  proof_token="$(line_commit_proof_token "$line")"
  [[ -n "$proof_token" ]] || return 1

  local proof_commit
  proof_commit="$(git rev-parse --verify --quiet "$proof_token^{commit}" 2>/dev/null || true)"
  [[ -n "$proof_commit" ]] || return 1

  local current_commit
  current_commit="$(git rev-parse --verify --quiet HEAD^{commit} 2>/dev/null || true)"
  [[ -n "$current_commit" ]] || return 1

  if [[ "$proof_commit" == "$current_commit" ]]; then
    return 0
  fi

  # Proof rows should go stale when the app/runtime source changes, not when the
  # proof driver gets safer for a different lane and app behavior is unchanged.
  local source_paths_raw="${AUTOCOMPLETE_LAB_PROOF_SOURCE_PATHS:-Package.swift Package.resolved Sources}"
  local -a source_paths=()
  read -r -a source_paths <<<"$source_paths_raw"
  (( ${#source_paths[@]} > 0 )) || return 1

  git diff --quiet "$proof_commit".."$current_commit" -- "${source_paths[@]}"
}

matching_report_line() {
  local report_name="$1"
  local bundle_id="$2"
  local proof_label="$3"
  local required_verified_regex="$4"

  [[ -f "$REPORT_PATH" ]] || return 0

  local line
  line="$(
    grep -E "\\| $report_name \\| \`$bundle_id\` \\| \`$proof_label\` \\| $required_verified_regex \\|" "$REPORT_PATH" |
      tail -n 1 ||
      true
  )"

  if [[ -z "$line" && "$proof_label" == "default" ]]; then
    line="$(
      grep -E "\\| $report_name \\| \`$bundle_id\` \\| $required_verified_regex \\|" "$REPORT_PATH" |
        tail -n 1 ||
        true
    )"
  fi

  printf '%s' "$line"
}

matching_limited_report_line() {
  local report_name="$1"
  local bundle_id="$2"
  local proof_label="$3"

  [[ -f "$REPORT_PATH" ]] || return 0

  grep -E "\\| $report_name \\| \`$bundle_id\` \\| (\`$proof_label\` \\| )?0 \\| \`detached-suppressed\` \\|" "$REPORT_PATH" |
    tail -n 1 ||
    true
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
collect_current_build_proofs
echo "Current build proof: $(current_build_proof_summary)"

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

  if [[ "$proof_mode" == "blocked" ]]; then
    echo "- $display_name: pending ($run_hint)"
    missing=$((missing + 1))
    pending_apps+=("$display_name - $run_hint")
    continue
  fi

  required_verified_regex='[2-9][0-9]*'
  pass_suffix=""
  if [[ "$proof_mode" == "one-word" ]]; then
    required_verified_regex='1'
    pass_suffix=" (one-word no-submit profile)"
  fi
  limited_reason="needs full accept proof"
  if [[ "$proof_mode" == "one-word" ]]; then
    limited_reason="needs one-word no-submit proof"
  fi

  pass_line="$(matching_report_line "$report_name" "$bundle_id" "$proof_label" "$required_verified_regex")"
  limited_line="$(matching_limited_report_line "$report_name" "$bundle_id" "$proof_label")"

  if [[ "$proof_mode" == "one-word" && -n "$pass_line" ]] &&
    ! grep -F "prompt no-submit confirmed" <<<"$pass_line" >/dev/null; then
    pass_line=""
  fi

  if [[ -n "$pass_line" ]]; then
    if line_has_current_build_proof "$pass_line"; then
      echo "- $display_name: passed$pass_suffix"
    else
      echo "- $display_name: stale pass (needs current commit/archive proof; run $run_hint)"
      missing=$((missing + 1))
      pending_apps+=("$display_name - $run_hint")
    fi
  elif [[ -n "$limited_line" ]]; then
    echo "- $display_name: limited pass ($limited_reason; run $run_hint)"
    missing=$((missing + 1))
    pending_apps+=("$display_name - $run_hint")
  else
    if [[ "$run_hint" == terminal-host* ]]; then
      echo "- $display_name: pending ($run_hint)"
    else
      echo "- $display_name: pending (run $run_hint)"
    fi
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
