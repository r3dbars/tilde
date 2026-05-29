#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

APP_BUNDLE_WAS_EXPLICIT=0
if [[ -n "${AUTOCOMPLETE_LAB_APP_BUNDLE+x}" ]]; then
  APP_BUNDLE_WAS_EXPLICIT=1
fi

APP_BUNDLE="${AUTOCOMPLETE_LAB_APP_BUNDLE:-$ROOT_DIR/dist/SteadyType.app}"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/SteadyType"
OUTPUT_DIR="${AUTOCOMPLETE_LAB_PRIVACY_PROOF_OUTPUT:-$ROOT_DIR/docs/diagnostics/runs/current-build-privacy-export-proof}"
LOCK_DIR="${AUTOCOMPLETE_LAB_PRIVACY_EXPORT_LOCK_DIR:-${TMPDIR:-/tmp}/autocomplete-current-build-privacy-export.lock}"
LOCK_WAIT_SECONDS="${AUTOCOMPLETE_LAB_PRIVACY_EXPORT_LOCK_WAIT_SECONDS:-300}"
LOCK_HELD=0
BUILD_DIST_DIR=""
EXPECTED_FILES=""
ACTUAL_FILES=""

BUILD_LOG=/tmp/autocomplete-current-build-privacy-build.log

cleanup() {
  if [[ "$LOCK_HELD" == "1" ]]; then
    rm -rf "$LOCK_DIR" >/dev/null 2>&1 || true
  fi
  [[ -z "$BUILD_DIST_DIR" ]] || rm -rf "$BUILD_DIST_DIR" >/dev/null 2>&1 || true
  [[ -z "$EXPECTED_FILES" ]] || rm -f "$EXPECTED_FILES" >/dev/null 2>&1 || true
  [[ -z "$ACTUAL_FILES" ]] || rm -f "$ACTUAL_FILES" >/dev/null 2>&1 || true
}
trap cleanup EXIT

use_temp_build_bundle_if_default() {
  if [[ "$APP_BUNDLE_WAS_EXPLICIT" == "1" ]]; then
    return 0
  fi

  BUILD_DIST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/steadytype-privacy-build.XXXXXX")"
  APP_BUNDLE="$BUILD_DIST_DIR/SteadyType.app"
  APP_BINARY="$APP_BUNDLE/Contents/MacOS/SteadyType"
}

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

current_process_ancestor_pids() {
  local pid="${BASHPID:-$$}"
  local parent
  local ancestors=()

  while parent="$(ps -o ppid= -p "$pid" 2>/dev/null || true)"; do
    parent="${parent//[[:space:]]/}"
    [[ -n "$parent" && "$parent" != "0" && "$parent" != "$pid" ]] || break
    ancestors+=("$parent")
    pid="$parent"
  done

  printf '%s\n' "${ancestors[@]}"
}

allowed_proof_pgids() {
  local raw="${AUTOCOMPLETE_LAB_PRIVACY_EXPORT_ALLOWED_PROOF_PGIDS:-}"
  local token

  raw="${raw//,/ }"
  for token in $raw; do
    if [[ "$token" =~ ^[0-9]+$ ]]; then
      printf '%s\n' "$token"
    fi
  done
}

other_proof_process_lines() {
  local process_list ancestor_pids allowed_pgids
  ancestor_pids="$(current_process_ancestor_pids || true)"
  ancestor_pids="${ancestor_pids//$'\n'/ }"
  allowed_pgids="$(allowed_proof_pgids || true)"
  allowed_pgids="${allowed_pgids//$'\n'/ }"
  process_list="$(ps -axo pid=,ppid=,pgid=,command= 2>/dev/null || true)"

  awk -v self="${BASHPID:-$$}" -v ancestorPids="$ancestor_pids" -v allowedProofPgids="$allowed_pgids" '
    BEGIN {
      split(ancestorPids, rawAncestors, /[[:space:]]+/)
      for (i in rawAncestors) {
        if (rawAncestors[i] != "") {
          ancestor[rawAncestors[i]] = 1
        }
      }
      split(allowedProofPgids, rawAllowedProofPgids, /[[:space:]]+/)
      for (i in rawAllowedProofPgids) {
        if (rawAllowedProofPgids[i] != "") {
          allowedPgid[rawAllowedProofPgids[i]] = 1
        }
      }
    }
    {
      pid = $1
      ppid = $2
      pgid = $3
      command = $0
      rawLine[pid] = $0
      parent[pid] = ppid
      processGroup[pid] = pgid
      sub(/^[[:space:]]*[0-9]+[[:space:]]+[0-9]+[[:space:]]+[0-9]+[[:space:]]+/, "", command)
      directScript[pid] = command ~ /^(\.\/)?script\/(real_app_smoke|fresh_latency_proof|smoke_test|build_and_run|beta_readiness|check_score_targets)\.sh([[:space:]]|$)/
      shellWrapper = command ~ /^((\/[^[:space:]]+\/)?(env[[:space:]]+)?(bash|zsh)|\/usr\/bin\/env[[:space:]]+(bash|zsh))([[:space:]]|$)/
      hasProofScript[pid] = index(command, "script/real_app_smoke.sh") > 0 ||
        index(command, "script/fresh_latency_proof.sh") > 0 ||
        index(command, "script/smoke_test.sh") > 0 ||
        index(command, "script/build_and_run.sh") > 0 ||
        index(command, "script/beta_readiness.sh") > 0 ||
        index(command, "script/check_score_targets.sh") > 0
      shellHasProofScript[pid] = shellWrapper && hasProofScript[pid]
    }
    function relatedToSelf(pid, parentPid, depth) {
      if (pid == self || pid in ancestor) return 1
      parentPid = pid
      for (depth = 0; depth < 128; depth++) {
        if (!(parentPid in parent)) return 0
        parentPid = parent[parentPid]
        if (parentPid == self) return 1
        if (parentPid == "" || parentPid == "0" || parentPid == parent[parentPid]) return 0
      }
      return 0
    }
    END {
      for (pid in rawLine) {
        if (relatedToSelf(pid)) continue
        if (processGroup[pid] in allowedPgid) continue
        if (directScript[pid] || shellHasProofScript[pid]) {
          print rawLine[pid]
        }
      }
    }
  ' <<<"$process_list"
}

wait_for_quiet_proof_processes() {
  local deadline=$((SECONDS + LOCK_WAIT_SECONDS))
  local announced=0
  local processes

  while true; do
    processes="$(other_proof_process_lines || true)"
    if [[ -z "$processes" ]]; then
      return 0
    fi

    if ((SECONDS >= deadline)); then
      echo "Another proof process is already active." >&2
      echo "Timed out before current build privacy export proof." >&2
      echo "$processes" >&2
      exit 1
    fi

    if [[ "$announced" == "0" ]]; then
      echo "Waiting for active proof process before current build privacy export." >&2
      echo "$processes" >&2
      announced=1
    fi
    sleep 2
  done
}

if ! [[ "$LOCK_WAIT_SECONDS" =~ ^[0-9]+$ ]]; then
  echo "AUTOCOMPLETE_LAB_PRIVACY_EXPORT_LOCK_WAIT_SECONDS must be a non-negative integer" >&2
  exit 2
fi

acquire_lock
wait_for_quiet_proof_processes

if [[ ! -x "$APP_BINARY" || "${AUTOCOMPLETE_LAB_REBUILD_PRIVACY_PROOF:-0}" =~ ^(1|true|yes|on)$ ]]; then
  use_temp_build_bundle_if_default
  if ! AUTOCOMPLETE_LAB_DIST_DIR="$(dirname "$APP_BUNDLE")" ./script/build_and_run.sh --bundle-only >"$BUILD_LOG" 2>&1; then
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
  "$OUTPUT_DIR/privacy-export/visual-calibration-report.txt" \
  "$OUTPUT_DIR/privacy-export/trace-report.html"; do
  if [[ ! -f "$required" ]]; then
    echo "privacy proof missing required file: $required" >&2
    exit 1
  fi
done

EXPECTED_FILES="$(mktemp)"
ACTUAL_FILES="$(mktemp)"

cat >"$EXPECTED_FILES" <<'EOF'
privacy-export/PRIVACY-CHECKLIST.md
privacy-export/manifest.json
privacy-export/redacted-traces.jsonl
privacy-export/survival-report.json
privacy-export/trace-report.html
privacy-export/visual-calibration-report.txt
proof-command.log
proof-manifest.json
EOF

find "$OUTPUT_DIR" -type f -print |
  sed "s#^$OUTPUT_DIR/##" |
  sort >"$ACTUAL_FILES"

if ! diff -u "$EXPECTED_FILES" "$ACTUAL_FILES" >/tmp/autocomplete-current-build-privacy-files.diff; then
  echo "privacy proof output contains unexpected shareable files" >&2
  cat /tmp/autocomplete-current-build-privacy-files.diff >&2
  exit 1
fi

python3 - "$OUTPUT_DIR/privacy-export/redacted-traces.jsonl" "$OUTPUT_DIR/privacy-export/survival-report.json" "$OUTPUT_DIR/privacy-export/manifest.json" <<'PY'
import json
import re
import sys
from pathlib import Path

raw_text_fields = {
    "acceptedText",
    "cleanedVisibleText",
    "displayedText",
    "rawOutput",
    "remainingVisibleText",
    "screenshotPath",
    "systemPrompt",
    "textAfterCursor",
    "textBeforeCursor",
    "userPrompt",
}
shape_metadata = {
    "contextPreview",
    "documentTitle",
    "innocentNote",
    "neighborText",
    "visibleURL",
    "recipientEmail",
    "subjectLine",
}
shape_re = re.compile(r"^String\(\d+ chars\)$")
private_re = re.compile(
    r"proof-private-|private\.example|private-screenshot|private-recipient|private document|private subject",
    re.IGNORECASE,
)

required_types = {"suggestionPresented", "suggestionAccepted"}

def check_event(event, source):
    for field in raw_text_fields:
        value = event.get(field)
        if value not in (None, ""):
            raise SystemExit(f"{source}: raw field {field} was not redacted")
    metadata = event.get("metadata") or {}
    if metadata.get("privacyLane") != "redacted-local-beta-telemetry":
        raise SystemExit(f"{source}: missing redacted privacy lane")
    if metadata.get("rawDogfoodDiagnostics") != "false":
        raise SystemExit(f"{source}: raw dogfood diagnostics marker was not false")
    for key, value in metadata.items():
        if private_re.search(str(value)):
            raise SystemExit(f"{source}: metadata {key} leaked private sentinel {value!r}")
    for key in shape_metadata:
        value = metadata.get(key)
        if value is not None and not shape_re.match(str(value)):
            raise SystemExit(f"{source}: metadata {key} kept raw value {value!r}")

trace_path = Path(sys.argv[1])
events = []
for line_number, line in enumerate(trace_path.read_text().splitlines(), start=1):
    if line.strip():
        event = json.loads(line)
        events.append(event)
        check_event(event, f"{trace_path}:{line_number}")

if len(events) < 2:
    raise SystemExit(f"{trace_path}: expected at least 2 redacted proof events, found {len(events)}")

seen_types = {event.get("type") for event in events}
missing_types = required_types - seen_types
if missing_types:
    raise SystemExit(f"{trace_path}: missing proof event type(s): {', '.join(sorted(missing_types))}")

if {event.get("sessionID") for event in events} != {"privacy-proof-session"}:
    raise SystemExit(f"{trace_path}: proof session id changed or mixed with another session")

survival_path = Path(sys.argv[2])
survival_events = json.loads(survival_path.read_text())
for index, event in enumerate(survival_events, start=1):
    check_event(event, f"{survival_path}:event-{index}")

manifest_path = Path(sys.argv[3])
manifest = json.loads(manifest_path.read_text())
if manifest.get("privacyLane") != "redacted-local-beta-telemetry":
    raise SystemExit(f"{manifest_path}: manifest privacy lane is not redacted beta telemetry")
if manifest.get("rawTextIncluded") is not False or manifest.get("screenshotsIncluded") is not False:
    raise SystemExit(f"{manifest_path}: manifest claims raw text or screenshots are included")
if manifest.get("eventCount") != len(events):
    raise SystemExit(f"{manifest_path}: event count {manifest.get('eventCount')} did not match {len(events)}")
PY

echo "Current build privacy export proof passed: $OUTPUT_DIR"
