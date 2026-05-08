#!/usr/bin/env bash
set -euo pipefail

TRACE_PATH="${AUTOCOMPLETE_LAB_TRACE_PATH:-$HOME/Library/Logs/AutocompleteLab/traces.jsonl}"
MARK_PATH="${AUTOCOMPLETE_LAB_TRACE_MARK_PATH:-$HOME/Library/Logs/AutocompleteLab/trace-start-line.txt}"
MODE="${1:-}"
APP_BUNDLE_ID="${2:-}"

if [[ -f "$TRACE_PATH" ]]; then
  START_LINE="$(wc -l <"$TRACE_PATH" | tr -d ' ')"
else
  START_LINE=0
fi

case "$MODE" in
  --quiet)
    echo "$START_LINE"
    exit 0
    ;;
  --save)
    mkdir -p "$(dirname "$MARK_PATH")"
    printf "%s\n" "$START_LINE" >"$MARK_PATH"
    echo "Saved trace mark: $START_LINE"
    echo "Marker: $MARK_PATH"
    exit 0
    ;;
  --eval|--replay)
    if [[ ! -f "$MARK_PATH" ]]; then
      echo "trace mark missing: $MARK_PATH" >&2
      echo "Run ./script/trace_mark.sh --save before the dogfood pass." >&2
      exit 1
    fi

    SAVED_LINE="$(tr -d '[:space:]' <"$MARK_PATH")"
    if [[ -z "$SAVED_LINE" ]]; then
      echo "trace mark is empty: $MARK_PATH" >&2
      exit 1
    fi

    if (( START_LINE <= SAVED_LINE )); then
      echo "Trace: $TRACE_PATH"
      echo "Saved mark: $SAVED_LINE"
      echo "Current line: $START_LINE"
      echo "No new trace events since the saved mark."
      echo "Type for a bit, accept/dismiss a few suggestions, then run this again."
      exit 0
    fi

    if [[ "$MODE" == "--replay" ]]; then
      swift run AutocompleteTraceReplay --start-line "$SAVED_LINE" "$TRACE_PATH"
      exit 0
    fi

    if [[ -n "$APP_BUNDLE_ID" ]]; then
      AUTOCOMPLETE_LAB_TRACE_START_LINE="$SAVED_LINE" \
      AUTOCOMPLETE_LAB_TRACE_REQUIRE_APP="$APP_BUNDLE_ID" \
        ./script/check_trace_eval.sh
    else
      AUTOCOMPLETE_LAB_TRACE_START_LINE="$SAVED_LINE" \
        ./script/check_trace_eval.sh
    fi
    exit 0
    ;;
  "")
    ;;
  *)
    echo "usage: $0 [--quiet|--save|--eval [bundle-id]|--replay]" >&2
    exit 2
    ;;
esac

cat <<EOF
Trace: $TRACE_PATH
Start line: $START_LINE

After a dogfood pass, run:
  AUTOCOMPLETE_LAB_TRACE_START_LINE=$START_LINE ./script/check_trace_eval.sh

For dogfood apps:
  AUTOCOMPLETE_LAB_TRACE_START_LINE=$START_LINE AUTOCOMPLETE_LAB_TRACE_REQUIRE_APP=com.openai.codex ./script/check_trace_eval.sh
  AUTOCOMPLETE_LAB_TRACE_START_LINE=$START_LINE AUTOCOMPLETE_LAB_TRACE_REQUIRE_APP=com.anthropic.claude-code ./script/check_trace_eval.sh

Shortcut:
  ./script/trace_mark.sh --save
  # do the dogfood pass
  ./script/trace_mark.sh --eval com.openai.codex
  ./script/trace_mark.sh --eval com.anthropic.claude-code
  ./script/trace_mark.sh --replay
EOF
