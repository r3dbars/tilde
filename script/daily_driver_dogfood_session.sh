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

  local end_line fresh_start report_path trace_eval_output non_annoyance_output
  local trace_eval_status non_annoyance_status gate_status timestamp
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
  trap 'rm -f "$trace_eval_output" "$non_annoyance_output"' RETURN

  set +e
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
  if ((non_annoyance_status != 0 || trace_eval_status != 0)); then
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
    echo "- Non-annoyance status: \`$non_annoyance_status\`."
    echo "- Trace eval status: \`$trace_eval_status\`."
    echo
    echo "## Manual Trust Row"
    echo
    echo "| App | Minutes | Did I reach for it? | Magic moment | Annoying moment | Placement trust | Keep it on tomorrow? |"
    echo "| --- | ---: | --- | --- | --- | --- | --- |"
    echo "| ${APP_FILTER:-mixed} |  |  |  |  |  |  |"
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
