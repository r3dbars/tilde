#!/usr/bin/env bash
set -euo pipefail

TRACE_FOLDER="${AUTOCOMPLETE_LAB_TRACE_FOLDER:-$HOME/Library/Logs/SteadyType}"
STATE_FOLDER="${AUTOCOMPLETE_LAB_STATE_FOLDER:-$HOME/Library/Application Support/SteadyType}"

rm -f "$TRACE_FOLDER/traces.jsonl"
rm -f "$TRACE_FOLDER/raw-traces.jsonl"
rm -f "$TRACE_FOLDER/trace-report.html"
rm -f "$TRACE_FOLDER/survival-report.json"
rm -rf "$TRACE_FOLDER/privacy-export"
rm -rf "$TRACE_FOLDER/screenshots"
rm -f "$STATE_FOLDER/compatibility-learning.json"

echo "Deleted SteadyType local traces: $TRACE_FOLDER"
