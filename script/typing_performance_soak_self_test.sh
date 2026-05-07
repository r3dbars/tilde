#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TMP_DIR="$(mktemp -d)"
TEST_DEFAULTS_DOMAIN="bar.r3d.autocomplete-lab.typing-soak-self-test.$$"
export AUTOCOMPLETE_LAB_DEFAULTS_DOMAIN="$TEST_DEFAULTS_DOMAIN"
trap 'defaults delete "$TEST_DEFAULTS_DOMAIN" >/dev/null 2>&1 || true; rm -rf "$TMP_DIR"' EXIT

script/typing_performance_soak.sh --dry-run >"$TMP_DIR/default.txt"

if ! grep -F "Safe typing performance soak" "$TMP_DIR/default.txt" >/dev/null; then
  echo "typing soak self-test did not print the plan title" >&2
  cat "$TMP_DIR/default.txt" >&2
  exit 1
fi

if ! grep -F "Target app: TextEdit disposable temp file" "$TMP_DIR/default.txt" >/dev/null; then
  echo "typing soak self-test did not explain the safe TextEdit target" >&2
  cat "$TMP_DIR/default.txt" >&2
  exit 1
fi

if ! grep -F "Synthetic text: 1800 generated chars from a built-in neutral fixture" "$TMP_DIR/default.txt" >/dev/null; then
  echo "typing soak self-test did not report the default synthetic text length" >&2
  cat "$TMP_DIR/default.txt" >&2
  exit 1
fi

if ! grep -F "Event tap proof: require at least 100 samples" "$TMP_DIR/default.txt" >/dev/null; then
  echo "typing soak self-test did not require event-tap samples by default" >&2
  cat "$TMP_DIR/default.txt" >&2
  exit 1
fi

if ! grep -F "AX warnings: separate non-fatal lane" "$TMP_DIR/default.txt" >/dev/null; then
  echo "typing soak self-test did not keep AX warnings separate by default" >&2
  cat "$TMP_DIR/default.txt" >&2
  exit 1
fi

if ! grep -F "Primer: require a TextEdit suggestion before long typing" "$TMP_DIR/default.txt" >/dev/null; then
  echo "typing soak self-test did not explain the TextEdit suggestion primer" >&2
  cat "$TMP_DIR/default.txt" >&2
  exit 1
fi

if ! grep -F "TextEdit enablement: already allowed" "$TMP_DIR/default.txt" >/dev/null; then
  echo "typing soak self-test did not report TextEdit enablement state" >&2
  cat "$TMP_DIR/default.txt" >&2
  exit 1
fi

script/typing_performance_soak.sh \
  --dry-run \
  --skip-build \
  --strict-ax \
  --characters 250 \
  --chunk-size 7 \
  --delay-ms 2 \
  --require-event-tap-samples 25 \
  --require-ax-samples 3 >"$TMP_DIR/strict.txt"

if ! grep -F "Build: skipped; using an already-running app" "$TMP_DIR/strict.txt" >/dev/null; then
  echo "typing soak self-test did not honor --skip-build" >&2
  cat "$TMP_DIR/strict.txt" >&2
  exit 1
fi

if ! grep -F "Typing: 7-char chunks with 2ms delay" "$TMP_DIR/strict.txt" >/dev/null; then
  echo "typing soak self-test did not honor chunk and delay overrides" >&2
  cat "$TMP_DIR/strict.txt" >&2
  exit 1
fi

if ! grep -F "AppleScript timeout:" "$TMP_DIR/strict.txt" >/dev/null; then
  echo "typing soak self-test did not print the computed AppleScript timeout" >&2
  cat "$TMP_DIR/strict.txt" >&2
  exit 1
fi

if ! grep -F "Event tap proof: require at least 25 samples" "$TMP_DIR/strict.txt" >/dev/null; then
  echo "typing soak self-test did not honor event-tap sample override" >&2
  cat "$TMP_DIR/strict.txt" >&2
  exit 1
fi

if ! grep -F "AX warnings: strict; slow or skipped focused-text polling fails the soak" "$TMP_DIR/strict.txt" >/dev/null; then
  echo "typing soak self-test did not honor --strict-ax" >&2
  cat "$TMP_DIR/strict.txt" >&2
  exit 1
fi

if ! grep -F "AX sample proof: require at least 3 focused-text poll samples" "$TMP_DIR/strict.txt" >/dev/null; then
  echo "typing soak self-test did not honor AX sample override" >&2
  cat "$TMP_DIR/strict.txt" >&2
  exit 1
fi

defaults write "$TEST_DEFAULTS_DOMAIN" DisabledBundleIdentifiers -array com.apple.TextEdit md.obsidian
script/typing_performance_soak.sh --dry-run >"$TMP_DIR/textedit-disabled.txt"

if ! grep -F "TextEdit enablement: would temporarily allow TextEdit before relaunch" "$TMP_DIR/textedit-disabled.txt" >/dev/null; then
  echo "typing soak self-test did not explain temporary TextEdit enablement" >&2
  cat "$TMP_DIR/textedit-disabled.txt" >&2
  exit 1
fi

if script/typing_performance_soak.sh --dry-run --skip-build >/dev/null 2>"$TMP_DIR/textedit-disabled-skip-build.txt"; then
  echo "typing soak self-test expected disabled TextEdit with --skip-build to fail" >&2
  exit 1
fi

if ! grep -F -- "--skip-build cannot refresh the running app state" "$TMP_DIR/textedit-disabled-skip-build.txt" >/dev/null; then
  echo "typing soak self-test did not explain disabled TextEdit plus --skip-build" >&2
  cat "$TMP_DIR/textedit-disabled-skip-build.txt" >&2
  exit 1
fi

defaults delete "$TEST_DEFAULTS_DOMAIN" DisabledBundleIdentifiers >/dev/null 2>&1 || true

if script/typing_performance_soak.sh --dry-run --characters 99 >/dev/null 2>"$TMP_DIR/short.txt"; then
  echo "typing soak self-test expected very short soaks to fail" >&2
  exit 1
fi

if ! grep -F "must be at least 100" "$TMP_DIR/short.txt" >/dev/null; then
  echo "typing soak self-test did not explain the minimum character count" >&2
  cat "$TMP_DIR/short.txt" >&2
  exit 1
fi

if script/typing_performance_soak.sh --dry-run --chunk-size 81 >/dev/null 2>"$TMP_DIR/chunk.txt"; then
  echo "typing soak self-test expected huge chunks to fail" >&2
  exit 1
fi

if ! grep -F "must be 80 or lower" "$TMP_DIR/chunk.txt" >/dev/null; then
  echo "typing soak self-test did not explain the chunk-size cap" >&2
  cat "$TMP_DIR/chunk.txt" >&2
  exit 1
fi

if script/typing_performance_soak.sh --dry-run --app codex >/dev/null 2>"$TMP_DIR/app.txt"; then
  echo "typing soak self-test expected unsupported app automation to fail" >&2
  exit 1
fi

if ! grep -F "Only TextEdit is automated" "$TMP_DIR/app.txt" >/dev/null; then
  echo "typing soak self-test did not explain why unsupported apps are blocked" >&2
  cat "$TMP_DIR/app.txt" >&2
  exit 1
fi

if script/typing_performance_soak.sh --dry-run --unknown >/dev/null 2>&1; then
  echo "typing soak self-test expected unknown options to fail" >&2
  exit 1
fi

echo "Typing performance soak self-test passed."
