#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

DEEP_DIVE_PATH="${AUTOCOMPLETE_LAB_DEEP_DIVE_SCORECARD:-docs/product/deep-dive-scorecard-2026-05-06.md}"
DEEP_RESEARCH_PATH="${AUTOCOMPLETE_LAB_DEEP_RESEARCH_SCORECARD:-docs/product/deep-research-autocomplete-scorecard-2026-05-07.md}"
APPLE_NATIVE_PATH="${AUTOCOMPLETE_LAB_APPLE_NATIVE_CHECKLIST:-docs/product/apple-native-experience-checklist.md}"
APP_PROOF_PATH="${AUTOCOMPLETE_LAB_APP_PROOF_MATRIX:-docs/product/app-proof-matrix.md}"

ISSUES=0
LIVE_PROMPT_PROOF_ISSUES=0
DEFAULT_CHROME_EDITOR_ISSUES=0
VARIANT_PROOF_ISSUES=0
TYPING_RESTRAINT_ISSUES=0
RELEASE_ARCHITECTURE_ISSUES=0

record_blocker_theme() {
  local file="$1"
  local label="$2"
  local target="$3"

  case "$label" in
    *Codex*|*"Claude Code"*|*"AI chat profile"*|*"Proof status"*)
      LIVE_PROMPT_PROOF_ISSUES=$((LIVE_PROMPT_PROOF_ISSUES + 1))
      return
      ;;
    *"Chrome Monaco"*|*"Chrome ProseMirror"*|*"Browser editor"*|*"editor-like"*|*"real Monaco"*|*"real ProseMirror"*)
      DEFAULT_CHROME_EDITOR_ISSUES=$((DEFAULT_CHROME_EDITOR_ISSUES + 1))
      return
      ;;
    *"Normal typing"*|*"Typing must feel untouched"*|*"Non-annoyance"*|*"Failure restraint"*|*"Failure Restraint"*)
      TYPING_RESTRAINT_ISSUES=$((TYPING_RESTRAINT_ISSUES + 1))
      return
      ;;
    *TextEdit*|*Notes*|*Obsidian*|*Chrome*|*"Claude desktop"*|*"Browser editor"*)
      VARIANT_PROOF_ISSUES=$((VARIANT_PROOF_ISSUES + 1))
      return
      ;;
    *"Overall"*|*"Current implementation score"*|*"Weighted score"*|*"Release readiness"*|*"Architecture"*|*"Evidence and QA loop"*|*"Evidence And QA Loop"*)
      RELEASE_ARCHITECTURE_ISSUES=$((RELEASE_ARCHITECTURE_ISSUES + 1))
      return
      ;;
  esac

  if [[ "$target" == "A" ]]; then
    VARIANT_PROOF_ISSUES=$((VARIANT_PROOF_ISSUES + 1))
    return
  fi

  case "$file" in
    *app-proof-matrix.md|*apple-native-experience-checklist.md|*deep-dive-scorecard-2026-05-06.md)
      VARIANT_PROOF_ISSUES=$((VARIANT_PROOF_ISSUES + 1))
      ;;
    *)
      RELEASE_ARCHITECTURE_ISSUES=$((RELEASE_ARCHITECTURE_ISSUES + 1))
      ;;
  esac
}

require_file() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    echo "missing score target file: $path" >&2
    exit 2
  fi
}

record_issue() {
  local file="$1"
  local label="$2"
  local actual="$3"
  local target="$4"

  printf -- "- %s: %s is %s; target is %s\n" "$file" "$label" "$actual" "$target"
  record_blocker_theme "$file" "$label" "$target"
  ISSUES=$((ISSUES + 1))
}

print_blocker_summary() {
  echo
  echo "Blocking themes"
  if ((LIVE_PROMPT_PROOF_ISSUES > 0)); then
    echo "- Live prompt proof: $LIVE_PROMPT_PROOF_ISSUES issue(s). Finish Codex same-slice no-submit proof and Claude Code terminal-host proof."
  fi
  if ((DEFAULT_CHROME_EDITOR_ISSUES > 0)); then
    echo "- Chrome editor production proof: $DEFAULT_CHROME_EDITOR_ISSUES issue(s). Local real Monaco/ProseMirror caret-quality proof exists; add production variants before target scores can reach 100."
  fi
  if ((VARIANT_PROOF_ISSUES > 0)); then
    echo "- Real-app variant proof: $VARIANT_PROOF_ISSUES issue(s). Add missing Notes, Obsidian, Chrome, Claude desktop, and prompt layout variants."
  fi
  if ((TYPING_RESTRAINT_ISSUES > 0)); then
    echo "- Typing restraint and noise: $TYPING_RESTRAINT_ISSUES issue(s). Keep normal typing untouched and separate key-path failures from AX warning noise."
  fi
  if ((RELEASE_ARCHITECTURE_ISSUES > 0)); then
    echo "- Release and architecture polish: $RELEASE_ARCHITECTURE_ISSUES issue(s). Keep aggregate scores below target until proof gates and shared orchestration gaps close."
  fi
}

check_deep_dive() {
  local path="$1"

  while IFS= read -r line; do
    if [[ "$line" =~ ^Overall:[[:space:]]*([0-9]+(\.[0-9]+)?)/10\.?$ ]]; then
      if [[ "${BASH_REMATCH[1]}" != "10" && "${BASH_REMATCH[1]}" != "10.0" ]]; then
        record_issue "$path" "Overall" "${BASH_REMATCH[1]}/10" "10/10"
      fi
    fi

    if [[ "$line" =~ ^\|[[:space:]]*([^|]+)[[:space:]]*\|[[:space:]]*([0-9]+(\.[0-9]+)?)/10[[:space:]]*\| ]]; then
      local area="${BASH_REMATCH[1]}"
      local rating="${BASH_REMATCH[2]}"
      area="$(printf '%s' "$area" | sed 's/[[:space:]]*$//')"
      if [[ "$area" != "App or surface" && "$rating" != "10" && "$rating" != "10.0" ]]; then
        record_issue "$path" "$area" "$rating/10" "10/10"
      fi
    fi
  done <"$path"
}

check_deep_research() {
  local path="$1"

  while IFS= read -r line; do
    if [[ "$line" =~ ^Current[[:space:]]implementation[[:space:]]score.*\*\*([0-9]+)/100\*\*\.?$ ]]; then
      if [[ "${BASH_REMATCH[1]}" != "100" ]]; then
        record_issue "$path" "Current implementation score" "${BASH_REMATCH[1]}/100" "100/100"
      fi
    fi

    if [[ "$line" =~ ^Proof[[:space:]]status:[[:space:]]\*\*([^*]+)\*\*\.?$ ]]; then
      local status="${BASH_REMATCH[1]}"
      if [[ "$status" != "complete" ]]; then
        record_issue "$path" "Proof status" "$status" "complete"
      fi
    fi
  done <"$path"
}

check_apple_native() {
  local path="$1"
  local section_label=""

  while IFS= read -r line; do
    if [[ "$line" =~ ^##[[:space:]]+(.+)$ ]]; then
      section_label="${BASH_REMATCH[1]}"
      section_label="$(printf '%s' "$section_label" | sed 's/[[:space:]]*$//')"
    fi

    if [[ "$line" =~ ^Overall[[:space:]]Apple-native[[:space:]]feel:[[:space:]]*([0-9]+)/100\.?$ ]]; then
      if [[ "${BASH_REMATCH[1]}" != "100" ]]; then
        record_issue "$path" "Overall Apple-native feel" "${BASH_REMATCH[1]}/100" "100/100"
      fi
    fi

    if [[ "$line" =~ ^Weighted[[:space:]]score:[[:space:]]*([0-9]+)/100\.?$ ]]; then
      if [[ "${BASH_REMATCH[1]}" != "100" ]]; then
        record_issue "$path" "Weighted score" "${BASH_REMATCH[1]}/100" "100/100"
      fi
    fi

    if [[ "$line" =~ ^Current[[:space:]]score:[[:space:]]*([0-9]+)/100\.?$ ]]; then
      if [[ "${BASH_REMATCH[1]}" != "100" ]]; then
        local label="${section_label:-section} current score"
        record_issue "$path" "$label" "${BASH_REMATCH[1]}/100" "100/100"
      fi
    fi

    if [[ "$line" =~ ^\|[[:space:]]*([^|]+)[[:space:]]*\|[[:space:]]*([0-9]+)[[:space:]]*\|[[:space:]]*([0-9]+)[[:space:]]*\|[[:space:]]*([0-9]+)[[:space:]]*\| ]]; then
      local category="${BASH_REMATCH[1]}"
      local current="${BASH_REMATCH[3]}"
      local target="${BASH_REMATCH[4]}"
      category="$(printf '%s' "$category" | sed 's/[[:space:]]*$//')"
      if [[ "$category" != "Category" && "$current" != "$target" ]]; then
        record_issue "$path" "$category" "$current/100" "$target/100"
      fi
    fi
  done <"$path"
}

check_app_proof() {
  local path="$1"

  while IFS= read -r line; do
    if [[ "$line" =~ ^\|[[:space:]]*([^|]+)[[:space:]]*\|[[:space:]]*([A-D][+-]?)[[:space:]]*\| ]]; then
      local surface="${BASH_REMATCH[1]}"
      local grade="${BASH_REMATCH[2]}"
      surface="$(printf '%s' "$surface" | sed 's/[[:space:]]*$//')"
      if [[ "$surface" != "Surface" && "$grade" != "A" ]]; then
        record_issue "$path" "$surface" "$grade" "A"
      fi
    fi
  done <"$path"
}

require_file "$DEEP_DIVE_PATH"
require_file "$DEEP_RESEARCH_PATH"
require_file "$APPLE_NATIVE_PATH"
require_file "$APP_PROOF_PATH"

echo "Score target status"
echo "Deep dive: $DEEP_DIVE_PATH"
echo "Deep research: $DEEP_RESEARCH_PATH"
echo "Apple-native checklist: $APPLE_NATIVE_PATH"
echo "App proof matrix: $APP_PROOF_PATH"
echo

check_deep_dive "$DEEP_DIVE_PATH"
check_deep_research "$DEEP_RESEARCH_PATH"
check_apple_native "$APPLE_NATIVE_PATH"
check_app_proof "$APP_PROOF_PATH"

if ((ISSUES > 0)); then
  print_blocker_summary
  echo
  echo "Score target check failed with $ISSUES issue(s)."
  exit 1
fi

echo "All score targets are complete."
