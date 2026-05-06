#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

SOURCE_IMAGE="docs/product/visual-placement-screenshots/chrome-textarea.png"
if [[ ! -f "$SOURCE_IMAGE" ]]; then
  echo "visual evidence self-test requires $SOURCE_IMAGE" >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$TMP_DIR/visual-placement-screenshots"
cp "$SOURCE_IMAGE" "$TMP_DIR/visual-placement-screenshots/good.png"
cat >"$TMP_DIR/visual-placement-screenshots/checklist.md" <<'MARKDOWN'
# Test Checklist

Use disposable screenshots only.
MARKDOWN
GOOD_OUTPUT="$TMP_DIR/good-output.txt"
MISSING_OUTPUT="$TMP_DIR/missing-output.txt"
ORPHAN_OUTPUT="$TMP_DIR/orphan-output.txt"
EMPTY_OUTPUT="$TMP_DIR/empty-output.txt"
INVALID_OUTPUT="$TMP_DIR/invalid-output.txt"
TINY_OUTPUT="$TMP_DIR/tiny-output.txt"
PENDING_OUTPUT="$TMP_DIR/pending-output.txt"
PENDING_STRICT_OUTPUT="$TMP_DIR/pending-strict-output.txt"

expect_failure() {
  local scorecard_path="$1"
  local output_path="$2"
  local expected_text="$3"
  local failure_message="$4"

  if AUTOCOMPLETE_LAB_SCORECARD="$scorecard_path" \
    script/check_visual_placement_evidence.sh >"$output_path" 2>&1; then
    echo "$failure_message" >&2
    cat "$output_path" >&2
    exit 1
  fi

  if ! grep -F "$expected_text" "$output_path" >/dev/null; then
    echo "visual evidence self-test did not explain: $expected_text" >&2
    cat "$output_path" >&2
    exit 1
  fi
}

cat >"$TMP_DIR/scorecard-good.md" <<'MARKDOWN'
# Scorecard

## Visual Placement And Text Box Audit

| App or surface | Grade | Evidence | What is good | What still needs work |
| --- | ---: | --- | --- | --- |
| Chrome textarea | 9/10 | [good.png](visual-placement-screenshots/good.png) | Good. | More real sites. |
MARKDOWN

AUTOCOMPLETE_LAB_SCORECARD="$TMP_DIR/scorecard-good.md" \
  script/check_visual_placement_evidence.sh >"$GOOD_OUTPUT" 2>&1

if ! grep -F "Visual placement evidence verified: 1 screenshot(s)." "$GOOD_OUTPUT" >/dev/null; then
  echo "visual evidence self-test did not verify a good screenshot" >&2
  cat "$GOOD_OUTPUT" >&2
  exit 1
fi

if ! grep -F "All visual placement audit rows are screenshot-backed." "$GOOD_OUTPUT" >/dev/null; then
  echo "visual evidence self-test did not report all screenshot-backed rows" >&2
  cat "$GOOD_OUTPUT" >&2
  exit 1
fi

cat >"$TMP_DIR/scorecard-pending.md" <<'MARKDOWN'
# Scorecard

## Visual Placement And Text Box Audit

| App or surface | Grade | Evidence | What is good | What still needs work |
| --- | ---: | --- | --- | --- |
| Chrome textarea | 9/10 | [good.png](visual-placement-screenshots/good.png) | Good. | More real sites. |
| Codex | 7.5/10 | Pending safe screenshot | Insertion proof exists. | Needs a safe prompt screenshot audit. |
MARKDOWN

AUTOCOMPLETE_LAB_SCORECARD="$TMP_DIR/scorecard-pending.md" \
  script/check_visual_placement_evidence.sh >"$PENDING_OUTPUT" 2>&1

if ! grep -F "Pending screenshot-backed visual proof:" "$PENDING_OUTPUT" >/dev/null; then
  echo "visual evidence self-test did not list pending screenshot proof" >&2
  cat "$PENDING_OUTPUT" >&2
  exit 1
fi

if ! grep -F "Codex: Pending safe screenshot - next: Needs a safe prompt screenshot audit." "$PENDING_OUTPUT" >/dev/null; then
  echo "visual evidence self-test did not make the pending Codex proof actionable" >&2
  cat "$PENDING_OUTPUT" >&2
  exit 1
fi

if ! grep -F "Safe capture checklist: visual-placement-screenshots/checklist.md" "$PENDING_OUTPUT" >/dev/null; then
  echo "visual evidence self-test did not point pending proof at the safe capture checklist" >&2
  cat "$PENDING_OUTPUT" >&2
  exit 1
fi

if AUTOCOMPLETE_LAB_SCORECARD="$TMP_DIR/scorecard-pending.md" \
  script/check_visual_placement_evidence.sh --require-all >"$PENDING_STRICT_OUTPUT" 2>&1; then
  echo "visual evidence self-test expected strict pending screenshot proof to fail" >&2
  cat "$PENDING_STRICT_OUTPUT" >&2
  exit 1
fi

if ! grep -F "Pending screenshot-backed visual proof:" "$PENDING_STRICT_OUTPUT" >/dev/null; then
  echo "visual evidence self-test did not explain strict pending screenshot proof" >&2
  cat "$PENDING_STRICT_OUTPUT" >&2
  exit 1
fi

cat >"$TMP_DIR/scorecard-missing.md" <<'MARKDOWN'
# Scorecard

| App or surface | Grade | Evidence |
| --- | ---: | --- |
| Missing | 1/10 | [missing.png](visual-placement-screenshots/missing.png) |
MARKDOWN

expect_failure \
  "$TMP_DIR/scorecard-missing.md" \
  "$MISSING_OUTPUT" \
  "Missing screenshot evidence" \
  "visual evidence self-test expected missing screenshot evidence to fail"

cp "$SOURCE_IMAGE" "$TMP_DIR/visual-placement-screenshots/orphan.png"

expect_failure \
  "$TMP_DIR/scorecard-good.md" \
  "$ORPHAN_OUTPUT" \
  "Unreferenced screenshot evidence" \
  "visual evidence self-test expected unreferenced screenshot evidence to fail"

rm "$TMP_DIR/visual-placement-screenshots/orphan.png"

: >"$TMP_DIR/visual-placement-screenshots/empty.png"
cat >"$TMP_DIR/scorecard-empty.md" <<'MARKDOWN'
# Scorecard

| App or surface | Grade | Evidence |
| --- | ---: | --- |
| Empty | 1/10 | [empty.png](visual-placement-screenshots/empty.png) |
MARKDOWN

expect_failure \
  "$TMP_DIR/scorecard-empty.md" \
  "$EMPTY_OUTPUT" \
  "Empty screenshot evidence" \
  "visual evidence self-test expected empty screenshot evidence to fail"

rm "$TMP_DIR/visual-placement-screenshots/empty.png"
printf 'not a png\n' >"$TMP_DIR/visual-placement-screenshots/invalid.png"
cat >"$TMP_DIR/scorecard-invalid.md" <<'MARKDOWN'
# Scorecard

| App or surface | Grade | Evidence |
| --- | ---: | --- |
| Invalid | 1/10 | [invalid.png](visual-placement-screenshots/invalid.png) |
MARKDOWN

expect_failure \
  "$TMP_DIR/scorecard-invalid.md" \
  "$INVALID_OUTPUT" \
  "Invalid screenshot evidence type" \
  "visual evidence self-test expected invalid screenshot evidence to fail"

rm "$TMP_DIR/visual-placement-screenshots/invalid.png"
cp "$SOURCE_IMAGE" "$TMP_DIR/visual-placement-screenshots/tiny.png"
sips -z 16 16 "$TMP_DIR/visual-placement-screenshots/tiny.png" >/dev/null
cat >"$TMP_DIR/scorecard-tiny.md" <<'MARKDOWN'
# Scorecard

| App or surface | Grade | Evidence |
| --- | ---: | --- |
| Tiny | 1/10 | [tiny.png](visual-placement-screenshots/tiny.png) |
MARKDOWN

expect_failure \
  "$TMP_DIR/scorecard-tiny.md" \
  "$TINY_OUTPUT" \
  "Screenshot evidence too small" \
  "visual evidence self-test expected tiny screenshot evidence to fail"

echo "Visual placement evidence self-test passed."
