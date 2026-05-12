#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

LOG_PATH="$TMP_DIR/diagnostics.log"

cat >"$LOG_PATH" <<'EOF'
2026-05-06T10:00:00Z launch accessibility=trusted
2026-05-06T10:00:01Z keyboard-event-tap-latency decision=consume durationMicros=410 key=tab
2026-05-06T10:00:02Z keyboard-event-tap-latency decision=passthrough durationMicros=620 key=escape
2026-05-06T10:00:03Z keyboard-event-tap-latency-summary count=3 maxMicros=900 p50Micros=500 p90Micros=900 p95Micros=900 p99Micros=900 reason=stop
2026-05-06T10:00:04Z focused-text-poll-latency-summary count=3 maxMilliseconds=12 p50Milliseconds=4 p90Milliseconds=12 p95Milliseconds=12 p99Milliseconds=12
EOF

AUTOCOMPLETE_LAB_LOG="$LOG_PATH" \
AUTOCOMPLETE_LAB_TYPING_PERF_REQUIRE_SAMPLES=3 \
AUTOCOMPLETE_LAB_FOCUSED_TEXT_POLL_REQUIRE_SAMPLES=3 \
  script/check_typing_performance_log.sh >"$TMP_DIR/pass.txt"

if ! grep -F "Raw event tap latency: n=2" "$TMP_DIR/pass.txt" >/dev/null; then
  echo "typing performance self-test did not summarize raw latency samples" >&2
  cat "$TMP_DIR/pass.txt" >&2
  exit 1
fi

if ! grep -F "Line limit: last 5000 non-empty line(s)" "$TMP_DIR/pass.txt" >/dev/null; then
  echo "typing performance self-test did not report the default recent line window" >&2
  cat "$TMP_DIR/pass.txt" >&2
  exit 1
fi

if ! grep -F "Latency summary windows: n=1 samples=3" "$TMP_DIR/pass.txt" >/dev/null; then
  echo "typing performance self-test did not summarize latency windows" >&2
  cat "$TMP_DIR/pass.txt" >&2
  exit 1
fi
if ! grep -F "Summary p90 max: 900us" "$TMP_DIR/pass.txt" >/dev/null; then
  echo "typing performance self-test did not summarize event-tap p90 windows" >&2
  cat "$TMP_DIR/pass.txt" >&2
  exit 1
fi


if ! grep -F "Typing performance log verified." "$TMP_DIR/pass.txt" >/dev/null; then
  echo "typing performance self-test did not pass the good log" >&2
  cat "$TMP_DIR/pass.txt" >&2
  exit 1
fi

if ! grep -F "Focused text poll windows: n=1 samples=3" "$TMP_DIR/pass.txt" >/dev/null; then
  echo "typing performance self-test did not summarize focused text poll windows" >&2
  cat "$TMP_DIR/pass.txt" >&2
  exit 1
fi
if ! grep -F "Focused text poll p99 max: 12ms" "$TMP_DIR/pass.txt" >/dev/null; then
  echo "typing performance self-test did not summarize focused-text poll p99 windows" >&2
  cat "$TMP_DIR/pass.txt" >&2
  exit 1
fi


if ! grep -F "Focused text poll skipped: events=0 eventSkipped=0 summarySkipped=0 evidence=0" "$TMP_DIR/pass.txt" >/dev/null; then
  echo "typing performance self-test did not summarize focused-text poll skips" >&2
  cat "$TMP_DIR/pass.txt" >&2
  exit 1
fi

cat >"$LOG_PATH" <<'EOF'
2026-05-06T10:00:00Z keyboard-event-tap-latency decision=consume durationMicros=500 key=tab
EOF

if AUTOCOMPLETE_LAB_LOG="$LOG_PATH" \
   AUTOCOMPLETE_LAB_FOCUSED_TEXT_POLL_REQUIRE_SAMPLES=1 \
   script/check_typing_performance_log.sh >"$TMP_DIR/poll-required-fail.txt" 2>&1; then
  echo "typing performance self-test expected missing focused-text poll samples to fail" >&2
  cat "$TMP_DIR/poll-required-fail.txt" >&2
  exit 1
fi

if ! grep -F "expected at least 1 focused text poll latency samples, found 0" "$TMP_DIR/poll-required-fail.txt" >/dev/null; then
  echo "typing performance self-test did not explain missing focused-text poll samples" >&2
  cat "$TMP_DIR/poll-required-fail.txt" >&2
  exit 1
fi

cat >"$LOG_PATH" <<'EOF'
2026-05-06T10:00:00Z keyboard-event-tap-latency decision=consume durationMicros=fast key=tab
2026-05-06T10:00:01Z keyboard-event-tap-latency-summary count=3 maxMicros=900 p50Micros=500 reason=stop
2026-05-06T10:00:02Z focused-text-poll-latency-summary count=3 maxMilliseconds=12 p50Milliseconds=4
2026-05-06T10:00:03Z focused-text-poll-skip-summary reason=in-flight durationMilliseconds=10
2026-05-06T10:00:04Z focused-text-poll-skipped reason=in-flight count=many
EOF

if AUTOCOMPLETE_LAB_LOG="$LOG_PATH" script/check_typing_performance_log.sh >"$TMP_DIR/malformed.txt" 2>&1; then
  echo "typing performance self-test expected malformed latency diagnostics to fail" >&2
  cat "$TMP_DIR/malformed.txt" >&2
  exit 1
fi

if ! grep -F "keyboard-event-tap-latency invalid durationMicros=fast" "$TMP_DIR/malformed.txt" >/dev/null; then
  echo "typing performance self-test did not catch invalid raw latency diagnostics" >&2
  cat "$TMP_DIR/malformed.txt" >&2
  exit 1
fi

if ! grep -F "keyboard-event-tap-latency-summary missing p95Micros" "$TMP_DIR/malformed.txt" >/dev/null; then
  echo "typing performance self-test did not catch malformed event-tap summaries" >&2
  cat "$TMP_DIR/malformed.txt" >&2
  exit 1
fi

if ! grep -F "focused-text-poll-latency-summary missing p95Milliseconds" "$TMP_DIR/malformed.txt" >/dev/null; then
  echo "typing performance self-test did not catch malformed focused-text poll summaries" >&2
  cat "$TMP_DIR/malformed.txt" >&2
  exit 1
fi

if ! grep -F "focused-text-poll-skip-summary missing count" "$TMP_DIR/malformed.txt" >/dev/null; then
  echo "typing performance self-test did not catch malformed focused-text poll skip summaries" >&2
  cat "$TMP_DIR/malformed.txt" >&2
  exit 1
fi

if ! grep -F "focused-text-poll-skipped invalid count=many" "$TMP_DIR/malformed.txt" >/dev/null; then
  echo "typing performance self-test did not catch malformed focused-text poll skip events" >&2
  cat "$TMP_DIR/malformed.txt" >&2
  exit 1
fi

cat >"$LOG_PATH" <<'EOF'
2026-05-06T10:00:00Z keyboard-event-tap-latency decision=consume durationMicros=1200 key=tab
2026-05-06T10:00:01Z keyboard-event-tap-latency-slow decision=consume durationMicros=9100 key=tab
EOF

if AUTOCOMPLETE_LAB_LOG="$LOG_PATH" script/check_typing_performance_log.sh >"$TMP_DIR/slow.txt" 2>&1; then
  echo "typing performance self-test expected slow markers to fail" >&2
  cat "$TMP_DIR/slow.txt" >&2
  exit 1
fi

if ! grep -F "slow event tap latency marker 9100us" "$TMP_DIR/slow.txt" >/dev/null; then
  echo "typing performance self-test did not explain slow latency markers" >&2
  cat "$TMP_DIR/slow.txt" >&2
  exit 1
fi

cat >"$LOG_PATH" <<'EOF'
2026-05-06T10:00:00Z keyboard-event-tap-latency-summary count=100 maxMicros=11000 p50Micros=600 p95Micros=9000 p99Micros=10500 reason=sample-window
EOF

if AUTOCOMPLETE_LAB_LOG="$LOG_PATH" script/check_typing_performance_log.sh >"$TMP_DIR/summary-fail.txt" 2>&1; then
  echo "typing performance self-test expected slow summaries to fail" >&2
  cat "$TMP_DIR/summary-fail.txt" >&2
  exit 1
fi

if ! grep -F "event tap p95 9000us exceeds 8000us" "$TMP_DIR/summary-fail.txt" >/dev/null; then
  echo "typing performance self-test did not catch slow p95 summaries" >&2
  cat "$TMP_DIR/summary-fail.txt" >&2
  exit 1
fi

if ! grep -F "event tap max 11000us exceeds 8000us" "$TMP_DIR/summary-fail.txt" >/dev/null; then
  echo "typing performance self-test did not catch slow max summaries" >&2
  cat "$TMP_DIR/summary-fail.txt" >&2
  exit 1
fi

cat >"$LOG_PATH" <<'EOF'
2026-05-06T10:00:00Z focused-text-poll-latency-summary count=60 maxMilliseconds=140 p50Milliseconds=12 p95Milliseconds=90
EOF

AUTOCOMPLETE_LAB_LOG="$LOG_PATH" script/check_typing_performance_log.sh >"$TMP_DIR/poll-summary-warn.txt"

if ! grep -F "focused text poll p95 90ms exceeds 80ms" "$TMP_DIR/poll-summary-warn.txt" >/dev/null; then
  echo "typing performance self-test did not warn on slow focused-text poll p95 summaries" >&2
  cat "$TMP_DIR/poll-summary-warn.txt" >&2
  exit 1
fi

if ! grep -F "focused text poll max 140ms exceeds 120ms" "$TMP_DIR/poll-summary-warn.txt" >/dev/null; then
  echo "typing performance self-test did not warn on slow focused-text poll max summaries" >&2
  cat "$TMP_DIR/poll-summary-warn.txt" >&2
  exit 1
fi

if ! grep -F "Typing performance log verified." "$TMP_DIR/poll-summary-warn.txt" >/dev/null; then
  echo "typing performance self-test should not fail normal typing on off-main focused-text poll warnings by default" >&2
  cat "$TMP_DIR/poll-summary-warn.txt" >&2
  exit 1
fi

if AUTOCOMPLETE_LAB_LOG="$LOG_PATH" \
   AUTOCOMPLETE_LAB_TYPING_PERF_FAIL_ON_FOCUSED_POLL=1 \
   script/check_typing_performance_log.sh >"$TMP_DIR/poll-summary-fail.txt" 2>&1; then
  echo "typing performance self-test expected strict focused-text poll summaries to fail" >&2
  cat "$TMP_DIR/poll-summary-fail.txt" >&2
  exit 1
fi

cat >"$LOG_PATH" <<'EOF'
2026-05-06T10:00:00Z focused-text-poll-latency-slow durationMilliseconds=130
EOF

AUTOCOMPLETE_LAB_LOG="$LOG_PATH" script/check_typing_performance_log.sh >"$TMP_DIR/poll-marker-warn.txt"

if ! grep -F "slow focused text poll marker 130ms" "$TMP_DIR/poll-marker-warn.txt" >/dev/null; then
  echo "typing performance self-test did not warn on slow focused-text poll markers" >&2
  cat "$TMP_DIR/poll-marker-warn.txt" >&2
  exit 1
fi

if AUTOCOMPLETE_LAB_LOG="$LOG_PATH" \
   AUTOCOMPLETE_LAB_TYPING_PERF_FAIL_ON_FOCUSED_POLL=1 \
   script/check_typing_performance_log.sh >"$TMP_DIR/poll-marker-fail.txt" 2>&1; then
  echo "typing performance self-test expected strict slow focused-text poll markers to fail" >&2
  cat "$TMP_DIR/poll-marker-fail.txt" >&2
  exit 1
fi

cat >"$LOG_PATH" <<'EOF'
2026-05-06T10:00:00Z focused-text-poll-skipped reason=in-flight count=1
2026-05-06T10:00:01Z focused-text-poll-skip-summary reason=in-flight count=3 durationMilliseconds=110
EOF

AUTOCOMPLETE_LAB_LOG="$LOG_PATH" script/check_typing_performance_log.sh >"$TMP_DIR/poll-skip-warn.txt"

if ! grep -F "focused text poll skipped 3 time(s) exceeds 0" "$TMP_DIR/poll-skip-warn.txt" >/dev/null; then
  echo "typing performance self-test did not warn on focused-text poll skips" >&2
  cat "$TMP_DIR/poll-skip-warn.txt" >&2
  exit 1
fi

if ! grep -F "focused text poll skip summary reason=in-flight count=3 duration=110ms" "$TMP_DIR/poll-skip-warn.txt" >/dev/null; then
  echo "typing performance self-test did not report focused-text poll skip summaries" >&2
  cat "$TMP_DIR/poll-skip-warn.txt" >&2
  exit 1
fi

if AUTOCOMPLETE_LAB_LOG="$LOG_PATH" \
   AUTOCOMPLETE_LAB_TYPING_PERF_FAIL_ON_FOCUSED_POLL=1 \
   script/check_typing_performance_log.sh >"$TMP_DIR/poll-skip-fail.txt" 2>&1; then
  echo "typing performance self-test expected strict focused-text poll skips to fail" >&2
  cat "$TMP_DIR/poll-skip-fail.txt" >&2
  exit 1
fi

cat >"$LOG_PATH" <<'EOF'
2026-05-06T10:00:00Z keyboard-event-tap-disabled reason=timeout
EOF

if AUTOCOMPLETE_LAB_LOG="$LOG_PATH" script/check_typing_performance_log.sh >"$TMP_DIR/disabled-timeout.txt" 2>&1; then
  echo "typing performance self-test expected timeout disables to fail" >&2
  cat "$TMP_DIR/disabled-timeout.txt" >&2
  exit 1
fi

if ! grep -F "event tap disabled reason=timeout" "$TMP_DIR/disabled-timeout.txt" >/dev/null; then
  echo "typing performance self-test did not catch timeout disables" >&2
  cat "$TMP_DIR/disabled-timeout.txt" >&2
  exit 1
fi

cat >"$LOG_PATH" <<'EOF'
2026-05-06T10:00:00Z keyboard-event-tap-disabled reason=user-input
EOF

if AUTOCOMPLETE_LAB_LOG="$LOG_PATH" script/check_typing_performance_log.sh >"$TMP_DIR/disabled-user-input.txt" 2>&1; then
  echo "typing performance self-test expected user-input disables to fail" >&2
  cat "$TMP_DIR/disabled-user-input.txt" >&2
  exit 1
fi

if ! grep -F "event tap disabled reason=user-input" "$TMP_DIR/disabled-user-input.txt" >/dev/null; then
  echo "typing performance self-test did not catch user-input disables" >&2
  cat "$TMP_DIR/disabled-user-input.txt" >&2
  exit 1
fi

cat >"$LOG_PATH" <<'EOF'
2026-05-06T10:00:00Z keyboard-event-tap-start-failed
EOF

if AUTOCOMPLETE_LAB_LOG="$LOG_PATH" script/check_typing_performance_log.sh >"$TMP_DIR/start-failed.txt" 2>&1; then
  echo "typing performance self-test expected event-tap start failure to fail" >&2
  cat "$TMP_DIR/start-failed.txt" >&2
  exit 1
fi

if ! grep -F "event tap start failed reason=unknown" "$TMP_DIR/start-failed.txt" >/dev/null; then
  echo "typing performance self-test did not catch event-tap start failure" >&2
  cat "$TMP_DIR/start-failed.txt" >&2
  exit 1
fi

cat >"$LOG_PATH" <<'EOF'
2026-05-06T10:00:00Z keyboard-event-tap-failed-closed reason=timeout
EOF

if AUTOCOMPLETE_LAB_LOG="$LOG_PATH" script/check_typing_performance_log.sh >"$TMP_DIR/failed-closed.txt" 2>&1; then
  echo "typing performance self-test expected event-tap failed-closed marker to fail" >&2
  cat "$TMP_DIR/failed-closed.txt" >&2
  exit 1
fi

if ! grep -F "event tap failed closed reason=timeout" "$TMP_DIR/failed-closed.txt" >/dev/null; then
  echo "typing performance self-test did not catch event-tap failed-closed marker" >&2
  cat "$TMP_DIR/failed-closed.txt" >&2
  exit 1
fi

cat >"$LOG_PATH" <<'EOF'
2026-05-06T10:00:00Z keyboard-event-tap-latency decision=consume durationMicros=70 key=tab
2026-05-06T10:00:00Z keyboard-event-tap-replayed-captured-key key=tab reason=focus-changed diagnosticLayer=keyCapture safetyFailure=false
2026-05-06T10:00:01Z focused-text-poll-latency-summary count=60 maxMilliseconds=140 p50Milliseconds=12 p95Milliseconds=90
EOF

AUTOCOMPLETE_LAB_LOG="$LOG_PATH" script/check_typing_performance_log.sh >"$TMP_DIR/replayed-captured-key.txt"

if ! grep -F "Captured key recovery events: replayed=1 dropped=0" "$TMP_DIR/replayed-captured-key.txt" >/dev/null; then
  echo "typing performance self-test did not summarize replayed captured keys" >&2
  cat "$TMP_DIR/replayed-captured-key.txt" >&2
  exit 1
fi

if ! grep -F "focused text poll p95 90ms exceeds 80ms" "$TMP_DIR/replayed-captured-key.txt" >/dev/null; then
  echo "typing performance self-test did not keep AX warnings separate from replayed captured keys" >&2
  cat "$TMP_DIR/replayed-captured-key.txt" >&2
  exit 1
fi

if ! grep -F "Typing performance log verified." "$TMP_DIR/replayed-captured-key.txt" >/dev/null; then
  echo "typing performance self-test should pass replayed captured keys" >&2
  cat "$TMP_DIR/replayed-captured-key.txt" >&2
  exit 1
fi

cat >"$LOG_PATH" <<'EOF'
2026-05-06T10:00:00Z keyboard-event-tap-latency decision=consume durationMicros=70 key=tab
2026-05-06T10:00:00Z keyboard-event-tap-unhandled-consumed-key-dropped key=tab reason=acceptance-proof-failed diagnosticLayer=keyCapture safetyFailure=true
EOF

if AUTOCOMPLETE_LAB_LOG="$LOG_PATH" script/check_typing_performance_log.sh >"$TMP_DIR/dropped-captured-key.txt" 2>&1; then
  echo "typing performance self-test expected dropped captured keys to fail" >&2
  cat "$TMP_DIR/dropped-captured-key.txt" >&2
  exit 1
fi

if ! grep -F "captured key dropped key=tab reason=acceptance-proof-failed" "$TMP_DIR/dropped-captured-key.txt" >/dev/null; then
  echo "typing performance self-test did not catch dropped captured keys" >&2
  cat "$TMP_DIR/dropped-captured-key.txt" >&2
  exit 1
fi

cat >"$LOG_PATH" <<'EOF'
2026-05-06T10:00:00Z keyboard-event-tap-disabled reason=timeout
2026-05-06T10:00:01Z keyboard-event-tap-latency decision=consume durationMicros=500 key=tab
EOF

AUTOCOMPLETE_LAB_LOG="$LOG_PATH" \
AUTOCOMPLETE_LAB_LOG_START_LINE=1 \
AUTOCOMPLETE_LAB_TYPING_PERF_REQUIRE_SAMPLES=1 \
  script/check_typing_performance_log.sh >"$TMP_DIR/sliced-pass.txt"

if ! grep -F "Start line: 1" "$TMP_DIR/sliced-pass.txt" >/dev/null; then
  echo "typing performance self-test did not honor AUTOCOMPLETE_LAB_LOG_START_LINE" >&2
  cat "$TMP_DIR/sliced-pass.txt" >&2
  exit 1
fi

{
  echo "2026-05-06T09:00:00Z keyboard-event-tap-latency-slow decision=consume durationMicros=9100 key=tab"
  for index in $(seq 1 5000); do
    echo "2026-05-06T09:00:00Z filler index=$index"
  done
  echo "2026-05-06T10:00:00Z keyboard-event-tap-latency decision=consume durationMicros=500 key=tab"
} >"$LOG_PATH"

AUTOCOMPLETE_LAB_LOG="$LOG_PATH" \
AUTOCOMPLETE_LAB_TYPING_PERF_REQUIRE_SAMPLES=1 \
  script/check_typing_performance_log.sh >"$TMP_DIR/recent-window-pass.txt"

if ! grep -F "Scanned lines: 5000" "$TMP_DIR/recent-window-pass.txt" >/dev/null; then
  echo "typing performance self-test did not bound the default recent line window" >&2
  cat "$TMP_DIR/recent-window-pass.txt" >&2
  exit 1
fi

if ! grep -F "Typing performance log verified." "$TMP_DIR/recent-window-pass.txt" >/dev/null; then
  echo "typing performance self-test did not ignore old historical latency outside the recent window" >&2
  cat "$TMP_DIR/recent-window-pass.txt" >&2
  exit 1
fi

if AUTOCOMPLETE_LAB_LOG="$LOG_PATH" \
   AUTOCOMPLETE_LAB_TYPING_PERF_LOG_LINES=0 \
   AUTOCOMPLETE_LAB_TYPING_PERF_REQUIRE_SAMPLES=1 \
   script/check_typing_performance_log.sh >"$TMP_DIR/all-history-fail.txt" 2>&1; then
  echo "typing performance self-test expected all-history override to include old slow latency" >&2
  cat "$TMP_DIR/all-history-fail.txt" >&2
  exit 1
fi

if ! grep -F "Line limit: all history after start line" "$TMP_DIR/all-history-fail.txt" >/dev/null; then
  echo "typing performance self-test did not report all-history mode" >&2
  cat "$TMP_DIR/all-history-fail.txt" >&2
  exit 1
fi

if ! grep -F "slow event tap latency marker 9100us" "$TMP_DIR/all-history-fail.txt" >/dev/null; then
  echo "typing performance self-test did not let the all-history override catch old slow latency" >&2
  cat "$TMP_DIR/all-history-fail.txt" >&2
  exit 1
fi

echo "Typing performance log self-test passed."
