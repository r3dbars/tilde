#!/usr/bin/env bash
set -euo pipefail

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

PASSING="$TMP_DIR/passing.md"
UNCHECKED="$TMP_DIR/unchecked.md"
PENDING="$TMP_DIR/pending.md"
MISSING_DENIED="$TMP_DIR/missing-denied.md"
INDENTED_UNCHECKED="$TMP_DIR/indented-unchecked.md"
STALE_COMMIT="$TMP_DIR/stale-commit.md"
MISSING_SECTION="$TMP_DIR/missing-section.md"

write_required_sections() {
  cat <<'EOF'
## First 10-Minute User Map

## Clean Install

## Guided Practice

## Permission Recovery

## Diagnostics

## Model Setup

## Proof Log
EOF
}

cat >"$PASSING" <<'EOF'
# Onboarding Permission QA Checklist

## First 10-Minute User Map

## Clean Install

- [x] Install the app with Accessibility off.
- [x] Confirm the app explains Accessibility before macOS prompts.

## Guided Practice

## Permission Recovery

## Diagnostics

## Model Setup

## Proof Log

| Date | Build commit | macOS user | Result | Evidence |
| --- | --- | --- | --- | --- |
| 2026-05-12 | abc123 | Clean tester account | Pass | first prompt followed Allow Accessibility |
| 2026-05-12 | abc123 | Permission denied account | Pass | denied recovery worked |
EOF

AUTOCOMPLETE_LAB_ONBOARDING_PERMISSION_QA_CHECKLIST="$PASSING" \
AUTOCOMPLETE_LAB_ONBOARDING_PERMISSION_QA_COMMIT="abc123" \
  script/check_onboarding_permission_qa.sh --check >/dev/null

{
  cat <<'EOF'
# Onboarding Permission QA Checklist
EOF
  write_required_sections
  cat <<'EOF'

- [ ] Install the app with Accessibility off.

| Date | Build commit | macOS user | Result | Evidence |
| --- | --- | --- | --- | --- |
| 2026-05-12 | abc123 | Clean tester account | Pass | first prompt followed Allow Accessibility |
| 2026-05-12 | abc123 | Permission denied account | Pass | denied recovery worked |
EOF
} >"$UNCHECKED"

if AUTOCOMPLETE_LAB_ONBOARDING_PERMISSION_QA_CHECKLIST="$UNCHECKED" \
  AUTOCOMPLETE_LAB_ONBOARDING_PERMISSION_QA_COMMIT="abc123" \
  script/check_onboarding_permission_qa.sh --check >/dev/null 2>&1; then
  echo "onboarding QA self-test expected unchecked checklist to fail" >&2
  exit 1
fi

{
  cat <<'EOF'
# Onboarding Permission QA Checklist
EOF
  write_required_sections
  cat <<'EOF'

- [x] Install the app with Accessibility off.

| Date | Build commit | macOS user | Result | Evidence |
| --- | --- | --- | --- | --- |
| Pending | Pending | Clean tester account | pending | Needs fresh clean-user run. |
EOF
} >"$PENDING"

if AUTOCOMPLETE_LAB_ONBOARDING_PERMISSION_QA_CHECKLIST="$PENDING" \
  AUTOCOMPLETE_LAB_ONBOARDING_PERMISSION_QA_COMMIT="abc123" \
  script/check_onboarding_permission_qa.sh --check >/dev/null 2>&1; then
  echo "onboarding QA self-test expected pending proof log to fail" >&2
  exit 1
fi

{
  cat <<'EOF'
# Onboarding Permission QA Checklist
EOF
  write_required_sections
  cat <<'EOF'

- [x] Install the app with Accessibility off.

| Date | Build commit | macOS user | Result | Evidence |
| --- | --- | --- | --- | --- |
| 2026-05-12 | abc123 | Clean tester account | Pass | first prompt followed Allow Accessibility |
EOF
} >"$MISSING_DENIED"

if AUTOCOMPLETE_LAB_ONBOARDING_PERMISSION_QA_CHECKLIST="$MISSING_DENIED" \
  AUTOCOMPLETE_LAB_ONBOARDING_PERMISSION_QA_COMMIT="abc123" \
  script/check_onboarding_permission_qa.sh --check >/dev/null 2>&1; then
  echo "onboarding QA self-test expected missing denial proof to fail" >&2
  exit 1
fi

{
  cat <<'EOF'
# Onboarding Permission QA Checklist
EOF
  write_required_sections
  cat <<'EOF'

  - [ ] Indented unchecked proof rows must still fail.

| Date | Build commit | macOS user | Result | Evidence |
| --- | --- | --- | --- | --- |
| 2026-05-12 | abc123 | Clean tester account | Pass | first prompt followed Allow Accessibility |
| 2026-05-12 | abc123 | Permission denied account | Pass | denied recovery worked |
EOF
} >"$INDENTED_UNCHECKED"

if AUTOCOMPLETE_LAB_ONBOARDING_PERMISSION_QA_CHECKLIST="$INDENTED_UNCHECKED" \
  AUTOCOMPLETE_LAB_ONBOARDING_PERMISSION_QA_COMMIT="abc123" \
  script/check_onboarding_permission_qa.sh --check >/dev/null 2>&1; then
  echo "onboarding QA self-test expected indented unchecked row to fail" >&2
  exit 1
fi

cat >"$STALE_COMMIT" <<'EOF'
# Onboarding Permission QA Checklist

## First 10-Minute User Map

## Clean Install

- [x] Install the app with Accessibility off.

## Guided Practice

## Permission Recovery

## Diagnostics

## Model Setup

## Proof Log

| Date | Build commit | macOS user | Result | Evidence |
| --- | --- | --- | --- | --- |
| 2026-05-12 | stale123 | Clean tester account | Pass | first prompt followed Allow Accessibility |
| 2026-05-12 | stale123 | Permission denied account | Pass | denied recovery worked |
EOF

if AUTOCOMPLETE_LAB_ONBOARDING_PERMISSION_QA_CHECKLIST="$STALE_COMMIT" \
  AUTOCOMPLETE_LAB_ONBOARDING_PERMISSION_QA_COMMIT="abc123" \
  script/check_onboarding_permission_qa.sh --check >/dev/null 2>&1; then
  echo "onboarding QA self-test expected stale commit proof to fail" >&2
  exit 1
fi

cat >"$MISSING_SECTION" <<'EOF'
# Onboarding Permission QA Checklist

## Clean Install

- [x] Install the app with Accessibility off.

## Guided Practice

## Permission Recovery

## Diagnostics

## Model Setup

## Proof Log

| Date | Build commit | macOS user | Result | Evidence |
| --- | --- | --- | --- | --- |
| 2026-05-12 | abc123 | Clean tester account | Pass | first prompt followed Allow Accessibility |
| 2026-05-12 | abc123 | Permission denied account | Pass | denied recovery worked |
EOF

if AUTOCOMPLETE_LAB_ONBOARDING_PERMISSION_QA_CHECKLIST="$MISSING_SECTION" \
  AUTOCOMPLETE_LAB_ONBOARDING_PERMISSION_QA_COMMIT="abc123" \
  script/check_onboarding_permission_qa.sh --check >/dev/null 2>&1; then
  echo "onboarding QA self-test expected missing section to fail" >&2
  exit 1
fi

script/check_onboarding_permission_qa.sh --print >"$TMP_DIR/print.txt"
if ! grep -F "Required before private beta" "$TMP_DIR/print.txt" >/dev/null; then
  echo "onboarding QA self-test expected print mode to describe the gate" >&2
  exit 1
fi

echo "Onboarding permission QA self-test passed."
