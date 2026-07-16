#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

REPORT_PATH="${AUTOCOMPLETE_LAB_MANUAL_SMOKE_REPORT:-docs/product/manual-smoke-runs.md}"
MODE="print"
RUN_ALL=0
declare -a SELECTED_TARGETS=()
declare -a CURRENT_PROOFS=()
CURRENT_COMMIT_PROOF=""
CURRENT_APP_PROOF=""
CURRENT_ARCHIVE_PROOF=""
TARGET_STATUS=""
TARGET_STATUS_REASON=""

usage() {
  cat <<'EOF'
Usage: script/manual_proof_refresh.sh [--print|--dry-run|--run] [--target SLUG|--all]
       script/manual_proof_refresh.sh --verify-target SLUG

Prints exact stale/pending proof refresh commands, runs selected recorder
commands, and verifies that the latest proof row matches the current app,
archive, commit, or source-compatible commit fingerprint. By default it prints
only beta-safe target rows. Use --all for proof-only or blocked refresh lanes.

Examples:
  script/manual_proof_refresh.sh --print
  script/manual_proof_refresh.sh --dry-run --target textedit
  script/manual_proof_refresh.sh --run --target textedit
  script/manual_proof_refresh.sh --verify-target textedit
EOF
}

declare -a TARGETS=(
  "textedit|TextEdit|TextEdit|com.apple.TextEdit|default|full|AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh textedit"
  "notes-title|Notes title|Notes|com.apple.Notes|notes-title|full|AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-title --manual-gate"
  "notes-body|Notes body|Notes|com.apple.Notes|notes-body|full|AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-body --manual-gate"
  "notes-checklist|Notes checklist|Notes|com.apple.Notes|notes-checklist|full|AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-checklist --manual-gate"
  "obsidian|Obsidian|Obsidian|md.obsidian|default|full|AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh obsidian --manual-gate"
  "obsidian-theme|Obsidian theme|Obsidian|md.obsidian|obsidian-theme|full|AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh obsidian-theme --manual-gate"
  "obsidian-pane|Obsidian panes|Obsidian|md.obsidian|obsidian-pane|full|AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh obsidian-pane --manual-gate"
  "obsidian-long-note|Obsidian long note|Obsidian|md.obsidian|obsidian-long-note|full|AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh obsidian-long-note --manual-gate"
  "chrome-textarea|Chrome textarea|Chrome|com.google.Chrome|textarea|full|AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh chrome --fixture textarea"
  "chrome-contenteditable|Chrome contenteditable|Chrome|com.google.Chrome|contenteditable|full|AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh chrome --fixture contenteditable"
  "chrome-production-textarea|Chrome production textarea|Chrome|com.google.Chrome|textarea-public|full|AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh chrome --fixture textarea-public"
  "chrome-production-contenteditable|Chrome production contenteditable|Chrome|com.google.Chrome|contenteditable-public|full|AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh chrome --fixture contenteditable-public"
  "chrome-editor-like|Chrome editor-like|Chrome|com.google.Chrome|editor-like|full|AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh chrome --fixture editor-like"
  "chrome-monaco-like|Chrome Monaco-like|Chrome|com.google.Chrome|monaco-like|full|AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh chrome --fixture monaco-like"
  "chrome-prosemirror-like|Chrome ProseMirror-like|Chrome|com.google.Chrome|prosemirror-like|full|AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh chrome --fixture prosemirror-like"
  "chrome-monaco-real|Chrome real Monaco|Chrome|com.google.Chrome|monaco-real|full|AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh chrome --fixture monaco-real"
  "chrome-prosemirror-real|Chrome real ProseMirror|Chrome|com.google.Chrome|prosemirror-real|full|AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh chrome --fixture prosemirror-real"
  "chrome-monaco-real-default|Chrome real Monaco default AX|Chrome|com.google.Chrome|monaco-real-default|full|AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh chrome --fixture monaco-real --chrome-accessibility default"
  "chrome-prosemirror-real-default|Chrome real ProseMirror default AX|Chrome|com.google.Chrome|prosemirror-real-default|full|AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh chrome --fixture prosemirror-real --chrome-accessibility default"
  "chrome-chat-like|Chrome chat-like no-submit|Chrome|com.google.Chrome|chat-like|full|AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh chrome --fixture chat-like"
  "codex|Codex|Codex|com.openai.codex|default|one-word|AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh codex --manual-gate"
  "codex-full-accept|Codex full accept no-submit|Codex|com.openai.codex|full-accept|prompt-full-accept|AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh codex-full-accept --manual-gate"
  "claude-code|Claude Code|Claude Code|com.anthropic.claude-code|default|one-word|AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh claude-code --manual-gate"
  "claude|Claude desktop|Claude|com.anthropic.claudefordesktop|default|one-word|AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh claude --manual-gate"
  "claude-empty|Claude desktop empty composer|Claude|com.anthropic.claudefordesktop|claude-empty|one-word|AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh claude-empty --manual-gate"
  "claude-long|Claude desktop long prompt|Claude|com.anthropic.claudefordesktop|claude-long|one-word|AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh claude-long --manual-gate"
  "claude-wrapped|Claude desktop wrapped prompt|Claude|com.anthropic.claudefordesktop|claude-wrapped|one-word|AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh claude-wrapped --manual-gate"
  "claude-narrow|Claude desktop narrow window|Claude|com.anthropic.claudefordesktop|claude-narrow|one-word|AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh claude-narrow --manual-gate"
  "claude-context|Claude desktop context layout|Claude|com.anthropic.claudefordesktop|claude-context|one-word|AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh claude-context --manual-gate"
  "claude-light|Claude desktop light appearance|Claude|com.anthropic.claudefordesktop|claude-light|one-word|AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh claude-light --manual-gate"
  "claude-dark|Claude desktop dark appearance|Claude|com.anthropic.claudefordesktop|claude-dark|one-word|AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh claude-dark --manual-gate"
)

declare -a BETA_SAFE_TARGETS=(
  "textedit"
  "notes-title"
  "notes-body"
  "notes-checklist"
  "obsidian"
  "obsidian-theme"
  "obsidian-pane"
  "obsidian-long-note"
  "chrome-textarea"
  "chrome-contenteditable"
)

while (($#)); do
  case "$1" in
    --print)
      MODE="print"
      ;;
    --dry-run)
      MODE="dry-run"
      ;;
    --run)
      MODE="run"
      ;;
    --all)
      RUN_ALL=1
      ;;
    --target)
      shift
      if [[ $# -eq 0 ]]; then
        echo "--target needs a slug" >&2
        exit 2
      fi
      SELECTED_TARGETS+=("$1")
      ;;
    --target=*)
      SELECTED_TARGETS+=("${1#--target=}")
      ;;
    --verify-target)
      shift
      if [[ $# -eq 0 ]]; then
        echo "--verify-target needs a slug" >&2
        exit 2
      fi
      MODE="verify"
      SELECTED_TARGETS+=("$1")
      ;;
    --verify-target=*)
      MODE="verify"
      SELECTED_TARGETS+=("${1#--verify-target=}")
      ;;
    -h|--help|help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
  shift
done

collect_current_proofs() {
  CURRENT_PROOFS=()
  CURRENT_COMMIT_PROOF=""
  CURRENT_APP_PROOF=""
  CURRENT_ARCHIVE_PROOF=""

  local commit
  commit="$(git rev-parse --short=12 HEAD 2>/dev/null || true)"
  if [[ -n "$commit" ]]; then
    CURRENT_COMMIT_PROOF="commit:$commit"
    CURRENT_PROOFS+=("$CURRENT_COMMIT_PROOF")
  fi

  local app_binary="${AUTOCOMPLETE_LAB_APP_BINARY:-dist/SteadyType.app/Contents/MacOS/SteadyType}"
  if [[ -s "$app_binary" ]]; then
    local app_sha
    app_sha="$(shasum -a 256 "$app_binary" | awk '{print $1}')"
    if [[ -n "$app_sha" ]]; then
      CURRENT_APP_PROOF="app-sha256:$app_sha"
      CURRENT_PROOFS+=("$CURRENT_APP_PROOF")
    fi
  fi

  local archive_path="${AUTOCOMPLETE_LAB_ARCHIVE_PATH:-dist/smoke-proof/SteadyType.zip}"
  if [[ -s "$archive_path" ]]; then
    local archive_sha
    archive_sha="$(shasum -a 256 "$archive_path" | awk '{print $1}')"
    if [[ -n "$archive_sha" ]]; then
      CURRENT_ARCHIVE_PROOF="archive-sha256:$archive_sha"
      CURRENT_PROOFS+=("$CURRENT_ARCHIVE_PROOF")
    fi
  fi
}

print_current_proofs() {
  collect_current_proofs
  echo "Current proof fingerprints:"
  if ((${#CURRENT_PROOFS[@]} == 0)); then
    echo "- none"
    return
  fi

  local proof
  for proof in "${CURRENT_PROOFS[@]}"; do
    echo "- $proof"
  done
}

target_entry() {
  local slug="$1"
  local entry entry_slug
  for entry in "${TARGETS[@]}"; do
    entry_slug="${entry%%|*}"
    if [[ "$entry_slug" == "$slug" ]]; then
      printf '%s' "$entry"
      return 0
    fi
  done

  return 1
}

validate_selected_targets() {
  local slug
  if ((${#SELECTED_TARGETS[@]} == 0)); then
    return
  fi

  for slug in "${SELECTED_TARGETS[@]}"; do
    if ! target_entry "$slug" >/dev/null; then
      echo "unknown proof target: $slug" >&2
      echo "Use --print to see valid target slugs." >&2
      exit 2
    fi
  done
}

selected_entries() {
  local slug entry
  if (( RUN_ALL == 1 )); then
    printf '%s\n' "${TARGETS[@]}"
    return
  fi

  if ((${#SELECTED_TARGETS[@]} == 0)); then
    local beta_slug
    for entry in "${TARGETS[@]}"; do
      slug="${entry%%|*}"
      for beta_slug in "${BETA_SAFE_TARGETS[@]}"; do
        if [[ "$slug" == "$beta_slug" ]]; then
          printf '%s\n' "$entry"
          break
        fi
      done
    done
    return
  fi

  for slug in "${SELECTED_TARGETS[@]}"; do
    if ! entry="$(target_entry "$slug")"; then
      echo "unknown proof target: $slug" >&2
      echo "Use --print to see valid target slugs." >&2
      exit 2
    fi
    printf '%s\n' "$entry"
  done
}

parse_entry() {
  IFS='|' read -r TARGET_SLUG TARGET_DISPLAY TARGET_REPORT TARGET_BUNDLE TARGET_PROOF TARGET_KIND TARGET_COMMAND <<<"$1"
}

verified_regex_for_kind() {
  case "$1" in
    one-word|prompt-full-accept)
      printf '1'
      ;;
    *)
      printf '[2-9][0-9]*'
      ;;
  esac
}

latest_report_line() {
  local verified_regex
  verified_regex="$(verified_regex_for_kind "$TARGET_KIND")"
  [[ -f "$REPORT_PATH" ]] || return 1

  grep -E "\\| $TARGET_REPORT \\| \`$TARGET_BUNDLE\` \\| \`$TARGET_PROOF\` \\| $verified_regex \\|" "$REPORT_PATH" |
    tail -n 1 ||
    true
}

line_has_current_commit_or_archive() {
  local line="$1"
  classify_current_commit_or_archive "$line"
  if [[ "$TARGET_STATUS" == "current" ]]; then
    return 0
  fi

  echo "$TARGET_STATUS_REASON" >&2
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
  local source_paths_raw="${2:-${AUTOCOMPLETE_LAB_PROOF_SOURCE_PATHS:-Package.swift Package.resolved Sources}}"
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

  local -a source_paths=()
  read -r -a source_paths <<<"$source_paths_raw"
  (( ${#source_paths[@]} > 0 )) || return 1

  git diff --quiet "$proof_commit".."$current_commit" -- "${source_paths[@]}"
}

proof_source_paths_for_target() {
  if [[ -n "${AUTOCOMPLETE_LAB_PROOF_SOURCE_PATHS+x}" ]]; then
    printf '%s' "$AUTOCOMPLETE_LAB_PROOF_SOURCE_PATHS"
    return
  fi

  local paths="Package.swift Package.resolved Sources"
  if [[ "${TARGET_BUNDLE:-}" != "com.anthropic.claude-code" ]]; then
    paths+=" :!Sources/AutocompleteLabResearch/ClaudeCodeTerminalHostProofPolicy.swift"
  fi
  printf '%s' "$paths"
}

classify_current_commit_or_archive() {
  local line="$1"
  TARGET_STATUS="stale"
  TARGET_STATUS_REASON="missing current app/source proof fingerprint"

  if [[ -n "$CURRENT_COMMIT_PROOF" && "$line" == *"$CURRENT_COMMIT_PROOF"* ]]; then
    TARGET_STATUS="current"
    TARGET_STATUS_REASON="current commit fingerprint"
    return 0
  fi

  if [[ -n "$CURRENT_APP_PROOF" && "$line" == *"$CURRENT_APP_PROOF"* ]]; then
    TARGET_STATUS="current"
    TARGET_STATUS_REASON="current app binary fingerprint"
    return 0
  fi

  if [[ -n "$CURRENT_ARCHIVE_PROOF" && "$line" == *"$CURRENT_ARCHIVE_PROOF"* ]]; then
    TARGET_STATUS="current"
    TARGET_STATUS_REASON="current archive fingerprint"
    return 0
  fi

  if line_has_source_compatible_commit_proof "$line" "$(proof_source_paths_for_target)"; then
    TARGET_STATUS="current"
    TARGET_STATUS_REASON="source-compatible commit fingerprint"
    return 0
  fi

  if [[ "$line" == *"commit:"* ]]; then
    if [[ -z "$CURRENT_COMMIT_PROOF" || "$line" != *"$CURRENT_COMMIT_PROOF"* ]]; then
      TARGET_STATUS_REASON="stale commit fingerprint"
      return 0
    fi
  fi

  if [[ "$line" == *"archive-sha256:"* ]]; then
    TARGET_STATUS_REASON="stale archive fingerprint"
    return 0
  fi

  if [[ "$line" == *"app-sha256:"* ]]; then
    TARGET_STATUS_REASON="stale app binary fingerprint"
    return 0
  fi

  return 0
}

classify_entry() {
  local line
  line="$(latest_report_line)"

  if [[ -z "$line" ]]; then
    TARGET_STATUS="pending"
    TARGET_STATUS_REASON="missing proof row"
    return 0
  fi

  if [[ "$TARGET_KIND" == "one-word" && "$line" != *"prompt no-submit confirmed"* ]]; then
    TARGET_STATUS="pending"
    TARGET_STATUS_REASON="missing prompt no-submit confirmation"
    return 0
  fi
  if [[ "$TARGET_KIND" == "prompt-full-accept" && "$line" != *"prompt full-accept no-submit confirmed"* ]]; then
    TARGET_STATUS="pending"
    TARGET_STATUS_REASON="missing prompt full-accept no-submit confirmation"
    return 0
  fi

  classify_current_commit_or_archive "$line"
}

verify_entry() {
  local line
  collect_current_proofs
  line="$(latest_report_line)"

  if [[ -z "$line" ]]; then
    echo "$TARGET_DISPLAY proof is missing from $REPORT_PATH" >&2
    return 1
  fi

  if [[ "$TARGET_KIND" == "one-word" && "$line" != *"prompt no-submit confirmed"* ]]; then
    echo "$TARGET_DISPLAY proof is missing prompt no-submit confirmation" >&2
    return 1
  fi
  if [[ "$TARGET_KIND" == "prompt-full-accept" && "$line" != *"prompt full-accept no-submit confirmed"* ]]; then
    echo "$TARGET_DISPLAY proof is missing prompt full-accept no-submit confirmation" >&2
    return 1
  fi

  if ! line_has_current_commit_or_archive "$line"; then
    echo "$TARGET_DISPLAY proof is not current. Run:" >&2
    echo "$TARGET_COMMAND" >&2
    return 1
  fi

  echo "$TARGET_DISPLAY: current proof recorded"
  echo "$line"
}

print_plan() {
  echo "Manual proof refresh"
  echo
  echo "Default scope: beta-safe rows only. Use --all for proof-only or blocked lanes."
  echo
  print_current_proofs
  echo
  echo "Strict status command:"
  echo "./script/manual_smoke_status.sh --strict"
  echo

  local entry current_count stale_count pending_count needed_count
  current_count=0
  stale_count=0
  pending_count=0
  needed_count=0

  if (( RUN_ALL == 1 )); then
    echo "All proof target status:"
  elif ((${#SELECTED_TARGETS[@]} == 0)); then
    echo "Beta-safe target status:"
  else
    echo "Selected target status:"
  fi
  while IFS= read -r entry; do
    [[ -n "$entry" ]] || continue
    parse_entry "$entry"
    classify_entry
    case "$TARGET_STATUS" in
      current)
        current_count=$((current_count + 1))
        ;;
      stale)
        stale_count=$((stale_count + 1))
        needed_count=$((needed_count + 1))
        ;;
      pending)
        pending_count=$((pending_count + 1))
        needed_count=$((needed_count + 1))
        ;;
    esac
    printf -- '- %s: %s (%s)\n' "$TARGET_DISPLAY" "$TARGET_STATUS" "$TARGET_STATUS_REASON"
  done < <(selected_entries)

  echo
  printf 'Summary: %d current, %d stale, %d pending, %d need refresh.\n' \
    "$current_count" "$stale_count" "$pending_count" "$needed_count"
  echo
  echo "Exact next commands for stale or pending rows:"

  local entry
  while IFS= read -r entry; do
    [[ -n "$entry" ]] || continue
    parse_entry "$entry"
    classify_entry
    [[ "$TARGET_STATUS" != "current" ]] || continue
    echo
    echo "# $TARGET_SLUG - $TARGET_DISPLAY"
    echo "# status: $TARGET_STATUS - $TARGET_STATUS_REASON"
    echo "$TARGET_COMMAND"
    echo "script/manual_proof_refresh.sh --verify-target $TARGET_SLUG"
  done < <(selected_entries)
}

if [[ "$MODE" == "print" ]]; then
  validate_selected_targets
  print_plan
  exit 0
fi

validate_selected_targets

if [[ "$MODE" == "run" && ${#SELECTED_TARGETS[@]} -eq 0 && "$RUN_ALL" != "1" ]]; then
  echo "--run needs --target SLUG or --all" >&2
  echo "Use --print to see valid target slugs." >&2
  exit 2
fi

if [[ "$MODE" == "dry-run" ]]; then
  local_index=1
  while IFS= read -r entry; do
    [[ -n "$entry" ]] || continue
    parse_entry "$entry"
    printf 'would run %d: %s\n%s\n\n' "$local_index" "$TARGET_DISPLAY" "$TARGET_COMMAND"
    local_index=$((local_index + 1))
  done < <(selected_entries)
  exit 0
fi

if [[ "$MODE" == "verify" ]]; then
  if ((${#SELECTED_TARGETS[@]} != 1)); then
    echo "--verify-target checks exactly one target" >&2
    exit 2
  fi

  parse_entry "$(target_entry "${SELECTED_TARGETS[0]}")"
  verify_entry
  exit $?
fi

while IFS= read -r entry; do
  [[ -n "$entry" ]] || continue
  parse_entry "$entry"
  echo
  echo "== Refreshing $TARGET_DISPLAY =="
  echo "$TARGET_COMMAND"
  bash -c "$TARGET_COMMAND"
  verify_entry
done < <(selected_entries)
