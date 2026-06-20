#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

APP=""
LABEL="default"
OUT_DIR=""
LOG_PATH="${AUTOCOMPLETE_LAB_LOG:-$HOME/Library/Logs/SteadyType/diagnostics.log}"
TRACE_PATH="${AUTOCOMPLETE_LAB_TRACE_PATH:-$HOME/Library/Logs/SteadyType/traces.jsonl}"
LOG_START_LINE=0
TRACE_START_LINE=0
OUTCOME="blocked"
REASON=""
NEXT_STEP=""
COMMAND_TEXT=""

usage() {
  cat <<'EOF'
Usage: script/real_app_smoke_proof_export.sh --app APP --label LABEL --out DIR [options]

Writes a redacted proof bundle for a real-app smoke run. The bundle contains
counts, line ranges, and safe event metadata only. It never copies raw
diagnostic or trace lines, prompt text, accepted text, document names, URLs, or
screenshots.

Options:
  --log PATH              Diagnostics log path.
  --trace PATH            Trace JSONL path.
  --log-start N           First diagnostics line before the smoke slice.
  --trace-start N         First trace line before the smoke slice.
  --outcome VALUE         passed, blocked, or failed.
  --reason TEXT           Short blocked/failed/pass reason.
  --next-step TEXT        Operator next step.
  --command TEXT          Command being proven.
EOF
}

while (($#)); do
  case "$1" in
    --app)
      shift
      APP="${1:-}"
      ;;
    --label)
      shift
      LABEL="${1:-}"
      ;;
    --out)
      shift
      OUT_DIR="${1:-}"
      ;;
    --log)
      shift
      LOG_PATH="${1:-}"
      ;;
    --trace)
      shift
      TRACE_PATH="${1:-}"
      ;;
    --log-start)
      shift
      LOG_START_LINE="${1:-0}"
      ;;
    --trace-start)
      shift
      TRACE_START_LINE="${1:-0}"
      ;;
    --outcome)
      shift
      OUTCOME="${1:-}"
      ;;
    --reason)
      shift
      REASON="${1:-}"
      ;;
    --next-step)
      shift
      NEXT_STEP="${1:-}"
      ;;
    --command)
      shift
      COMMAND_TEXT="${1:-}"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

if [[ -z "$APP" || -z "$OUT_DIR" ]]; then
  usage >&2
  exit 2
fi
if ! [[ "$LOG_START_LINE" =~ ^[0-9]+$ ]]; then
  echo "--log-start must be a non-negative integer" >&2
  exit 2
fi
if ! [[ "$TRACE_START_LINE" =~ ^[0-9]+$ ]]; then
  echo "--trace-start must be a non-negative integer" >&2
  exit 2
fi

mkdir -p "$OUT_DIR"

created_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
log_end_line=0
trace_end_line=0
if [[ -f "$LOG_PATH" ]]; then
  log_end_line="$(wc -l <"$LOG_PATH" | tr -d ' ')"
fi
if [[ -f "$TRACE_PATH" ]]; then
  trace_end_line="$(wc -l <"$TRACE_PATH" | tr -d ' ')"
fi

line_range() {
  local start="$1"
  local end="$2"
  if ((end <= start)); then
    printf 'none'
  else
    printf '%s-%s' "$((start + 1))" "$end"
  fi
}

write_diagnostic_counts() {
  local output_path="$1"
  if [[ ! -f "$LOG_PATH" ]]; then
    : >"$output_path"
    return 0
  fi

  awk -v start="$LOG_START_LINE" -v app="$APP" '
    NR <= start { next }
    /launch accessibility=(true|trusted)|status .*accessibility=AX ok/ { counts["accessibility_ok"]++ }
    /launch accessibility=false|status .*accessibility=AX missing/ { counts["accessibility_missing"]++ }
    / runtime .*readinessStage=ready/ { counts["runtime_ready"]++ }
    index($0, "suggestion-presented") && index($0, "app=" app) { counts["suggestion_presented"]++ }
    index($0, "keyboard-event-tap-latency") && index($0, "key=tab") { counts["tab_event_tap"]++ }
    index($0, "keyboard-action") && index($0, "app=" app) && index($0, "key=tab") &&
      index($0, "action=acceptNextWord") && index($0, "handled=true") { counts["tab_accept_handled"]++ }
    index($0, "keyboard-action") && index($0, "app=" app) &&
      index($0, "action=acceptAllVisible") && index($0, "handled=true") { counts["full_accept_handled"]++ }
    index($0, "insert ") && index($0, "app=" app) && index($0, "success=true") { counts["insert_success"]++ }
    index($0, "insert-verification") && index($0, "app=" app) && index($0, "result=verified") { counts["insertion_verified"]++ }
    index($0, "screenshot-captured") && index($0, "app=" app) { counts["screenshot_captured"]++ }
    END {
      keys[1] = "accessibility_ok"
      keys[2] = "accessibility_missing"
      keys[3] = "runtime_ready"
      keys[4] = "suggestion_presented"
      keys[5] = "tab_event_tap"
      keys[6] = "tab_accept_handled"
      keys[7] = "full_accept_handled"
      keys[8] = "insert_success"
      keys[9] = "insertion_verified"
      keys[10] = "screenshot_captured"
      for (i = 1; i <= 10; i++) {
        key = keys[i]
        printf "%s=%d\n", key, counts[key] + 0
      }
    }
  ' "$LOG_PATH" >"$output_path"
}

write_redacted_diagnostics() {
  local output_path="$1"
  if [[ ! -f "$LOG_PATH" ]]; then
    : >"$output_path"
    return 0
  fi

  awk -v start="$LOG_START_LINE" -v app="$APP" '
    NR <= start { next }
    {
      category = ""
      if ($0 ~ /launch accessibility=/ || $0 ~ /status .*accessibility=/) category = "accessibility"
      else if ($0 ~ / runtime .*readinessStage=/) category = "runtime"
      else if (index($0, "suggestion-presented") && index($0, "app=" app)) category = "suggestion-presented"
      else if (index($0, "keyboard-event-tap-latency") && index($0, "key=tab")) category = "keyboard-event-tap-latency"
      else if (index($0, "keyboard-action") && index($0, "app=" app)) category = "keyboard-action"
      else if (index($0, "insert ") && index($0, "app=" app)) category = "insert"
      else if (index($0, "insert-verification") && index($0, "app=" app)) category = "insert-verification"
      else if (index($0, "screenshot-captured") && index($0, "app=" app)) category = "screenshot-captured"
      if (category == "") next

      safe = ""
      split("app key action handled result success effectiveRenderMode placementAnchorSource placementConfidenceBand requestMode reason readinessStage accessibility decision", fields, " ")
      for (i in fields) {
        key = fields[i]
        if (match($0, key "=[^ ]+")) {
          safe = safe (safe == "" ? "" : " ") substr($0, RSTART, RLENGTH)
        }
      }
      print NR "\t" category "\t" safe
    }
  ' "$LOG_PATH" | tail -n 120 >"$output_path"
}

write_redacted_trace_events() {
  local output_path="$1"
  if [[ ! -f "$TRACE_PATH" ]]; then
    : >"$output_path"
    return 0
  fi

  python3 - "$TRACE_PATH" "$TRACE_START_LINE" "$APP" >"$output_path" <<'PY'
import json
import sys

trace_path = sys.argv[1]
start_line = int(sys.argv[2])
app = sys.argv[3]
allowed_metadata = {
    "acceptMode",
    "acceptedVisibleScope",
    "anchorCanPresent",
    "anchorQuality",
    "anchorReason",
    "anchorSource",
    "placementConfidenceBand",
    "promptSafetyMode",
}

with open(trace_path, "r", encoding="utf-8") as handle:
    for line_number, line in enumerate(handle, start=1):
        if line_number <= start_line:
            continue
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue
        if event.get("appBundleIdentifier") != app:
            continue
        metadata = event.get("metadata") or {}
        safe_metadata = {
            key: str(metadata.get(key))
            for key in sorted(allowed_metadata)
            if key in metadata
        }
        safe_event = {
            "line": line_number,
            "type": event.get("type"),
            "appBundleIdentifier": event.get("appBundleIdentifier"),
            "requestMode": event.get("requestMode"),
            "metadata": safe_metadata,
        }
        print(json.dumps(safe_event, sort_keys=True))
PY
}

write_status_json() {
  local output_path="$1"
  python3 - "$output_path" <<'PY'
import json
import os
import sys

output_path = sys.argv[1]
payload = {
    "createdAt": os.environ["CREATED_AT"],
    "app": os.environ["APP_NAME"],
    "label": os.environ["LABEL"],
    "outcome": os.environ["OUTCOME"],
    "reason": os.environ["REASON"],
    "nextStep": os.environ["NEXT_STEP"],
    "command": os.environ["COMMAND_TEXT"],
    "diagnosticsRange": os.environ["DIAGNOSTICS_RANGE"],
    "traceRange": os.environ["TRACE_RANGE"],
    "privacy": "redacted metadata and counts only",
}
with open(output_path, "w", encoding="utf-8") as handle:
    json.dump(payload, handle, indent=2, sort_keys=True)
    handle.write("\n")
PY
}

diagnostic_counts_path="$OUT_DIR/diagnostic-counts.txt"
redacted_diagnostics_path="$OUT_DIR/redacted-diagnostics.tsv"
redacted_trace_path="$OUT_DIR/redacted-trace-events.jsonl"
status_path="$OUT_DIR/status.json"
summary_path="$OUT_DIR/README.md"

write_diagnostic_counts "$diagnostic_counts_path"
write_redacted_diagnostics "$redacted_diagnostics_path"
write_redacted_trace_events "$redacted_trace_path"

diagnostics_range="$(line_range "$LOG_START_LINE" "$log_end_line")"
trace_range="$(line_range "$TRACE_START_LINE" "$trace_end_line")"

CREATED_AT="$created_at" \
APP_NAME="$APP" \
LABEL="$LABEL" \
OUTCOME="$OUTCOME" \
REASON="$REASON" \
NEXT_STEP="$NEXT_STEP" \
COMMAND_TEXT="$COMMAND_TEXT" \
DIAGNOSTICS_RANGE="$diagnostics_range" \
TRACE_RANGE="$trace_range" \
  write_status_json "$status_path"

cat >"$summary_path" <<EOF
# Real App Smoke Proof Export

- Created: $created_at
- App: \`$APP\`
- Label: \`$LABEL\`
- Outcome: \`$OUTCOME\`
- Reason: ${REASON:-none}
- Next step: ${NEXT_STEP:-none}
- Command: ${COMMAND_TEXT:-not recorded}
- Diagnostics range: \`$diagnostics_range\`
- Trace range: \`$trace_range\`

Privacy: redacted metadata and counts only. This folder does not include raw
prompt text, accepted text, document names, URLs, screenshots, clipboard data,
or raw diagnostic/trace lines.

Files:

- \`status.json\`
- \`diagnostic-counts.txt\`
- \`redacted-diagnostics.tsv\`
- \`redacted-trace-events.jsonl\`
EOF

echo "Redacted proof export written to $OUT_DIR"
