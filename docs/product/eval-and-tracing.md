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

Or turn screenshots on for only the current app from Diagnostics. Screenshot traces are stored beside the JSONL log and linked from the exported report.

The app also keeps local compatibility learning here:

```text
~/Library/Application Support/AutocompleteLab/compatibility-learning.json
```

That file can hold per-app visual offsets, render-mode overrides, screenshot-tracing state, observation counts, and confidence. This is the first self-healing layer: small learned adjustments can apply at runtime, while bigger repeated misses become adapter patches.

For quick visual calibration, use the menu bar nudge actions while the target app is focused:

- `Nudge Suggestion Up/Down/Left/Right`
- `Reset Current App Learning`

Nudges are local, per app, and take effect on the next suggestion.

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

Events include app bundle id, request mode, field identity, prompt/output when available, displayed text, accepted text, outcome, reason, latency, screenshot path, caret/panel geometry, and compatibility-learning metadata.

## What To Evaluate

Track these rates per app and request mode:

- shown suggestions
- accepted with Tab
- accepted with backtick
- ignored by continued typing
- suppressed as empty, meta, repeated context, or invalid word completion
- insertion verification failures

Use the in-app Diagnostics window for the quickest read. It shows why a
suggestion is missing right now, recent suppressed reasons in plain language,
top misses, accept rates by app/mode, pause/delete controls, screenshot tracing,
current learned adapter state, and an HTML export.

When a tester says "nothing showed up," check `Why no suggestion` first. It
should name the active blocker: missing Accessibility permission, app paused or
disabled, model not ready, diagnostics-only profile, secure/sensitive field,
missing caret/anchor trust, or no focused text field. Then check `Recent trace
events` for the exact event and `Suppressed by reason` for repeats.

Use the command-line checker for repeatable proof:

```bash
./script/check_trace_eval.sh
```

By default, this also enforces geometry proof for every shown suggestion: `anchorSource`, `anchorQuality`, `anchorReason`, `anchorCanPresent`, and a concrete anchor rect must be present and internally consistent. Set `AUTOCOMPLETE_LAB_TRACE_REQUIRE_GEOMETRY_PROOF=0` only when reviewing old trace slices.

Compare local model latency after a trial launch:

```bash
script/model_latency_report.py --latest
AUTOCOMPLETE_LAB_MODEL=qwen35-9b ./script/build_and_run.sh --verify
```

Supported override names include `qwen35-4b`, `qwen35-9b`, `qwen3-1.7b`, `qwen3-0.6b`, `gemma-4-e4b`, `gemma-4-e4b-it-optiq`, and `gemma-4-26b`.

Try shorter or longer streamed phrase suggestions without editing code:

```bash
AUTOCOMPLETE_LAB_MODEL=gemma-4-e4b-it-optiq AUTOCOMPLETE_LAB_VISIBLE_WORDS=3 ./script/build_and_run.sh --verify
AUTOCOMPLETE_LAB_MODEL=gemma-4-e4b-it-optiq AUTOCOMPLETE_LAB_VISIBLE_WORDS=10 AUTOCOMPLETE_LAB_MAX_GENERATED_TOKENS=16 ./script/build_and_run.sh --verify
```

After a manual model trial, require enough samples before trusting the result:

```bash
script/model_latency_report.py --latest --require-timing-samples 5 --require-shown-samples 5
```

For a clean app-specific slice:

```bash
START_LINE=$(wc -l < "$HOME/Library/Logs/AutocompleteLab/traces.jsonl" | tr -d ' ')
# do the manual app pass
AUTOCOMPLETE_LAB_TRACE_START_LINE=$START_LINE \
AUTOCOMPLETE_LAB_TRACE_REQUIRE_APP=com.apple.TextEdit \
  ./script/check_trace_eval.sh
```

Or use the helper, which prints the exact command to run after your dogfood pass:

```bash
./script/trace_mark.sh
```

For repeated dogfood sessions, save a mark and report from it later:

```bash
./script/trace_mark.sh --save
# type for a while
./script/trace_mark.sh --eval com.openai.codex
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
