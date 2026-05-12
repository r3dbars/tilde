#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

QUIET=0
while (($#)); do
  case "$1" in
    --quiet)
      QUIET=1
      ;;
    -h|--help|help)
      cat <<'EOF'
Usage: script/validate_beta_issue_template.sh [--quiet]

Validates the private-beta feedback issue form and triage label definitions.
EOF
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      exit 2
      ;;
  esac
  shift
done

TEMPLATE_PATH=".github/ISSUE_TEMPLATE/autocomplete-beta-feedback.yml"
LABELS_PATH=".github/labels.yml"
ISSUES=0

record_issue() {
  echo "beta issue template validation failed: $1" >&2
  ISSUES=$((ISSUES + 1))
}

require_file() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    record_issue "missing $path"
  fi
}

require_contains() {
  local path="$1"
  local expected="$2"
  if ! grep -Fq -- "$expected" "$path"; then
    record_issue "$path is missing: $expected"
  fi
}

reject_contains() {
  local path="$1"
  local rejected="$2"
  if grep -Fq -- "$rejected" "$path"; then
    record_issue "$path contains unsafe copy: $rejected"
  fi
}

require_file "$TEMPLATE_PATH"
require_file "$LABELS_PATH"

if [[ -f "$TEMPLATE_PATH" ]]; then
  require_contains "$TEMPLATE_PATH" "name: SteadyType beta feedback"
  require_contains "$TEMPLATE_PATH" "Do not paste raw typed text"
  require_contains "$TEMPLATE_PATH" "  - beta feedback"
  require_contains "$TEMPLATE_PATH" "  - needs triage"
  require_contains "$TEMPLATE_PATH" "Trust blocker: wrong insertion, submit, secure-field leak, data loss"
  require_contains "$TEMPLATE_PATH" "Yes, redacted export only"
  require_contains "$TEMPLATE_PATH" "No stop condition"

  for field_id in \
    build \
    macos \
    target-app \
    permission-state \
    severity \
    stop-condition \
    expected \
    actual \
    repro \
    diagnostics-consent; do
    require_contains "$TEMPLATE_PATH" "id: $field_id"
  done

  required_count="$(grep -Fc "required: true" "$TEMPLATE_PATH")"
  if ((required_count < 10)); then
    record_issue "$TEMPLATE_PATH should require at least 10 beta metadata fields"
  fi

  reject_contains "$TEMPLATE_PATH" "Paste the text you typed"
  reject_contains "$TEMPLATE_PATH" "Attach raw traces"
  reject_contains "$TEMPLATE_PATH" "Attach screenshots"
fi

if [[ -f "$LABELS_PATH" ]]; then
  for label in \
    "name: beta feedback" \
    "name: needs triage" \
    "name: beta stop" \
    "name: beta trust blocker" \
    "name: beta high" \
    "name: beta needs report" \
    "name: beta docs" \
    "name: beta ready to close"; do
    require_contains "$LABELS_PATH" "$label"
  done
fi

if ((ISSUES > 0)); then
  echo "Beta issue template validation found $ISSUES issue(s)." >&2
  exit 1
fi

if ((QUIET == 0)); then
  echo "Beta issue template validation passed."
fi
