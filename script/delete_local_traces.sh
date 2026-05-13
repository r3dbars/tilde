#!/usr/bin/env bash
set -euo pipefail

TRACE_FOLDER="${AUTOCOMPLETE_LAB_TRACE_FOLDER:-$HOME/Library/Logs/SteadyType}"
STATE_FOLDER="${AUTOCOMPLETE_LAB_STATE_FOLDER:-$HOME/Library/Application Support/SteadyType}"

canonical_path() {
  local path="$1"
  local parent
  local base

  parent="$(dirname "$path")"
  base="$(basename "$path")"
  if [[ -d "$path" ]]; then
    (cd "$path" && pwd -P)
  elif [[ -d "$parent" ]]; then
    printf '%s/%s\n' "$(cd "$parent" && pwd -P)" "$base"
  else
    printf '%s\n' "$path"
  fi
}

path_is_within() {
  local path="$1"
  local root="$2"

  [[ "$path" == "$root" || "$path" == "$root/"* ]]
}

require_safe_folder() {
  local label="$1"
  local path="$2"
  local home_path="${HOME%/}"
  local tmp_path="${TMPDIR:-/tmp}"
  local canonical
  local canonical_home
  local canonical_home_library
  local canonical_home_logs
  local canonical_home_application_support
  local default_logs
  local default_state
  local canonical_tmp

  if [[ -z "$path" || "$path" == "/" ]]; then
    echo "refusing to delete $label traces from unsafe folder: ${path:-<empty>}" >&2
    exit 2
  fi

  canonical="$(canonical_path "${path%/}")"
  canonical_home="$(canonical_path "$home_path")"
  canonical_home_library="$(canonical_path "$home_path/Library")"
  canonical_home_logs="$(canonical_path "$home_path/Library/Logs")"
  canonical_home_application_support="$(canonical_path "$home_path/Library/Application Support")"
  default_logs="$(canonical_path "$home_path/Library/Logs/SteadyType")"
  default_state="$(canonical_path "$home_path/Library/Application Support/SteadyType")"
  canonical_tmp="$(canonical_path "${tmp_path%/}")"

  case "$canonical" in
    "$canonical_home"|"$canonical_home_library"|"$canonical_home_logs"|"$canonical_home_application_support")
      echo "refusing to delete $label traces from broad folder: $path" >&2
      exit 2
      ;;
  esac

  if path_is_within "$canonical" "$default_logs" ||
     path_is_within "$canonical" "$default_state"; then
    return
  fi

  if path_is_within "$canonical" "$canonical_home"; then
    echo "refusing to delete $label traces from non-SteadyType folder: $path" >&2
    exit 2
  fi

  if path_is_within "$canonical" "$canonical_tmp" ||
     path_is_within "$canonical" "/tmp" ||
     path_is_within "$canonical" "/private/tmp"; then
    return
  fi

  echo "refusing to delete $label traces from non-SteadyType folder: $path" >&2
  exit 2
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
  survival-report.json \
  survival-inspector-debug.json; do
  delete_file "$TRACE_FOLDER/$name"
done

for name in \
  privacy-export \
  screenshots; do
  delete_folder "$TRACE_FOLDER/$name"
done

delete_file "$STATE_FOLDER/compatibility-learning.json"

echo "Deleted SteadyType local traces: $TRACE_FOLDER"
