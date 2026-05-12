#!/usr/bin/env bash
set -euo pipefail

CHECKLIST_PATH="${AUTOCOMPLETE_LAB_ONBOARDING_PERMISSION_QA_CHECKLIST:-docs/product/onboarding-permission-qa-checklist.md}"
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

unchecked_count="$(
  (grep -E '^- \[ \]' "$CHECKLIST_PATH" || true) |
    wc -l |
    tr -d ' '
)"
pending_count="$(
  (grep -E '\|[[:space:]]*Pending[[:space:]]*\|' "$CHECKLIST_PATH" || true) |
    wc -l |
    tr -d ' '
)"

if (( unchecked_count > 0 || pending_count > 0 )); then
  echo "Onboarding permission QA is incomplete: $CHECKLIST_PATH" >&2
  if (( unchecked_count > 0 )); then
    echo "Unchecked item(s): $unchecked_count" >&2
    grep -n -E '^- \[ \]' "$CHECKLIST_PATH" | sed -n '1,12p' >&2
  fi
  if (( pending_count > 0 )); then
    echo "Pending proof row(s): $pending_count" >&2
    grep -n -E '\|[[:space:]]*Pending[[:space:]]*\|' "$CHECKLIST_PATH" | sed -n '1,8p' >&2
  fi
  exit 1
fi

clean_rows="$(
  (grep -E '\|[^|]+\|[^|]+\|[^|]*(Clean|clean)[^|]*\|[^|]*(Pass|pass)[^|]*\|' "$CHECKLIST_PATH" || true) |
    wc -l |
    tr -d ' '
)"
denied_rows="$(
  (grep -E '\|[^|]+\|[^|]+\|[^|]*(Deny|deny|Permission|permission)[^|]*\|[^|]*(Pass|pass)[^|]*\|' "$CHECKLIST_PATH" || true) |
    wc -l |
    tr -d ' '
)"

if (( clean_rows == 0 || denied_rows == 0 )); then
  echo "Onboarding permission QA needs recorded passing clean-install and denied-permission rows." >&2
  echo "Clean-install pass rows: $clean_rows" >&2
  echo "Denied-permission pass rows: $denied_rows" >&2
  exit 1
fi

echo "Onboarding permission QA verified: $CHECKLIST_PATH"
