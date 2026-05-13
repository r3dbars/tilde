#!/usr/bin/env bash
set -euo pipefail

CHECKLIST_PATH="${AUTOCOMPLETE_LAB_ONBOARDING_PERMISSION_QA_CHECKLIST:-docs/product/onboarding-permission-qa-checklist.md}"
EXPECTED_COMMIT="${AUTOCOMPLETE_LAB_ONBOARDING_PERMISSION_QA_COMMIT:-}"
MODE="check"

usage() {
  cat <<'EOF'
Usage: script/check_onboarding_permission_qa.sh [--check|--print]

Checks the clean-user onboarding/permission QA checklist. This is a release
gate for first-run trust, not a substitute for doing the manual clean-user run.
It must keep unchecked proof gates visible until proof is actually recorded.
EOF
}

while (($#)); do
  case "$1" in
    --check)
      MODE="check"
      ;;
    --print)
      MODE="print"
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

if [[ "$MODE" == "print" ]]; then
  cat <<EOF
Onboarding permission QA gate

Checklist: $CHECKLIST_PATH

Required before private beta:
- every checklist item is checked,
- the proof log has no Pending rows,
- clean install proof is recorded,
- Accessibility denial/regrant proof is recorded.

Do not describe onboarding proof as complete while unchecked boxes or Pending
proof rows remain.
EOF
  exit 0
fi

if [[ ! -f "$CHECKLIST_PATH" ]]; then
  echo "onboarding QA checklist missing: $CHECKLIST_PATH" >&2
  exit 1
fi

if [[ -z "$EXPECTED_COMMIT" ]]; then
  EXPECTED_COMMIT="$(git rev-parse HEAD 2>/dev/null || true)"
fi
EXPECTED_SHORT_COMMIT="${EXPECTED_COMMIT:0:12}"

unchecked_count="$(
  (grep -E '^[[:space:]]*- \[ \]' "$CHECKLIST_PATH" || true) |
    wc -l |
    tr -d ' '
)"
pending_count="$(
  (grep -Ei '\|[[:space:]]*pending[[:space:]]*\|' "$CHECKLIST_PATH" || true) |
    wc -l |
    tr -d ' '
)"

required_headings=(
  "## First 10-Minute User Map"
  "## Clean Install"
  "## Guided Practice"
  "## Permission Recovery"
  "## Diagnostics"
  "## Model Setup"
  "## Proof Log"
)

missing_headings=()
for heading in "${required_headings[@]}"; do
  if ! grep -Fxq "$heading" "$CHECKLIST_PATH"; then
    missing_headings+=("$heading")
  fi
done

if (( unchecked_count > 0 || pending_count > 0 )); then
  echo "Onboarding permission QA is incomplete: $CHECKLIST_PATH" >&2
  if (( ${#missing_headings[@]} > 0 )); then
    echo "Missing required section heading(s):" >&2
    printf '%s\n' "${missing_headings[@]}" >&2
  fi
  if (( unchecked_count > 0 )); then
    echo "Unchecked item(s): $unchecked_count" >&2
    awk '
      /^## / {
        section = $0
        sub(/^## /, "", section)
        if (!(section in seen)) {
          seen[section] = 1
          order[++orderCount] = section
        }
        next
      }
      /^[[:space:]]*- \[ \]/ {
        if (section == "") {
          section = "(before first section)"
        }
        counts[section]++
      }
      END {
        for (i = 1; i <= orderCount; i++) {
          if (counts[order[i]] > 0) {
            printf "  %s: %d\n", order[i], counts[order[i]]
          }
        }
        if (counts["(before first section)"] > 0) {
          printf "  %s: %d\n", "(before first section)", counts["(before first section)"]
        }
      }
    ' "$CHECKLIST_PATH" >&2
    grep -n -E '^[[:space:]]*- \[ \]' "$CHECKLIST_PATH" >&2
  fi
  if (( pending_count > 0 )); then
    echo "Pending proof row(s): $pending_count" >&2
    grep -n -Ei '\|[[:space:]]*pending[[:space:]]*\|' "$CHECKLIST_PATH" >&2
  fi
  exit 1
fi

if (( ${#missing_headings[@]} > 0 )); then
  echo "Onboarding permission QA is missing required section heading(s):" >&2
  printf '%s\n' "${missing_headings[@]}" >&2
  exit 1
fi

clean_rows="$(
  awk -F'|' -v expected="$EXPECTED_COMMIT" -v expectedShort="$EXPECTED_SHORT_COMMIT" '
    function trim(value) {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      return value
    }
    function commit_matches(value) {
      if (expected == "") {
        return value != "" && tolower(value) != "pending"
      }
      return value == expected || value == expectedShort || index(expected, value) == 1 || index(value, expectedShort) == 1
    }
    /^\|/ {
      commit = trim($3)
      user = trim($4)
      result = trim($5)
      evidence = trim($6)
      if (tolower(user) ~ /clean/ &&
          result == "Pass" &&
          evidence != "" &&
          tolower(evidence) !~ /^pending$/ &&
          tolower(evidence) !~ /^needs / &&
          commit_matches(commit)) {
        count++
      }
    }
    END { print count + 0 }
  ' "$CHECKLIST_PATH"
)"
denied_rows="$(
  awk -F'|' -v expected="$EXPECTED_COMMIT" -v expectedShort="$EXPECTED_SHORT_COMMIT" '
    function trim(value) {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      return value
    }
    function commit_matches(value) {
      if (expected == "") {
        return value != "" && tolower(value) != "pending"
      }
      return value == expected || value == expectedShort || index(expected, value) == 1 || index(value, expectedShort) == 1
    }
    /^\|/ {
      commit = trim($3)
      user = trim($4)
      result = trim($5)
      evidence = trim($6)
      if (tolower(user) ~ /(deny|denied|denial|regrant|recovery)/ &&
          result == "Pass" &&
          evidence != "" &&
          tolower(evidence) !~ /^pending$/ &&
          tolower(evidence) !~ /^needs / &&
          commit_matches(commit)) {
        count++
      }
    }
    END { print count + 0 }
  ' "$CHECKLIST_PATH"
)"

if (( clean_rows == 0 || denied_rows == 0 )); then
  echo "Onboarding permission QA needs current-commit passing clean-install and denial/regrant rows." >&2
  echo "Expected commit: ${EXPECTED_SHORT_COMMIT:-unknown}" >&2
  echo "Clean-install current pass rows: $clean_rows" >&2
  echo "Denial/regrant current pass rows: $denied_rows" >&2
  exit 1
fi

echo "Onboarding permission QA verified: $CHECKLIST_PATH"
