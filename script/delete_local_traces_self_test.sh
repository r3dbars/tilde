#!/usr/bin/env bash
set -euo pipefail

TRACE_FOLDER="$(mktemp -d)"
STATE_FOLDER="$(mktemp -d)"
trap 'rm -rf "$TRACE_FOLDER" "$STATE_FOLDER"' EXIT

mkdir -p "$TRACE_FOLDER/screenshots"
mkdir -p "$TRACE_FOLDER/privacy-export"
printf '{}\n' >"$TRACE_FOLDER/traces.jsonl"
printf '{}\n' >"$TRACE_FOLDER/raw-traces.jsonl"
printf 'diagnostics\n' >"$TRACE_FOLDER/diagnostics.log"
printf '<html></html>\n' >"$TRACE_FOLDER/trace-report.html"
printf '[]\n' >"$TRACE_FOLDER/survival-report.json"
printf 'png\n' >"$TRACE_FOLDER/screenshots/sample.txt"
printf '{}\n' >"$TRACE_FOLDER/privacy-export/manifest.json"
printf '{}\n' >"$STATE_FOLDER/compatibility-learning.json"

AUTOCOMPLETE_LAB_TRACE_FOLDER="$TRACE_FOLDER" \
AUTOCOMPLETE_LAB_STATE_FOLDER="$STATE_FOLDER" \
  script/delete_local_traces.sh >/tmp/autocomplete-delete-local-traces-self-test.txt

for path in \
  "$TRACE_FOLDER/traces.jsonl" \
  "$TRACE_FOLDER/raw-traces.jsonl" \
  "$TRACE_FOLDER/diagnostics.log" \
  "$TRACE_FOLDER/trace-report.html" \
  "$TRACE_FOLDER/survival-report.json" \
  "$TRACE_FOLDER/privacy-export" \
  "$TRACE_FOLDER/screenshots" \
  "$STATE_FOLDER/compatibility-learning.json"; do
  if [[ -e "$path" ]]; then
    echo "delete local traces self-test left $path behind" >&2
    exit 1
  fi
done

if ! grep -F "Deleted SteadyType local traces:" /tmp/autocomplete-delete-local-traces-self-test.txt >/dev/null; then
  echo "delete local traces self-test did not print confirmation" >&2
  cat /tmp/autocomplete-delete-local-traces-self-test.txt >&2
  exit 1
fi

echo "Delete local traces self-test passed."
