# Eval And Tracing

This is the local tuning loop for making autocomplete better before it becomes customer-facing.

## Local Tracing

Tracing is local-only and enabled for the lab by default.

Disable it for a run with:

```bash
AUTOCOMPLETE_LAB_TRACE=0 ./script/build_and_run.sh
```

The app writes JSONL to:

```text
~/Library/Logs/AutocompleteLab/traces.jsonl
```

Enable optional local screenshot traces with:

```bash
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/build_and_run.sh
```

## Trace Events

Each suggestion gets a `suggestionID` and emits lifecycle events:

- `suggestionRequested`
- `modelResult`
- `suggestionPresented`
- `suggestionAccepted`
- `suggestionTypedOver`
- `suggestionHidden`
- `suggestionSuppressed`
- `insertionVerified`
- `insertionFailed`

Events include app bundle id, request mode, field identity, prompt/output when available, displayed text, accepted text, outcome, reason, and latency.

## What To Evaluate

Track these rates per app and request mode:

- shown suggestions
- accepted with Tab
- accepted with backtick
- ignored by continued typing
- suppressed as empty, meta, repeated context, or invalid word completion
- insertion verification failures

Use the in-app Diagnostics window for the quickest read. It shows recent trace events, top misses, accept rates by app/mode, pause/delete controls, and an HTML export.

Use the command-line checker for repeatable proof:

```bash
./script/check_trace_eval.sh
```

For a clean app-specific slice:

```bash
START_LINE=$(wc -l < "$HOME/Library/Logs/AutocompleteLab/traces.jsonl" | tr -d ' ')
# do the manual app pass
AUTOCOMPLETE_LAB_TRACE_START_LINE=$START_LINE \
AUTOCOMPLETE_LAB_TRACE_REQUIRE_APP=com.apple.TextEdit \
  ./script/check_trace_eval.sh
```

For Codex dogfooding, use:

```bash
START_LINE=$(wc -l < "$HOME/Library/Logs/AutocompleteLab/traces.jsonl" | tr -d ' ')
# type in the Codex message box, accept with Tab/backtick, but do not submit
AUTOCOMPLETE_LAB_TRACE_START_LINE=$START_LINE \
AUTOCOMPLETE_LAB_TRACE_REQUIRE_APP=com.openai.codex \
  ./script/check_trace_eval.sh
```

## Current Product Boundary

For the lab, raw local traces are useful because the user is tuning their own local model behavior.

For a customer-facing app, keep raw tracing disabled by default and require a clear local-only debug toggle. Do not upload typed text, prompts, outputs, or accepted text without explicit user consent.
