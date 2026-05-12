#!/usr/bin/env bash
set -euo pipefail

TRACE_FOLDER="$(mktemp -d)"
STATE_FOLDER="$(mktemp -d)"
MISSING_TRACE_FOLDER="$(mktemp -d)/missing-traces"
MISSING_STATE_FOLDER="$(mktemp -d)/missing-state"
FAKE_HOME="$(mktemp -d)"
OUTPUT_FILE="$(mktemp)"
SYMLINK_TARGET="$(mktemp -d)"
trap 'rm -rf "$TRACE_FOLDER" "$STATE_FOLDER" "$(dirname "$MISSING_TRACE_FOLDER")" "$(dirname "$MISSING_STATE_FOLDER")" "$FAKE_HOME" "$OUTPUT_FILE" "$OUTPUT_FILE.unsafe" "$OUTPUT_FILE.unsafe-docs" "$OUTPUT_FILE.unsafe-other" "$SYMLINK_TARGET"' EXIT

mkdir -p "$TRACE_FOLDER/screenshots"
printf 'keep\n' >"$SYMLINK_TARGET/sentinel.txt"
ln -s "$SYMLINK_TARGET" "$TRACE_FOLDER/privacy-export"
printf '{}\n' >"$TRACE_FOLDER/traces.jsonl"
printf '{}\n' >"$TRACE_FOLDER/raw-traces.jsonl"
printf 'diagnostics\n' >"$TRACE_FOLDER/diagnostics.log"
printf '<html></html>\n' >"$TRACE_FOLDER/trace-report.html"
printf '[]\n' >"$TRACE_FOLDER/survival-report.json"
printf '{"acceptedText":"private"}\n' >"$TRACE_FOLDER/survival-inspector-debug.json"
printf 'png\n' >"$TRACE_FOLDER/screenshots/sample.txt"
printf '{}\n' >"$STATE_FOLDER/compatibility-learning.json"

AUTOCOMPLETE_LAB_TRACE_FOLDER="$TRACE_FOLDER" \
AUTOCOMPLETE_LAB_STATE_FOLDER="$STATE_FOLDER" \
  script/delete_local_traces.sh >"$OUTPUT_FILE"

for path in \
  "$TRACE_FOLDER/traces.jsonl" \
  "$TRACE_FOLDER/raw-traces.jsonl" \
  "$TRACE_FOLDER/diagnostics.log" \
  "$TRACE_FOLDER/trace-report.html" \
  "$TRACE_FOLDER/survival-report.json" \
  "$TRACE_FOLDER/survival-inspector-debug.json" \
  "$TRACE_FOLDER/privacy-export" \
  "$TRACE_FOLDER/screenshots" \
  "$STATE_FOLDER/compatibility-learning.json"; do
  if [[ -e "$path" ]]; then
    echo "delete local traces self-test left $path behind" >&2
    exit 1
  fi
done

if [[ ! -f "$SYMLINK_TARGET/sentinel.txt" ]]; then
  echo "delete local traces self-test followed a symlinked trace folder" >&2
  exit 1
fi

AUTOCOMPLETE_LAB_TRACE_FOLDER="$MISSING_TRACE_FOLDER" \
AUTOCOMPLETE_LAB_STATE_FOLDER="$MISSING_STATE_FOLDER" \
  script/delete_local_traces.sh >>"$OUTPUT_FILE"

mkdir -p "$FAKE_HOME"
printf 'do-not-delete\n' >"$FAKE_HOME/traces.jsonl"
if HOME="$FAKE_HOME" \
  AUTOCOMPLETE_LAB_TRACE_FOLDER="$FAKE_HOME" \
  AUTOCOMPLETE_LAB_STATE_FOLDER="$STATE_FOLDER" \
  script/delete_local_traces.sh >>"$OUTPUT_FILE" 2>"$OUTPUT_FILE.unsafe"; then
  echo "delete local traces self-test allowed an unsafe home folder" >&2
  exit 1
fi

if [[ ! -f "$FAKE_HOME/traces.jsonl" ]]; then
  echo "delete local traces self-test deleted from an unsafe home folder" >&2
  exit 1
fi

if ! grep -F "refusing to delete log traces from broad folder:" "$OUTPUT_FILE.unsafe" >/dev/null; then
  echo "delete local traces self-test did not explain unsafe folder refusal" >&2
  cat "$OUTPUT_FILE.unsafe" >&2
  exit 1
fi

mkdir -p "$FAKE_HOME/Documents/SteadyType-looking" "$FAKE_HOME/Library/Logs/OtherApp"
printf 'do-not-delete\n' >"$FAKE_HOME/Documents/SteadyType-looking/traces.jsonl"
printf 'do-not-delete\n' >"$FAKE_HOME/Library/Logs/OtherApp/traces.jsonl"

if HOME="$FAKE_HOME" \
  AUTOCOMPLETE_LAB_TRACE_FOLDER="$FAKE_HOME/Documents/SteadyType-looking" \
  AUTOCOMPLETE_LAB_STATE_FOLDER="$STATE_FOLDER" \
  script/delete_local_traces.sh >>"$OUTPUT_FILE" 2>"$OUTPUT_FILE.unsafe-docs"; then
  echo "delete local traces self-test allowed a non-app Documents folder" >&2
  exit 1
fi

if HOME="$FAKE_HOME" \
  AUTOCOMPLETE_LAB_TRACE_FOLDER="$FAKE_HOME/Library/Logs/OtherApp" \
  AUTOCOMPLETE_LAB_STATE_FOLDER="$STATE_FOLDER" \
  script/delete_local_traces.sh >>"$OUTPUT_FILE" 2>"$OUTPUT_FILE.unsafe-other"; then
  echo "delete local traces self-test allowed another app log folder" >&2
  exit 1
fi

if [[ ! -f "$FAKE_HOME/Documents/SteadyType-looking/traces.jsonl" ||
      ! -f "$FAKE_HOME/Library/Logs/OtherApp/traces.jsonl" ]]; then
  echo "delete local traces self-test deleted from a non-app-owned folder" >&2
  exit 1
fi

if ! grep -F "Deleted SteadyType local traces:" "$OUTPUT_FILE" >/dev/null; then
  echo "delete local traces self-test did not print confirmation" >&2
  cat "$OUTPUT_FILE" >&2
  exit 1
fi

echo "Delete local traces self-test passed."
