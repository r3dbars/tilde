#!/usr/bin/env bash
set -euo pipefail

TRACE_PATH="${AUTOCOMPLETE_LAB_TRACE_PATH:-$HOME/Library/Logs/AutocompleteLab/traces.jsonl}"
MODE="${1:-}"

if [[ -f "$TRACE_PATH" ]]; then
  START_LINE="$(wc -l <"$TRACE_PATH" | tr -d ' ')"
else
  START_LINE=0
fi

if [[ "$MODE" == "--quiet" ]]; then
  echo "$START_LINE"
  exit 0
fi

cat <<EOF
Trace: $TRACE_PATH
Start line: $START_LINE

After a dogfood pass, run:
  AUTOCOMPLETE_LAB_TRACE_START_LINE=$START_LINE ./script/check_trace_eval.sh

For Codex only:
  AUTOCOMPLETE_LAB_TRACE_START_LINE=$START_LINE AUTOCOMPLETE_LAB_TRACE_REQUIRE_APP=com.openai.codex ./script/check_trace_eval.sh
EOF
