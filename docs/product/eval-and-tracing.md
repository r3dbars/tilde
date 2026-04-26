# Eval And Tracing

This is the local tuning loop for making autocomplete better before it becomes customer-facing.

## Local Raw Tracing

Raw tracing is off by default.

Enable it only for private local tuning:

```bash
AUTOCOMPLETE_LAB_RAW_TRACE=1 ./script/build_and_run.sh
```

The app writes JSONL to:

```text
~/Library/Logs/AutocompleteLab/raw-traces.jsonl
```

Each `model-result` row records:

- request mode: `phraseContinuation` or `wordCompletion`
- app bundle id
- raw `textBeforeCursor` and `textAfterCursor`
- system prompt and user prompt
- raw model output
- cleaned visible suggestion

Each `acceptance` row records:

- accepted action: `acceptNextWord` or `acceptAllVisible`
- app bundle id
- accepted text
- remaining visible suggestion

## What To Evaluate

Track these rates per app and request mode:

- shown suggestions
- accepted with Tab
- accepted with backtick
- ignored by continued typing
- suppressed as empty, meta, repeated context, or invalid word completion
- insertion verification failures

## Current Product Boundary

For the lab, raw traces are useful because the user is tuning their own local model behavior.

For a customer-facing app, keep raw tracing disabled by default and require a clear local-only debug toggle. Do not upload typed text, prompts, outputs, or accepted text without explicit user consent.
