# Eval And Tracing

This is the local tuning loop for making autocomplete better before it becomes customer-facing.

## Local Tracing

Tracing is local-only and enabled for the lab by default. The default trace is
redacted.

Disable it for a run with:

```bash
AUTOCOMPLETE_LAB_TRACE=0 ./script/build_and_run.sh
```

The app writes redacted JSONL to:

```text
~/Library/Logs/AutocompleteLab/traces.jsonl
```

Raw local debug traces are opt-in and written separately:

```bash
AUTOCOMPLETE_LAB_RAW_TRACE=1 ./script/build_and_run.sh
```

```text
~/Library/Logs/AutocompleteLab/raw-traces.jsonl
```

Enable optional local screenshot traces only with raw debug tracing on:

```bash
AUTOCOMPLETE_LAB_RAW_TRACE=1 AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/build_and_run.sh
```

Or turn screenshots on for only the current app from Diagnostics after enabling
raw debug tracing. Screenshot traces are stored beside the JSONL logs and linked
from raw debug events only, not from the redacted report.

The app also keeps local compatibility learning here:

```text
~/Library/Application Support/AutocompleteLab/compatibility-learning.json
```

That file can hold per-app visual offsets, render-mode overrides, screenshot-tracing state, observation counts, and confidence. This is the first self-healing layer: small learned adjustments can apply at runtime, while bigger repeated misses become adapter patches.

Compatibility learning is not a support claim by itself. Treat it as a code
candidate only when all of these are true:

- at least 5 observations for the same bundle id,
- confidence is at least 0.75,
- the reason is `manual-visual-nudge` or `screenshot-visual-correction`,
- the offset is reproduced on the current commit with screenshot-backed smoke,
- no wrong-app insertion, sensitive-field, or Tab-capture failure appears in
  the same slice.

Use the report helper to separate low-confidence learning from code candidates:

```bash
script/compatibility_self_healing_report.py
```

The default code-promotion thresholds are 5 observations and 0.75 confidence.
Lower them only for a local experiment, not for beta support language.

For quick visual calibration, use the menu bar nudge actions while the target app is focused:

- `Nudge Suggestion Up/Down/Left/Right`
- `Reset Current App Learning`

Nudges are local, per app, and take effect on the next suggestion.
For a screenshot-free placement readout, run:

```bash
script/visual_calibration_report.py
```

The report uses redacted caret, render-mode, learning-offset, flicker, and
caret-failure metadata only. It does not read or link screenshots.

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
- `acceptedTextEdited`
- `appPaused`
- `appDisabled`
- `caretGeometryFailed`

Default events include app bundle id, request mode, field identity, outcome,
reason, latency, counts, lengths, field metadata, caret/panel geometry, and
compatibility-learning metadata. Raw context, prompts, model output, displayed
text, accepted text, remaining visible text, and screenshot paths are removed
from the default trace. They are written only to `raw-traces.jsonl` when raw
local debug tracing is explicitly enabled.

The headline product metric is accepted-and-kept, not raw accept rate. Accepted text is compared at 2s, 10s, 30s, and field blur. Durable checkpoint events store survival class, token recall, edit distance, accepted length, timing metadata, and redacted fingerprints. They should not need the current field text on disk.

The RAM-only audit proof is the `acceptanceRetentionCleared` event. It records
the clear reason, accepted text length, fingerprint metadata, and
`rawAcceptedTextDurable=false`, but not the accepted raw text.

## What To Evaluate

Track these rates per app and request mode:

- shown suggestions
- accepted with Tab
- accepted with backtick
- accepted-and-kept shown rate
- accepted-and-kept accepted rate
- accepted-and-kept slices by app, field kind, render mode, insertion mode,
  request mode, model, and experiment arm
- median edit distance after accept
- median first edit delay after accept
- ignored by continued typing
- suppressed as empty, meta, repeated context, or invalid word completion
- annoyance score and annoyance signal counts
- insertion verification success
- insertion verification failures

Use the in-app Diagnostics window for the quickest read. It shows recent
redacted trace events, top misses, accept rates by app/mode, support state,
pause/delete controls, raw debug state, screenshot tracing, current learned
adapter state, and a redacted HTML export.

Use the command-line checker for repeatable proof:

```bash
./script/check_trace_eval.sh
```

Compare local model latency after a trial launch:

```bash
script/model_latency_report.py --default-model-proof
AUTOCOMPLETE_LAB_MODEL=qwen35-9b ./script/build_and_run.sh --verify
```

Supported override names match the runtime and download helper:
`qwen35-4b`, `qwen3.5-4b`, `qwen35-9b`, `qwen3.5-9b`,
`qwen3-1.7b`, `qwen3-0.6b`, `gemma-4-e2b`, `gemma-4-e4b`,
`gemma4-e4b`, `gemma-4-e4b-4bit`, `gemma-4-e4b-it-optiq`,
`gemma-4-e4b-it-optiq-4bit`, `gemma4-e4b-it-optiq`, and
`gemma-4-26b`.

Try shorter or longer streamed phrase suggestions without editing code:

```bash
AUTOCOMPLETE_LAB_MODEL=gemma-4-e4b-it-optiq AUTOCOMPLETE_LAB_VISIBLE_WORDS=3 ./script/build_and_run.sh --verify
AUTOCOMPLETE_LAB_MODEL=gemma-4-e4b-it-optiq AUTOCOMPLETE_LAB_VISIBLE_WORDS=10 AUTOCOMPLETE_LAB_MAX_GENERATED_TOKENS=16 ./script/build_and_run.sh --verify
```

After a manual model trial, require enough samples before trusting the result:

```bash
script/model_latency_report.py --latest --require-timing-samples 5 --require-shown-samples 5
script/model_latency_report.py --default-model-proof
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

For the lab, raw local traces can still be useful when tuning model behavior,
but they are an explicit debug mode. Do not upload typed text, prompts, outputs,
screenshots, or accepted text without explicit user consent.
