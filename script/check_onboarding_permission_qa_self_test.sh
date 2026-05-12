#!/usr/bin/env bash
set -euo pipefail

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

PASSING="$TMP_DIR/passing.md"
UNCHECKED="$TMP_DIR/unchecked.md"
PENDING="$TMP_DIR/pending.md"
MISSING_DENIED="$TMP_DIR/missing-denied.md"

cat >"$PASSING" <<'EOF'
# Onboarding Permission QA Checklist

- [x] Install the app with Accessibility off.
- [x] Confirm the app explains Accessibility before macOS prompts.

| Date | Build commit | macOS user | Result | Evidence |
| --- | --- | --- | --- | --- |
| 2026-05-12 | abc123 | Clean tester account | Pass | first prompt followed Allow Accessibility |
| 2026-05-12 | abc123 | Permission denied account | Pass | denied recovery worked |
EOF

AUTOCOMPLETE_LAB_ONBOARDING_PERMISSION_QA_CHECKLIST="$PASSING" \
  script/check_onboarding_permission_qa.sh --check >/dev/null

cat >"$UNCHECKED" <<'EOF'
# Onboarding Permission QA Checklist

- [ ] Install the app with Accessibility off.

| Date | Build commit | macOS user | Result | Evidence |
| --- | --- | --- | --- | --- |
| 2026-05-12 | abc123 | Clean tester account | Pass | first prompt followed Allow Accessibility |
| 2026-05-12 | abc123 | Permission denied account | Pass | denied recovery worked |
EOF

if AUTOCOMPLETE_LAB_ONBOARDING_PERMISSION_QA_CHECKLIST="$UNCHECKED" \
  script/check_onboarding_permission_qa.sh --check >/dev/null 2>&1; then
  echo "onboarding QA self-test expected unchecked checklist to fail" >&2
  exit 1
fi

cat >"$PENDING" <<'EOF'
# Onboarding Permission QA Checklist

- [x] Install the app with Accessibility off.

| Date | Build commit | macOS user | Result | Evidence |
| --- | --- | --- | --- | --- |
| Pending | Pending | Clean tester account | Pending | Needs fresh clean-user run. |
EOF

if AUTOCOMPLETE_LAB_ONBOARDING_PERMISSION_QA_CHECKLIST="$PENDING" \
  script/check_onboarding_permission_qa.sh --check >/dev/null 2>&1; then
  echo "onboarding QA self-test expected pending proof log to fail" >&2
  exit 1
fi

cat >"$MISSING_DENIED" <<'EOF'
# Onboarding Permission QA Checklist

- [x] Install the app with Accessibility off.

| Date | Build commit | macOS user | Result | Evidence |
| --- | --- | --- | --- | --- |
| 2026-05-12 | abc123 | Clean tester account | Pass | first prompt followed Allow Accessibility |
EOF

if AUTOCOMPLETE_LAB_ONBOARDING_PERMISSION_QA_CHECKLIST="$MISSING_DENIED" \
  script/check_onboarding_permission_qa.sh --check >/dev/null 2>&1; then
  echo "onboarding QA self-test expected missing denial proof to fail" >&2
  exit 1
fi

script/check_onboarding_permission_qa.sh --print >"$TMP_DIR/print.txt"
if ! grep -F "Required before private beta" "$TMP_DIR/print.txt" >/dev/null; then
  echo "onboarding QA self-test expected print mode to describe the gate" >&2
  exit 1
fi

echo "Onboarding permission QA self-test passed."
