#!/usr/bin/env bash
set -euo pipefail

TRACE_FOLDER="${AUTOCOMPLETE_LAB_TRACE_FOLDER:-$HOME/Library/Logs/SteadyType}"
STATE_FOLDER="${AUTOCOMPLETE_LAB_STATE_FOLDER:-$HOME/Library/Application Support/SteadyType}"

require_safe_folder() {
  local label="$1"
  local path="$2"
  local home_path="${HOME%/}"

  if [[ -z "$path" || "$path" == "/" ]]; then
    echo "refusing to delete $label traces from unsafe folder: ${path:-<empty>}" >&2
    exit 2
  fi

  case "${path%/}" in
    "$home_path"|"$home_path/Library"|"$home_path/Library/Logs"|"$home_path/Library/Application Support")
      echo "refusing to delete $label traces from broad folder: $path" >&2
      exit 2
      ;;
  esac
}

delete_file() {
  rm -f -- "$1"
}

delete_folder() {
  rm -rf -- "$1"
}

require_safe_folder "log" "$TRACE_FOLDER"
require_safe_folder "state" "$STATE_FOLDER"

for name in \
  traces.jsonl \
  raw-traces.jsonl \
  diagnostics.log \
  trace-report.html \
  survival-report.json; do
  delete_file "$TRACE_FOLDER/$name"
done

for name in \
  privacy-export \
  screenshots; do
  delete_folder "$TRACE_FOLDER/$name"
done

delete_file "$STATE_FOLDER/compatibility-learning.json"

echo "Deleted SteadyType local traces: $TRACE_FOLDER"
