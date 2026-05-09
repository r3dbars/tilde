#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

PASS_LOG="$TMP_DIR/pass-diagnostics.log"
MOCK_LOG="$TMP_DIR/mock-diagnostics.log"
WRONG_ASSET_LOG="$TMP_DIR/wrong-asset-diagnostics.log"

cat >"$PASS_LOG" <<'LOG'
2026-05-09T00:00:00Z launch accessibility=true
2026-05-09T00:00:00Z launch-health crashOrForceQuitSuspected=false launchID=test previousExit=clean-or-first-launch relaunch=false
2026-05-09T00:00:00Z runtime-bootstrap activeCandidate=mlx allowsUserManagedServer=false asset=Qwen3.5-4B-4bit nativeRuntimeAvailable=true preferredCandidate=mlx
2026-05-09T00:00:00Z runtime-warm-start candidate=mlx modelDirectory=/tmp/model warmID=1
2026-05-09T00:00:01Z runtime-warm-succeeded candidate=mlx durationMilliseconds=900 state=ready (MLX) warmID=1
2026-05-09T00:00:01Z runtime completionLength=3 words / 9 tokens readinessAction=none readinessStage=ready state=ready (MLX)
2026-05-09T00:00:02Z status accessibility=AX ok app=TextEdit control=running decision=Ready enabled=on paused=false profile=green
2026-05-09T00:00:03Z focused-text-context-missing app=Codex diagnostics=unavailable
2026-05-09T00:00:04Z focused-text-context-missing app=Codex diagnostics=unavailable
LOG

AUTOCOMPLETE_LAB_LOG="$PASS_LOG" \
AUTOCOMPLETE_LAB_LOG_LINES=2 \
AUTOCOMPLETE_LAB_REQUIRE_READY=1 \
AUTOCOMPLETE_LAB_EXPECTED_ASSET="Qwen3.5-4B-4bit" \
  ./script/check_diagnostics_log.sh >"$TMP_DIR/pass.txt"

if ! grep -F "Diagnostics log verified" "$TMP_DIR/pass.txt" >/dev/null; then
  echo "diagnostics self-test did not pass a busy latest-launch log" >&2
  cat "$TMP_DIR/pass.txt" >&2
  exit 1
fi

cat >"$MOCK_LOG" <<'LOG'
2026-05-09T00:00:00Z launch accessibility=true
2026-05-09T00:00:00Z launch-health crashOrForceQuitSuspected=false launchID=test previousExit=clean-or-first-launch relaunch=false
2026-05-09T00:00:00Z runtime-bootstrap activeCandidate=mock allowsUserManagedServer=false asset=Qwen3.5-4B-4bit fallbackReason=missing-model nativeRuntimeAvailable=true preferredCandidate=mlx
2026-05-09T00:00:01Z runtime-warm-succeeded candidate=mock state=ready (mock)
2026-05-09T00:00:01Z runtime completionLength=3 words / 9 tokens readinessAction=none readinessStage=ready state=ready (mock)
2026-05-09T00:00:02Z status accessibility=AX ok app=TextEdit control=running decision=Ready enabled=on paused=false profile=green
LOG

if AUTOCOMPLETE_LAB_LOG="$MOCK_LOG" \
  AUTOCOMPLETE_LAB_REQUIRE_READY=1 \
  AUTOCOMPLETE_LAB_READY_TIMEOUT_SECONDS=1 \
  AUTOCOMPLETE_LAB_EXPECTED_ASSET="Qwen3.5-4B-4bit" \
  ./script/check_diagnostics_log.sh >"$TMP_DIR/mock.txt" 2>&1; then
  echo "diagnostics self-test expected mock fallback to fail" >&2
  exit 1
fi

if ! grep -F "missing latest-launch diagnostics pattern: activeCandidate=mlx" "$TMP_DIR/mock.txt" >/dev/null; then
  echo "diagnostics self-test did not reject mock fallback clearly" >&2
  cat "$TMP_DIR/mock.txt" >&2
  exit 1
fi

cat >"$WRONG_ASSET_LOG" <<'LOG'
2026-05-09T00:00:00Z launch accessibility=true
2026-05-09T00:00:00Z launch-health crashOrForceQuitSuspected=false launchID=test previousExit=clean-or-first-launch relaunch=false
2026-05-09T00:00:00Z runtime-bootstrap activeCandidate=mlx allowsUserManagedServer=false asset=qwen3-0.6b-4bit nativeRuntimeAvailable=true preferredCandidate=mlx
2026-05-09T00:00:01Z runtime-warm-succeeded candidate=mlx state=ready (MLX)
2026-05-09T00:00:01Z runtime completionLength=3 words / 9 tokens readinessAction=none readinessStage=ready state=ready (MLX)
2026-05-09T00:00:02Z status accessibility=AX ok app=TextEdit control=running decision=Ready enabled=on paused=false profile=green
LOG

if AUTOCOMPLETE_LAB_LOG="$WRONG_ASSET_LOG" \
  AUTOCOMPLETE_LAB_REQUIRE_READY=1 \
  AUTOCOMPLETE_LAB_EXPECTED_ASSET="Qwen3.5-4B-4bit" \
  ./script/check_diagnostics_log.sh >"$TMP_DIR/wrong-asset.txt" 2>&1; then
  echo "diagnostics self-test expected wrong asset to fail" >&2
  exit 1
fi

if ! grep -F "missing latest-launch diagnostics pattern: asset=Qwen3.5-4B-4bit" "$TMP_DIR/wrong-asset.txt" >/dev/null; then
  echo "diagnostics self-test did not reject the wrong model asset" >&2
  cat "$TMP_DIR/wrong-asset.txt" >&2
  exit 1
fi

echo "Diagnostics log self-test passed."
