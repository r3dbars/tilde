#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

write_deep_dive() {
  local path="$1"
  local overall="$2"
  local area="$3"

  cat >"$path" <<EOF
# Deep Dive Scorecard

Overall: $overall/10.

| Area | Rating | Why |
| --- | ---: | --- |
| Normal typing passthrough | $area/10 | proof |

| App or surface | Grade | Evidence | What is good | What still needs work |
| --- | ---: | --- | --- | --- |
| TextEdit | $area/10 | screenshot | proof | none |
EOF
}

write_apple_native() {
  local path="$1"
  local overall="$2"
  local current="$3"

  cat >"$path" <<EOF
# Apple-Native Experience Checklist

Overall Apple-native feel: $overall/100.

| Category | Weight | Current | Target | Why |
| --- | ---: | ---: | ---: | --- |
| Typing must feel untouched | 15 | $current | 100 | proof |

Weighted score: $overall/100.

## Category 1

Current score: $current/100.
EOF
}

write_app_proof() {
  local path="$1"
  local grade="$2"

  cat >"$path" <<EOF
# App Proof Matrix

| Surface | Grade | Evidence | What is good | What still needs work |
| --- | --- | --- | --- | --- |
| TextEdit | $grade | screenshot | proof | none |
EOF
}

PASSING_DEEP="$TMP_DIR/deep-pass.md"
PASSING_APPLE="$TMP_DIR/apple-pass.md"
PASSING_PROOF="$TMP_DIR/proof-pass.md"
FAILING_DEEP="$TMP_DIR/deep-fail.md"
FAILING_APPLE="$TMP_DIR/apple-fail.md"
FAILING_PROOF="$TMP_DIR/proof-fail.md"

write_deep_dive "$PASSING_DEEP" 10 10
write_apple_native "$PASSING_APPLE" 100 100
write_app_proof "$PASSING_PROOF" A

AUTOCOMPLETE_LAB_DEEP_DIVE_SCORECARD="$PASSING_DEEP" \
AUTOCOMPLETE_LAB_APPLE_NATIVE_CHECKLIST="$PASSING_APPLE" \
AUTOCOMPLETE_LAB_APP_PROOF_MATRIX="$PASSING_PROOF" \
  script/check_score_targets.sh >"$TMP_DIR/passing.txt"

if ! grep -F "All score targets are complete." "$TMP_DIR/passing.txt" >/dev/null; then
  echo "score target self-test did not pass complete docs" >&2
  exit 1
fi

write_deep_dive "$FAILING_DEEP" 8.9 9.7
write_apple_native "$FAILING_APPLE" 82 92
write_app_proof "$FAILING_PROOF" B-

if AUTOCOMPLETE_LAB_DEEP_DIVE_SCORECARD="$FAILING_DEEP" \
  AUTOCOMPLETE_LAB_APPLE_NATIVE_CHECKLIST="$FAILING_APPLE" \
  AUTOCOMPLETE_LAB_APP_PROOF_MATRIX="$FAILING_PROOF" \
  script/check_score_targets.sh >"$TMP_DIR/failing.txt" 2>&1; then
  echo "score target self-test expected failing docs to fail" >&2
  exit 1
fi

for expected in \
  "$FAILING_DEEP: Overall is 8.9/10" \
  "$FAILING_DEEP: Normal typing passthrough is 9.7/10" \
  "$FAILING_APPLE: Overall Apple-native feel is 82/100" \
  "$FAILING_APPLE: Typing must feel untouched is 92/100" \
  "$FAILING_APPLE: Category 1 current score is 92/100" \
  "$FAILING_PROOF: TextEdit is B-"; do
  if ! grep -F -- "$expected" "$TMP_DIR/failing.txt" >/dev/null; then
    echo "score target self-test missing expected failure: $expected" >&2
    cat "$TMP_DIR/failing.txt" >&2
    exit 1
  fi
done

echo "Score target self-test passed."
