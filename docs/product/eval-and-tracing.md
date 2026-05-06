# Eval And Tracing

This is the local tuning loop for making autocomplete better before it becomes customer-facing.

Phase zero privacy rule: beta and customer language starts with local aggregate counters only. Raw text traces and debug screenshots require a clear local opt-in.

## Local Tracing

Tracing is local-only. Internal lab runs can use raw traces. Beta/customer runs should keep raw tracing off unless the tester turns on local debug capture.

Disable it for a run with:

```bash
AUTOCOMPLETE_LAB_TRACE=0 ./script/build_and_run.sh
```

The app writes JSONL to:

```text
~/Library/Logs/AutocompleteLab/traces.jsonl
```

Enable optional local screenshot traces only for local debugging:

```bash
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/build_and_run.sh
```

Or turn screenshots on for only the current app from Diagnostics. Screenshot traces are stored beside the JSONL log and linked from the exported report.

The app also keeps local compatibility learning here:

```text
~/Library/Application Support/AutocompleteLab/compatibility-learning.json
```

That file can hold per-app visual offsets, render-mode overrides, screenshot-tracing state, observation counts, and confidence. This is the learned self-healing layer: small learned adjustments can apply at runtime, while bigger repeated misses become adapter patches.

The live placement health layer runs before a suggestion is shown. It trusts a caret only when the rect is finite, caret-shaped, and inside the focused element/window. If the caret is missing, invalid, or outside the focused bounds, the app either heals to a floating mirror anchor or suppresses the suggestion when detached anchors are disabled for that app. Traces mark these cases with `placementSelfHealingApplied`, `placementSelfHealingAction`, `placementHealthReason`, `placementAnchorSource`, `placementConfidenceScore`, and `placementConfidenceBand`.

The live suggestion quality layer is intentionally conservative. Streaming phrase partials do not show until they have enough visible words to be worth looking at, tiny repeated word completions are suppressed more aggressively, ignored suggestions are learned as misses, and any normal typing key invalidates the current visible suggestion before Tab/backtick can accept it. The app should feel calmer, even if that means showing fewer completions.

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

Events include app bundle id, request mode, field identity, outcome, reason, latency, caret/panel geometry, and compatibility-learning metadata.

When raw tracing is explicitly enabled, events can also include prompt/output, displayed text, accepted text, and screenshot paths.

## What To Evaluate

Track these rates per app and request mode:

- shown suggestions
- accepted with Tab
- accepted with backtick
- ignored by continued typing
- suppressed as empty, meta, repeated context, or invalid word completion
- insertion verification failures

Use the in-app Diagnostics window for the quickest read. It shows the current suggestion verdict, recent trace events, top misses, accept rates by app/mode, pause/delete controls, screenshot tracing, current learned adapter state, and an HTML export.

Use the command-line checker for repeatable proof:

```bash
./script/check_trace_eval.sh
```

Fail a slice when any shown suggestion has missing or low placement confidence:

```bash
AUTOCOMPLETE_LAB_TRACE_REQUIRE_CONFIDENT_PLACEMENT=1 ./script/check_trace_eval.sh
```

Compare local model latency after a trial launch:

```bash
script/model_latency_report.py --latest
AUTOCOMPLETE_LAB_MODEL=qwen35-4b ./script/build_and_run.sh --verify
```

Supported override names include `qwen35-4b`, `qwen35-9b`, `qwen3-1.7b`, `qwen3-0.6b`, `gemma-4-e4b`, `gemma-4-e4b-it-optiq`, and `gemma-4-26b`.

Try shorter or longer streamed phrase suggestions without editing code:

```bash
AUTOCOMPLETE_LAB_MODEL=qwen35-4b AUTOCOMPLETE_LAB_VISIBLE_WORDS=3 ./script/build_and_run.sh --verify
AUTOCOMPLETE_LAB_MODEL=qwen35-4b AUTOCOMPLETE_LAB_VISIBLE_WORDS=10 AUTOCOMPLETE_LAB_MAX_GENERATED_TOKENS=16 ./script/build_and_run.sh --verify
```

After a manual model trial, require enough samples before trusting the result:

```bash
script/model_latency_report.py --latest --require-timing-samples 5 --require-shown-samples 5
```

Check whether typing stayed fast at the keyboard event tap:

```bash
START_LINE=$(wc -l < "$HOME/Library/Logs/AutocompleteLab/diagnostics.log" | tr -d ' ')
# type normally with a visible suggestion, then:
AUTOCOMPLETE_LAB_LOG_START_LINE=$START_LINE ./script/check_typing_performance_log.sh
```

The typing guard fails on `keyboard-event-tap-latency-slow`,
`keyboard-event-tap-disabled`, raw latency above 8000us, or a latency summary
whose p95/max is above 8000us. Use
`AUTOCOMPLETE_LAB_TYPING_PERF_REQUIRE_SAMPLES=1` when the slice must prove real
event-tap traffic.

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

For Claude Code dogfooding, use the same flow with the Claude Code bundle:

```bash
START_LINE=$(wc -l < "$HOME/Library/Logs/AutocompleteLab/traces.jsonl" | tr -d ' ')
# type in the Claude Code prompt, accept with Tab/backtick, but do not submit
AUTOCOMPLETE_LAB_TRACE_START_LINE=$START_LINE \
AUTOCOMPLETE_LAB_TRACE_REQUIRE_APP=com.anthropic.claude-code \
  ./script/check_trace_eval.sh
```

## Current Product Boundary

For the internal lab, raw local traces are useful because the user is tuning their own local model behavior.

For beta or customer-facing language, keep raw tracing disabled by default and require a clear local-only debug toggle. Do not upload typed text, prompts, outputs, accepted text, or screenshots.
