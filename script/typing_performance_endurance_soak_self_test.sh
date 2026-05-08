#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

script/typing_performance_endurance_soak.sh --dry-run >"$TMP_DIR/default.txt"

for expected in \
  "Typing endurance soak" \
  "Duration target: 10 minute(s)" \
  "Computed text: 12000 generated chars" \
  "Underlying command: script/typing_performance_soak.sh --characters 12000 --chunk-size 5 --delay-ms 250 --require-event-tap-samples 0 --require-ax-samples 0" \
  "Synthetic text: 12000 generated chars from a built-in neutral fixture" \
  "Typed text proof: exact TextEdit clipboard capture match required" \
  "Typing driver: CGEvent Unicode key events after target-window focus" \
  "Typing batches: up to 250 chars per Swift process" \
  "AX warmup: waits for a focused-text poll summary before typing"; do
  if ! grep -F "$expected" "$TMP_DIR/default.txt" >/dev/null; then
    echo "endurance soak self-test missing default output: $expected" >&2
    cat "$TMP_DIR/default.txt" >&2
    exit 1
  fi
done

script/typing_performance_endurance_soak.sh \
  --dry-run \
  --skip-build \
  --strict-ax \
  --minutes 1 \
  --chunk-size 10 \
  --delay-ms 100 \
  --require-event-tap-samples 50 \
  --require-ax-samples 5 >"$TMP_DIR/custom.txt"

for expected in \
  "Duration target: 1 minute(s)" \
  "Computed text: 6000 generated chars" \
  "Build: skipped; using an already-running app" \
  "AX warnings: strict; threshold-exceeding or skipped focused-text polling fails the soak" \
  "AX sample proof: require at least 5 focused-text poll samples"; do
  if ! grep -F "$expected" "$TMP_DIR/custom.txt" >/dev/null; then
    echo "endurance soak self-test missing custom output: $expected" >&2
    cat "$TMP_DIR/custom.txt" >&2
    exit 1
  fi
done

if script/typing_performance_endurance_soak.sh --dry-run --minutes 0 >/dev/null 2>"$TMP_DIR/minutes.txt"; then
  echo "endurance soak self-test expected zero minutes to fail" >&2
  exit 1
fi

if ! grep -F -- "--minutes must be a positive integer" "$TMP_DIR/minutes.txt" >/dev/null; then
  echo "endurance soak self-test did not explain invalid minutes" >&2
  cat "$TMP_DIR/minutes.txt" >&2
  exit 1
fi

if script/typing_performance_endurance_soak.sh --dry-run --delay-ms 9 >/dev/null 2>"$TMP_DIR/delay.txt"; then
  echo "endurance soak self-test expected tiny delay to fail" >&2
  exit 1
fi

if ! grep -F -- "--delay-ms must be at least 10" "$TMP_DIR/delay.txt" >/dev/null; then
  echo "endurance soak self-test did not explain tiny delay" >&2
  cat "$TMP_DIR/delay.txt" >&2
  exit 1
fi

echo "Typing endurance soak self-test passed."
