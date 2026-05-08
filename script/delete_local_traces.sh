#!/usr/bin/env bash
set -euo pipefail

TRACE_FOLDER="${AUTOCOMPLETE_LAB_TRACE_FOLDER:-$HOME/Library/Logs/AutocompleteLab}"

rm -f "$TRACE_FOLDER/traces.jsonl"
rm -f "$TRACE_FOLDER/raw-traces.jsonl"
rm -f "$TRACE_FOLDER/trace-report.html"
rm -f "$TRACE_FOLDER/survival-report.json"
rm -rf "$TRACE_FOLDER/screenshots"

echo "Deleted Autocomplete Lab local traces: $TRACE_FOLDER"
