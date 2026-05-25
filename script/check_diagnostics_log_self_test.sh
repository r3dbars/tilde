#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

LOG_PATH="$TMP_DIR/diagnostics.log"

cat >"$LOG_PATH" <<'LOG'
2026-05-12T20:00:00Z launch accessibility=true
2026-05-12T20:00:00Z runtime-bootstrap activeCandidate=mlx allowsUserManagedServer=false asset=Qwen3.5-4B-4bit nativeRuntimeAvailable=true preferredCandidate=mlx
2026-05-12T20:00:01Z runtime-warm-start candidate=mlx
2026-05-12T20:00:02Z runtime-warm-succeeded candidate=mlx state=ready (MLX)
2026-05-12T20:00:02Z runtime readinessAction=none readinessStage=ready state=ready (MLX)
2026-05-12T20:00:03Z status accessibility=AX ok app=TextEdit control=running decision=Ready enabled=on paused=false profile=green
2026-05-12T20:00:04Z focused-text-poll-latency-summary count=60 maxMilliseconds=5
2026-05-12T20:00:05Z focused-text-poll-latency-summary count=60 maxMilliseconds=5
2026-05-12T20:00:06Z focused-text-poll-latency-summary count=60 maxMilliseconds=5
LOG

AUTOCOMPLETE_LAB_LOG="$LOG_PATH" \
  AUTOCOMPLETE_LAB_LOG_LINES=2 \
  AUTOCOMPLETE_LAB_REQUIRE_READY=1 \
  AUTOCOMPLETE_LAB_EXPECTED_ASSET=Qwen3.5-4B-4bit \
  ./script/check_diagnostics_log.sh >/dev/null

cat >"$LOG_PATH" <<'LOG'
2026-05-12T20:00:00Z launch accessibility=true
2026-05-12T20:00:00Z runtime-bootstrap activeCandidate=mlx allowsUserManagedServer=false asset=Qwen3.5-4B-4bit nativeRuntimeAvailable=true preferredCandidate=mlx
2026-05-12T20:00:01Z runtime-resource-sample cpuPercent=0.0 reason=launch rssMB=3000
2026-05-12T20:00:02Z runtime-warm-succeeded candidate=mlx state=ready (MLX)
2026-05-12T20:00:02Z runtime readinessAction=none readinessStage=ready state=ready (MLX)
LOG

AUTOCOMPLETE_LAB_LOG="$LOG_PATH" \
  AUTOCOMPLETE_LAB_REQUIRE_READY=1 \
  AUTOCOMPLETE_LAB_EXPECTED_ASSET=Qwen3.5-4B-4bit \
  ./script/check_diagnostics_log.sh >/dev/null

cat >"$LOG_PATH" <<'LOG'
2026-05-12T20:00:00Z launch accessibility=true
2026-05-12T20:00:00Z runtime-bootstrap activeCandidate=mock allowsUserManagedServer=false asset=Qwen3.5-4B-4bit nativeRuntimeAvailable=true preferredCandidate=mlx fallbackReason=missing model
2026-05-12T20:00:01Z runtime-warm-succeeded candidate=mock state=ready (mock)
2026-05-12T20:00:02Z runtime readinessAction=none readinessStage=ready state=ready (MLX)
2026-05-12T20:00:03Z status accessibility=AX ok app=TextEdit control=running decision=Ready enabled=on paused=false profile=green
LOG

if AUTOCOMPLETE_LAB_LOG="$LOG_PATH" \
  AUTOCOMPLETE_LAB_REQUIRE_READY=1 \
  AUTOCOMPLETE_LAB_EXPECTED_ASSET=Qwen3.5-4B-4bit \
  ./script/check_diagnostics_log.sh >/dev/null 2>&1; then
  echo "diagnostics self-test failed: mock fallback passed the ready gate" >&2
  exit 1
fi

echo "Diagnostics log self-test passed."
