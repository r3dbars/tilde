#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TRACE_PATH="${AUTOCOMPLETE_LAB_TRACE_PATH:-$HOME/Library/Logs/SteadyType/traces.jsonl}"
MARK_PATH="${AUTOCOMPLETE_LAB_DAILY_DRIVER_MARK_PATH:-$HOME/Library/Logs/SteadyType/daily-driver-dogfood-session.env}"
REPORT_DIR="${AUTOCOMPLETE_LAB_DAILY_DRIVER_REPORT_DIR:-$ROOT_DIR/dist/daily-driver-dogfood}"
MODE="${1:-}"
if [[ $# -gt 0 ]]; then
  shift
fi

APP_FILTER=""
LABEL="daily-driver"
REPORT_PATH=""
START_LINE_OVERRIDE=""
END_LINE_OVERRIDE=""
NO_GATE=0
ALLOW_LOW_SAMPLE=0
MIN_SHOWN="${AUTOCOMPLETE_LAB_DAILY_DRIVER_MIN_SHOWN:-5}"
MIN_ACCEPTED="${AUTOCOMPLETE_LAB_DAILY_DRIVER_MIN_ACCEPTED:-1}"
MIN_KEPT="${AUTOCOMPLETE_LAB_DAILY_DRIVER_MIN_KEPT:-1}"
MIN_ACTIVE_MINUTES="${AUTOCOMPLETE_LAB_DAILY_DRIVER_MIN_ACTIVE_MINUTES:-5}"

usage() {
  cat <<'EOF'
Usage: script/daily_driver_dogfood_session.sh <start|finish|status|print> [options]

Start a redacted daily-driver dogfood trace slice, then finish it into a local
Markdown report. The report uses trace metadata only; do not paste raw writing
or screenshots into it.

Options:
  --app BUNDLE       Restrict finish checks to one app bundle, such as md.obsidian.
  --label LABEL     Human label stored in the local mark/report.
  --trace PATH      Trace JSONL path. Defaults to ~/Library/Logs/SteadyType/traces.jsonl.
  --mark-file PATH  Local mark state path.
  --report PATH     Finish report path. Defaults under dist/daily-driver-dogfood/.
  --start-line N    Finish from an explicit saved line instead of mark file.
  --end-line N      Finish at an explicit line instead of current trace end.
  --min-shown N     Minimum shown suggestions for a real session. Default: 5.
  --min-accepted N  Minimum accepted suggestions. Default: 1.
  --min-kept N      Minimum accepted-and-kept suggestions. Default: 1.
  --min-active-minutes N
                    Minimum active trace span. Default: 5.
  --allow-low-sample
                    Lower all sample minimums to 0 for harness/debug slices.
  --no-gate         Write the report even if gates fail and exit 0.

Examples:
  ./script/daily_driver_dogfood_session.sh start --app md.obsidian --label obsidian-note
  # write normally for 10-20 minutes, accept/dismiss naturally
  ./script/daily_driver_dogfood_session.sh finish --app md.obsidian
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app)
      shift
      APP_FILTER="${1:-}"
      ;;
    --app=*)
      APP_FILTER="${1#--app=}"
      ;;
    --label)
      shift
      LABEL="${1:-}"
      ;;
    --label=*)
      LABEL="${1#--label=}"
      ;;
    --trace)
      shift
      TRACE_PATH="${1:-}"
      ;;
    --trace=*)
      TRACE_PATH="${1#--trace=}"
      ;;
    --mark-file)
      shift
      MARK_PATH="${1:-}"
      ;;
    --mark-file=*)
      MARK_PATH="${1#--mark-file=}"
      ;;
    --report)
      shift
      REPORT_PATH="${1:-}"
      ;;
    --report=*)
      REPORT_PATH="${1#--report=}"
      ;;
    --start-line)
      shift
      START_LINE_OVERRIDE="${1:-}"
      ;;
    --start-line=*)
      START_LINE_OVERRIDE="${1#--start-line=}"
      ;;
    --end-line)
      shift
      END_LINE_OVERRIDE="${1:-}"
      ;;
    --end-line=*)
      END_LINE_OVERRIDE="${1#--end-line=}"
      ;;
    --min-shown)
      shift
      MIN_SHOWN="${1:-}"
      ;;
    --min-shown=*)
      MIN_SHOWN="${1#--min-shown=}"
      ;;
    --min-accepted)
      shift
      MIN_ACCEPTED="${1:-}"
      ;;
    --min-accepted=*)
      MIN_ACCEPTED="${1#--min-accepted=}"
      ;;
    --min-kept)
      shift
      MIN_KEPT="${1:-}"
      ;;
    --min-kept=*)
      MIN_KEPT="${1#--min-kept=}"
      ;;
    --min-active-minutes)
      shift
      MIN_ACTIVE_MINUTES="${1:-}"
      ;;
    --min-active-minutes=*)
      MIN_ACTIVE_MINUTES="${1#--min-active-minutes=}"
      ;;
    --allow-low-sample)
      ALLOW_LOW_SAMPLE=1
      ;;
    --no-gate)
      NO_GATE=1
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
  shift || true
done

current_trace_line() {
  if [[ -f "$TRACE_PATH" ]]; then
    wc -l <"$TRACE_PATH" | tr -d ' '
  else
    echo 0
  fi
}

require_integer() {
  local name="$1"
  local value="$2"
  if ! [[ "$value" =~ ^[0-9]+$ ]]; then
    echo "$name must be a non-negative integer: $value" >&2
    exit 2
  fi
}

load_mark() {
  if [[ -n "$START_LINE_OVERRIDE" ]]; then
    START_LINE="$START_LINE_OVERRIDE"
    STARTED_AT="explicit"
    MARK_LABEL="$LABEL"
    MARK_APP_FILTER="$APP_FILTER"
    return
  fi

  if [[ ! -f "$MARK_PATH" ]]; then
    echo "daily-driver dogfood mark missing: $MARK_PATH" >&2
    echo "Run ./script/daily_driver_dogfood_session.sh start first." >&2
    exit 1
  fi

  # shellcheck source=/dev/null
  source "$MARK_PATH"
  START_LINE="${START_LINE:-}"
  STARTED_AT="${STARTED_AT:-unknown}"
  MARK_LABEL="${LABEL:-daily-driver}"
  MARK_APP_FILTER="${APP_FILTER:-}"

  if [[ -z "$APP_FILTER" ]]; then
    APP_FILTER="$MARK_APP_FILTER"
  fi
  if [[ "$LABEL" == "daily-driver" && "$MARK_LABEL" != "daily-driver" ]]; then
    LABEL="$MARK_LABEL"
  fi
}

write_start_mark() {
  local line started_at
  line="$(current_trace_line)"
  started_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  mkdir -p "$(dirname "$MARK_PATH")"
  {
    printf "START_LINE=%q\n" "$line"
    printf "STARTED_AT=%q\n" "$started_at"
    printf "LABEL=%q\n" "$LABEL"
    printf "APP_FILTER=%q\n" "$APP_FILTER"
    printf "TRACE_PATH_AT_START=%q\n" "$TRACE_PATH"
  } >"$MARK_PATH"

  cat <<EOF
Daily-driver dogfood mark saved.
Trace: $TRACE_PATH
Start line: $line
Mark: $MARK_PATH
Label: $LABEL
App filter: ${APP_FILTER:-all supported apps}

Now write normally for 10-20 minutes. Accept with Tab/backtick only when useful,
dismiss with Esc when wrong, and do not paste raw writing into the final report.

Finish with:
  ./script/daily_driver_dogfood_session.sh finish${APP_FILTER:+ --app $APP_FILTER}
EOF
}

print_status() {
  local line
  line="$(current_trace_line)"
  echo "Trace: $TRACE_PATH"
  echo "Current line: $line"
  if [[ -f "$MARK_PATH" ]]; then
    # shellcheck source=/dev/null
    source "$MARK_PATH"
    echo "Saved mark: ${START_LINE:-unknown}"
    echo "Started at: ${STARTED_AT:-unknown}"
    echo "Label: ${LABEL:-daily-driver}"
    echo "App filter: ${APP_FILTER:-all supported apps}"
    if [[ "${START_LINE:-}" =~ ^[0-9]+$ ]]; then
      echo "New trace rows: $((line - START_LINE))"
    fi
  else
    echo "Saved mark: none"
  fi
}

run_session_sample_gate() {
  local trace_path="$1"
  local start_line="$2"
  local end_line="$3"
  local app_filter="$4"
  local min_shown="$5"
  local min_accepted="$6"
  local min_kept="$7"
  local min_active_minutes="$8"

  python3 - \
    "$trace_path" \
    "$start_line" \
    "$end_line" \
    "$app_filter" \
    "$min_shown" \
    "$min_accepted" \
    "$min_kept" \
    "$min_active_minutes" <<'PY'
import json
import sys
from datetime import datetime, timezone

path = sys.argv[1]
start_line = int(sys.argv[2])
end_line = int(sys.argv[3])
app_filter = sys.argv[4]


def parse_int(name, raw):
    try:
        value = int(raw)
    except ValueError as error:
        raise SystemExit(f"{name} must be a non-negative integer: {raw}") from error
    if value < 0:
        raise SystemExit(f"{name} must be a non-negative integer: {raw}")
    return value


def parse_float(name, raw):
    try:
        value = float(raw)
    except ValueError as error:
        raise SystemExit(f"{name} must be a non-negative number: {raw}") from error
    if value < 0:
        raise SystemExit(f"{name} must be a non-negative number: {raw}")
    return value


min_shown = parse_int("min shown", sys.argv[5])
min_accepted = parse_int("min accepted", sys.argv[6])
min_kept = parse_int("min accepted-kept", sys.argv[7])
min_active_minutes = parse_float("min active minutes", sys.argv[8])


def parse_timestamp(value):
    if not value:
        return None
    if value.endswith("Z"):
        value = value[:-1] + "+00:00"
    try:
        parsed = datetime.fromisoformat(value)
    except ValueError:
        return None
    if parsed.tzinfo is None:
        return parsed.replace(tzinfo=timezone.utc)
    return parsed


def metadata(event):
    value = event.get("metadata") or {}
    return value if isinstance(value, dict) else {}


def suggestion_key(line_number, event):
    return str(event.get("suggestionID") or event.get("id") or f"line:{line_number}")


def acceptance_key(line_number, event):
    event_metadata = metadata(event)
    return str(event_metadata.get("acceptanceID") or suggestion_key(line_number, event))


def truthy(value):
    return str(value).strip().lower() in {"1", "true", "yes", "on"}


def kept_event(event):
    event_metadata = metadata(event)
    if truthy(event_metadata.get("strongAcceptedAndKept")) or truthy(event_metadata.get("finalAcceptedAndKept")):
        return True
    if event_metadata.get("checkpoint") not in {"10s", "30s", "1m", "5m", "fieldBlur", "fieldSend"}:
        return False
    return event_metadata.get("survivalClass") in {
        "exactKept",
        "lightlyEditedKept",
        "partiallyKept",
    }


matched = []
scanned_rows = 0
with open(path, "r", encoding="utf-8") as handle:
    for line_number, line in enumerate(handle, start=1):
        if line_number < start_line:
            continue
        if line_number > end_line:
            break
        scanned_rows += 1
        line = line.strip()
        if not line:
            continue
        try:
            event = json.loads(line)
        except json.JSONDecodeError as error:
            raise SystemExit(f"invalid JSONL on line {line_number}: {error}") from error
        if app_filter and event.get("appBundleIdentifier") != app_filter:
            continue
        matched.append((line_number, event))

presented_keys = {
    suggestion_key(line_number, event)
    for line_number, event in matched
    if event.get("type") == "suggestionPresented"
}
accepted_keys = {
    acceptance_key(line_number, event)
    for line_number, event in matched
    if event.get("type") == "suggestionAccepted"
}
accepted_suggestion_keys = {
    suggestion_key(line_number, event)
    for line_number, event in matched
    if event.get("type") == "suggestionAccepted"
}
kept_keys = {
    acceptance_key(line_number, event)
    for line_number, event in matched
    if event.get("type") == "acceptedTextEdited" and kept_event(event)
}
kept_suggestion_keys = {
    suggestion_key(line_number, event)
    for line_number, event in matched
    if event.get("type") == "acceptedTextEdited" and kept_event(event)
}
if accepted_keys:
    accepted_kept = len(kept_keys.intersection(accepted_keys))
    accepted_kept = max(
        accepted_kept,
        len(kept_suggestion_keys.intersection(accepted_suggestion_keys)),
    )
else:
    accepted_kept = len(kept_keys)

dates = [
    parsed
    for _, event in matched
    for parsed in [parse_timestamp(str(event.get("timestamp") or ""))]
    if parsed is not None
]
if len(dates) >= 2:
    active_minutes = max(0.0, (max(dates) - min(dates)).total_seconds() / 60.0)
else:
    active_minutes = 0.0

failures = []
if not matched:
    failures.append("trace slice has no matching events")
if active_minutes < min_active_minutes:
    failures.append(
        f"active minutes below minimum ({active_minutes:.2f}/{min_active_minutes:g})"
    )
if len(presented_keys) < min_shown:
    failures.append(f"shown suggestions below minimum ({len(presented_keys)}/{min_shown})")
if len(accepted_keys) < min_accepted:
    failures.append(f"accepted suggestions below minimum ({len(accepted_keys)}/{min_accepted})")
if accepted_kept < min_kept:
    failures.append(f"accepted-kept suggestions below minimum ({accepted_kept}/{min_kept})")

print("Daily-driver sample gate")
print("Privacy: redacted metadata counts only")
print(f"App filter: {app_filter or 'all supported apps'}")
print(f"Rows scanned: {scanned_rows}")
print(f"Rows matched: {len(matched)}")
print(f"Active minutes: {active_minutes:.2f} (minimum {min_active_minutes:g})")
print(f"Shown suggestions: {len(presented_keys)} (minimum {min_shown})")
print(f"Accepted suggestions: {len(accepted_keys)} (minimum {min_accepted})")
print(f"Accepted-kept suggestions: {accepted_kept} (minimum {min_kept})")
if failures:
    print("Result: fail")
    print("Failures:")
    for failure in failures:
        print(f"- {failure}")
    raise SystemExit(1)
print("Result: pass")
PY
}

default_report_path() {
  local timestamp safe_label
  timestamp="$(date -u +"%Y%m%dT%H%M%SZ")"
  safe_label="$(printf "%s" "$LABEL" | tr -cs 'A-Za-z0-9._-' '-' | sed 's/^-//;s/-$//')"
  if [[ -z "$safe_label" ]]; then
    safe_label="daily-driver"
  fi
  echo "$REPORT_DIR/${timestamp}-${safe_label}.md"
}

finish_session() {
  load_mark
  require_integer "start line" "$START_LINE"
  if ((ALLOW_LOW_SAMPLE == 1)); then
    MIN_SHOWN=0
    MIN_ACCEPTED=0
    MIN_KEPT=0
    MIN_ACTIVE_MINUTES=0
  fi

  local end_line fresh_start report_path trace_eval_output non_annoyance_output sample_gate_output
  local trace_eval_status non_annoyance_status sample_gate_status gate_status timestamp
  end_line="${END_LINE_OVERRIDE:-$(current_trace_line)}"
  require_integer "end line" "$end_line"
  if ((end_line <= START_LINE)); then
    echo "No new trace rows since start line $START_LINE." >&2
    echo "Write for a bit, accept/dismiss naturally, then finish again." >&2
    exit 1
  fi

  fresh_start=$((START_LINE + 1))
  report_path="${REPORT_PATH:-$(default_report_path)}"
  mkdir -p "$(dirname "$report_path")"
  trace_eval_output="$(mktemp)"
  non_annoyance_output="$(mktemp)"
  sample_gate_output="$(mktemp)"
  trap 'rm -f "$trace_eval_output" "$non_annoyance_output" "$sample_gate_output"' RETURN

  set +e
  run_session_sample_gate \
    "$TRACE_PATH" \
    "$fresh_start" \
    "$end_line" \
    "$APP_FILTER" \
    "$MIN_SHOWN" \
    "$MIN_ACCEPTED" \
    "$MIN_KEPT" \
    "$MIN_ACTIVE_MINUTES" \
    >"$sample_gate_output" 2>&1
  sample_gate_status=$?

  "$ROOT_DIR/script/non_annoyance_report.py" \
    "$TRACE_PATH" \
    --start-line "$fresh_start" \
    --end-line "$end_line" \
    --window all \
    >"$non_annoyance_output" 2>&1
  non_annoyance_status=$?

  if [[ -n "$APP_FILTER" ]]; then
    AUTOCOMPLETE_LAB_TRACE_PATH="$TRACE_PATH" \
    AUTOCOMPLETE_LAB_TRACE_START_LINE="$START_LINE" \
    AUTOCOMPLETE_LAB_TRACE_END_LINE="$end_line" \
    AUTOCOMPLETE_LAB_TRACE_REQUIRE_APP="$APP_FILTER" \
    AUTOCOMPLETE_LAB_TRACE_STRICT=0 \
      "$ROOT_DIR/script/check_trace_eval.sh" >"$trace_eval_output" 2>&1
  else
    AUTOCOMPLETE_LAB_TRACE_PATH="$TRACE_PATH" \
    AUTOCOMPLETE_LAB_TRACE_START_LINE="$START_LINE" \
    AUTOCOMPLETE_LAB_TRACE_END_LINE="$end_line" \
    AUTOCOMPLETE_LAB_TRACE_STRICT=0 \
      "$ROOT_DIR/script/check_trace_eval.sh" >"$trace_eval_output" 2>&1
  fi
  trace_eval_status=$?
  set -e

  gate_status="pass"
  if ((sample_gate_status != 0 || non_annoyance_status != 0 || trace_eval_status != 0)); then
    gate_status="fail"
  fi
  timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  {
    echo "# Daily Driver Dogfood Session"
    echo
    echo "This report is redacted. It should contain trace metadata and manual labels only, not raw writing, prompts, screenshots, document names, URLs, recipients, or subjects."
    echo
    echo "## Summary"
    echo
    echo "- Finished at: \`$timestamp\`."
    echo "- Started at: \`${STARTED_AT:-unknown}\`."
    echo "- Label: \`$LABEL\`."
    echo "- App filter: \`${APP_FILTER:-all supported apps}\`."
    echo "- Trace: \`$TRACE_PATH\`."
    echo "- Fresh lines: \`$fresh_start-$end_line\`."
    echo "- Gate: \`$gate_status\`."
    echo "- Sample gate status: \`$sample_gate_status\`."
    echo "- Non-annoyance status: \`$non_annoyance_status\`."
    echo "- Trace eval status: \`$trace_eval_status\`."
    echo "- Sample minimums: shown \`$MIN_SHOWN\`, accepted \`$MIN_ACCEPTED\`, accepted-kept \`$MIN_KEPT\`, active minutes \`$MIN_ACTIVE_MINUTES\`."
    echo "- Low-sample override: \`$ALLOW_LOW_SAMPLE\`."
    echo
    echo "## Manual Trust Row"
    echo
    echo "| App | Minutes | Did I reach for it? | Magic moment | Annoying moment | Placement trust | Keep it on tomorrow? |"
    echo "| --- | ---: | --- | --- | --- | --- | --- |"
    echo "| ${APP_FILTER:-mixed} |  |  |  |  |  |  |"
    echo
    echo "## Session Sample Gate"
    echo
    echo '```text'
    cat "$sample_gate_output"
    echo '```'
    echo
    echo "## Non-Annoyance Gate"
    echo
    echo '```text'
    cat "$non_annoyance_output"
    echo '```'
    echo
    echo "## Trace Eval"
    echo
    echo '```text'
    cat "$trace_eval_output"
    echo '```'
    echo
    echo "## Next Decision"
    echo
    echo "- If the gate failed because of wrong insertion, sensitive field display, focus steal, or unreliable Tab, stop and fix that trust issue first."
    echo "- If the gate passed but the manual row says you did not reach for it, tune suggestion quality or cadence before expanding app support."
    echo "- If the gate passed and you would keep it on tomorrow, run another session in a different supported writing app."
  } >"$report_path"

  echo "Daily-driver dogfood report: $report_path"
  echo "Gate: $gate_status"
  if [[ "$gate_status" != "pass" && "$NO_GATE" != "1" ]]; then
    exit 1
  fi
}

case "$MODE" in
  start)
    write_start_mark
    ;;
  finish)
    finish_session
    ;;
  status)
    print_status
    ;;
  print|"")
    usage
    ;;
  *)
    echo "unknown mode: $MODE" >&2
    usage >&2
    exit 2
    ;;
esac
