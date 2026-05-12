#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TMP_DIR="$(mktemp -d)"
TEST_DEFAULTS_DOMAIN="bar.r3d.steadytype.typing-soak-self-test.$$"
export AUTOCOMPLETE_LAB_DEFAULTS_DOMAIN="$TEST_DEFAULTS_DOMAIN"
trap 'defaults delete "$TEST_DEFAULTS_DOMAIN" >/dev/null 2>&1 || true; rm -rf "$TMP_DIR"' EXIT

script/typing_performance_soak.sh --dry-run >"$TMP_DIR/default.txt"

if ! grep -F "Safe typing performance soak" "$TMP_DIR/default.txt" >/dev/null; then
  echo "typing soak self-test did not print the plan title" >&2
  cat "$TMP_DIR/default.txt" >&2
  exit 1
fi

if ! grep -F "Target app: disposable TextEdit window" "$TMP_DIR/default.txt" >/dev/null; then
  echo "typing soak self-test did not explain the safe TextEdit target" >&2
  cat "$TMP_DIR/default.txt" >&2
  exit 1
fi

if ! grep -F "Safety: temporarily enables TextEdit only for this proof pass" "$TMP_DIR/default.txt" >/dev/null; then
  echo "typing soak self-test did not explain temporary TextEdit enablement" >&2
  cat "$TMP_DIR/default.txt" >&2
  exit 1
fi

if ! grep -F "Safety: temporarily resumes suggestions and restores the previous pause state" "$TMP_DIR/default.txt" >/dev/null; then
  echo "typing soak self-test did not explain temporary pause-state recovery" >&2
  cat "$TMP_DIR/default.txt" >&2
  exit 1
fi

if ! grep -F "Synthetic text: 1200 generated chars from a built-in neutral fixture" "$TMP_DIR/default.txt" >/dev/null; then
  echo "typing soak self-test did not report the default synthetic text length" >&2
  cat "$TMP_DIR/default.txt" >&2
  exit 1
fi

if ! grep -F "Typed text proof: exact TextEdit clipboard capture match required" "$TMP_DIR/default.txt" >/dev/null; then
  echo "typing soak self-test did not explain exact typed-text verification" >&2
  cat "$TMP_DIR/default.txt" >&2
  exit 1
fi

if ! grep -F "Typing driver: CGEvent Unicode key events after target-window focus" "$TMP_DIR/default.txt" >/dev/null; then
  echo "typing soak self-test did not explain the CGEvent typing driver" >&2
  cat "$TMP_DIR/default.txt" >&2
  exit 1
fi

if ! grep -F "Typing batches: up to 250 chars per Swift process" "$TMP_DIR/default.txt" >/dev/null; then
  echo "typing soak self-test did not explain segmented Swift typing batches" >&2
  cat "$TMP_DIR/default.txt" >&2
  exit 1
fi

if ! grep -F "Typing focus guard: verifies TextEdit is frontmost before each generated key" "$TMP_DIR/default.txt" >/dev/null; then
  echo "typing soak self-test did not explain the frontmost app guard" >&2
  cat "$TMP_DIR/default.txt" >&2
  exit 1
fi

if ! grep -F "AX warmup: waits for a focused-text poll summary before typing" "$TMP_DIR/default.txt" >/dev/null; then
  echo "typing soak self-test did not explain the AX warmup flush" >&2
  cat "$TMP_DIR/default.txt" >&2
  exit 1
fi

if ! grep -F "Event tap proof: not required for this normal-typing pass" "$TMP_DIR/default.txt" >/dev/null; then
  echo "typing soak self-test did not explain normal typing event-tap scope" >&2
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

if ! grep -F "Typing: 7-char chunks with 2ms delay and 3000us key spacing" "$TMP_DIR/strict.txt" >/dev/null; then
  echo "typing soak self-test did not honor chunk and delay overrides" >&2
  cat "$TMP_DIR/strict.txt" >&2
  exit 1
fi

if ! grep -F "Typing duration budget:" "$TMP_DIR/strict.txt" >/dev/null; then
  echo "typing soak self-test did not print the computed typing duration budget" >&2
  cat "$TMP_DIR/strict.txt" >&2
  exit 1
fi

if ! grep -F "Event tap proof: require at least 25 samples" "$TMP_DIR/strict.txt" >/dev/null; then
  echo "typing soak self-test did not honor event-tap sample override" >&2
  cat "$TMP_DIR/strict.txt" >&2
  exit 1
fi

if ! grep -F "AX warnings: strict; threshold-exceeding or skipped focused-text polling fails the soak" "$TMP_DIR/strict.txt" >/dev/null; then
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

large_log="$TMP_DIR/large-diagnostics.log"
for _ in $(seq 1 8000); do
  printf '2026-05-12T00:00:00Z status decision=waiting\n'
done >"$large_log"
printf '2026-05-12T00:00:01Z focused-text-poll-latency-summary count=60 maxMilliseconds=8\n' >>"$large_log"
for _ in $(seq 1 8000); do
  printf '2026-05-12T00:00:02Z status decision=waiting\n'
done >>"$large_log"

if ! script/typing_performance_soak.sh --self-test-log-scan "$large_log" 7000; then
  echo "typing soak self-test expected large post-start log scan to find focused-text summary" >&2
  exit 1
fi

if script/typing_performance_soak.sh --self-test-log-scan "$large_log" 9000; then
  echo "typing soak self-test expected post-summary log scan to fail" >&2
  exit 1
fi

echo "Typing performance soak self-test passed."
