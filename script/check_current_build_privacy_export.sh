#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

APP_BUNDLE="${AUTOCOMPLETE_LAB_APP_BUNDLE:-$ROOT_DIR/dist/SteadyType.app}"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/SteadyType"
OUTPUT_DIR="${AUTOCOMPLETE_LAB_PRIVACY_PROOF_OUTPUT:-$ROOT_DIR/docs/diagnostics/runs/current-build-privacy-export-proof}"
LOCK_DIR="${AUTOCOMPLETE_LAB_PRIVACY_EXPORT_LOCK_DIR:-${TMPDIR:-/tmp}/autocomplete-current-build-privacy-export.lock}"
LOCK_WAIT_SECONDS="${AUTOCOMPLETE_LAB_PRIVACY_EXPORT_LOCK_WAIT_SECONDS:-300}"
LOCK_HELD=0

BUILD_LOG=/tmp/autocomplete-current-build-privacy-build.log

cleanup() {
  if [[ "$LOCK_HELD" == "1" ]]; then
    rm -rf "$LOCK_DIR" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

acquire_lock() {
  local deadline=$((SECONDS + LOCK_WAIT_SECONDS))
  local existing_pid=""
  local announced=0

  while true; do
    if mkdir "$LOCK_DIR" >/dev/null 2>&1; then
      LOCK_HELD=1
      printf '%s\n' "$$" >"$LOCK_DIR/pid"
      return 0
    fi

    existing_pid=""
    if [[ -f "$LOCK_DIR/pid" ]]; then
      existing_pid="$(cat "$LOCK_DIR/pid" 2>/dev/null || true)"
    fi

    if [[ -n "$existing_pid" ]] && kill -0 "$existing_pid" >/dev/null 2>&1; then
      if ((SECONDS >= deadline)); then
        echo "current build privacy export is already active (pid $existing_pid)" >&2
        echo "timed out waiting for lock: $LOCK_DIR" >&2
        exit 1
      fi
      if [[ "$announced" == "0" ]]; then
        echo "Waiting for active current build privacy export (pid $existing_pid)." >&2
        announced=1
      fi
      sleep 2
      continue
    fi

    rm -rf "$LOCK_DIR" >/dev/null 2>&1 || true
  done
}

if ! [[ "$LOCK_WAIT_SECONDS" =~ ^[0-9]+$ ]]; then
  echo "AUTOCOMPLETE_LAB_PRIVACY_EXPORT_LOCK_WAIT_SECONDS must be a non-negative integer" >&2
  exit 2
fi

acquire_lock

if [[ ! -x "$APP_BINARY" || "${AUTOCOMPLETE_LAB_REBUILD_PRIVACY_PROOF:-0}" =~ ^(1|true|yes|on)$ ]]; then
  if ! ./script/build_and_run.sh --bundle-only >"$BUILD_LOG" 2>&1; then
    echo "failed to build app bundle for privacy export proof" >&2
    echo "build output:" >&2
    cat "$BUILD_LOG" >&2 2>/dev/null || true
    exit 1
  fi
fi

if [[ ! -x "$APP_BINARY" ]]; then
  echo "missing app binary for privacy export proof: $APP_BINARY" >&2
  echo "build output:" >&2
  cat "$BUILD_LOG" >&2 2>/dev/null || true
  exit 1
fi

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

if ! "$APP_BINARY" --privacy-export-proof --output "$OUTPUT_DIR" >"$OUTPUT_DIR/proof-command.log" 2>&1; then
  cat "$OUTPUT_DIR/proof-command.log" >&2
  exit 1
fi

if find "$OUTPUT_DIR" \( -name 'traces.jsonl' -o -name 'raw-traces.jsonl' \) -print | grep -q .; then
  echo "privacy proof output retained raw trace input" >&2
  find "$OUTPUT_DIR" \( -name 'traces.jsonl' -o -name 'raw-traces.jsonl' \) -print >&2
  exit 1
fi

if grep -R -I -E 'proof-private-|private\.example|private-screenshot|private-recipient|private document|private subject|private-cache-redbars|freeform-reason-redbars|/Users/redbars/Library/Application Support/SteadyType/private-cache-redbars|/Users/redbars/private/freeform-reason-redbars\.md' "$OUTPUT_DIR" >/tmp/autocomplete-current-build-privacy-leaks.txt 2>/dev/null; then
  echo "privacy proof output leaked private sentinel text" >&2
  cat /tmp/autocomplete-current-build-privacy-leaks.txt >&2
  exit 1
fi

for required in \
  "$OUTPUT_DIR/proof-manifest.json" \
  "$OUTPUT_DIR/privacy-export/PRIVACY-CHECKLIST.md" \
  "$OUTPUT_DIR/privacy-export/manifest.json" \
  "$OUTPUT_DIR/privacy-export/redacted-traces.jsonl" \
  "$OUTPUT_DIR/privacy-export/survival-report.json" \
  "$OUTPUT_DIR/privacy-export/trace-report.html"; do
  if [[ ! -f "$required" ]]; then
    echo "privacy proof missing required file: $required" >&2
    exit 1
  fi
done

echo "Current build privacy export proof passed: $OUTPUT_DIR"
