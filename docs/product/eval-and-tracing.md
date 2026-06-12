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

## Personal Capture Dogfood Loop

Personal Capture is not default tracing. It is a local, opt-in Justin dogfood
mode that writes daily Markdown to:

```text
~/Library/Application Support/SteadyType/Personal Capture
```

The journal records new writing fragments, verified accepted suggestions, and
accepted-kept survival signals. It exists to tune whether SteadyType starts to
sound like the person using it.

Suggestion Episodes are the structured version of this loop. Each safe,
presented suggestion can get a local JSONL episode with app, field, reply
context, user text, suggested text, accepted text, action, model/prompt version,
placement, screenshot-captured flag, and latency. Later checkpoints append
whether the accepted text survived at 2s, 10s, 30s, 1m, 5m, blur, or send.

The episode store also writes `Episodes/YYYY-MM-DD-dashboard.md`, a local
scorecard for accepted/kept/deleted-fast signals, eval-case count, latency, and
model/prompt rows. The in-app Diagnostics window shows the same summary when
Personal Capture is on.

It stays separate from redacted diagnostics and Privacy Bundles. The capture
policy still blocks secure, login, password, OTP, payment, URL/search,
API-key-like, password-manager, private prompt/search, unproven browser, and
other sensitive fields before Markdown is written.

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

Nudges are explicit local opt-in actions. Autocomplete Lab must not infer,
store, or apply visual calibration automatically for a beta/customer user.
Only local dogfood/lab runs may use screenshot-backed visual calibration, and
only after screenshot tracing is explicitly enabled for that app or run.

ScreenCaptureKit and Vision are useful dogfood candidates for measuring
caret/suggestion alignment from local screenshots, but they stay out of the
private beta path for now. The product path remains AX geometry plus explicit
local nudges until screenshot/Vision calibration has fixture proof, current app
smoke proof, and a visible opt-in control.

Nudges are local, per app, and take effect on the next suggestion.
For a screenshot-free placement readout, run:

```bash
script/visual_calibration_report.py
```

The report uses redacted caret, render-mode, learning-offset, flicker, and
caret-failure metadata only. It does not read or link screenshots. Its
self-test uses a fixture JSONL slice and is part of `script/smoke_test.sh`.

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

The headline product metric is accepted-and-kept, not raw accept rate. Accepted text is compared at 2s, 10s, 30s, 1m, 5m, field blur, and send. Durable checkpoint events store survival class, token recall, edit distance, accepted length, timing metadata, and redacted fingerprints. They should not need the current field text on disk.

Acceptance events also carry log-safe proof that inserted text came from the
visible suggestion slice: accepted character count, pre-accept visible character
count, remaining visible character count, visible-prefix/full-visible match
flags, and the acceptance source. Raw text is still only available when local
debug tracing is explicitly enabled.
Set `AUTOCOMPLETE_LAB_TRACE_REQUIRE_ACCEPTANCE_SLICE_PROOF=1` with
`script/check_trace_eval.sh` to fail any slice where accepted events lack this
proof.

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
- suppressed as empty, meta, repeated context, duplicate/restart, or invalid word completion
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

All-history trace output is diagnostic only. The log can contain old branches,
old app versions, failed experiments, and stale proof attempts, so do not use it
to raise or lower beta support grades. Product proof must use a fresh marked
slice from `trace_mark.sh` or explicit `AUTOCOMPLETE_LAB_TRACE_START_LINE` and
`AUTOCOMPLETE_LAB_TRACE_END_LINE` bounds.

Compare local model latency after a trial launch:

```bash
script/model_latency_report.py --default-model-proof
script/latency_benchmark_report.py --beta-gate
script/runtime_performance_report.py
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
script/latency_benchmark_report.py --beta-gate
script/runtime_performance_report.py
```

Use `script/runtime_performance_report.py` for the broader performance read:
latest runtime asset, cold app launch-to-ready time, warm/model-load time,
first visible latency, first token, total generation, event-tap overhead, AX
read windows, live RSS/CPU, a rough battery risk label, and installed supported
model sizes. It reads diagnostic metadata and process stats only; it does not
store typed text, prompts, model output, screenshots, document names, URLs, or
trace lines.

## Local Quality Audit

Raw content quality audits are local opt-in only. Use disposable prompts, and do
not use real private writing unless you explicitly choose to debug that text on
this machine.

Run the current local model against a JSONL prompt set:

```bash
AUTOCOMPLETE_LAB_LOCAL_QUALITY_AUDIT=1 \
AUTOCOMPLETE_LAB_RUNTIME_BACKEND=mlx \
  ./script/local_quality_audit.py \
    --input /path/to/disposable-prompts.jsonl \
    --generate \
    --min-overall 92 \
    --min-relevance 72
```

The default report prints aggregate labels and row ids only. It scores
relevance, literal continuation, assistant voice, wrong topic, too long,
structural breakage, unsafe or sensitive content, and repetition. It does not
persist raw prompt text or raw model output by default.

Only include raw output for a short local debug session with disposable prompts:

```bash
AUTOCOMPLETE_LAB_LOCAL_QUALITY_AUDIT=1 \
AUTOCOMPLETE_LAB_LOCAL_QUALITY_AUDIT_INCLUDE_RAW=1 \
  ./script/local_quality_audit.py \
    --input /path/to/disposable-prompts.jsonl \
    --generate \
    --include-raw-output
```

Self-test the audit harness with fixtures:

```bash
./script/check_local_quality_audit_self_test.sh
```

The checked daily-driver audit report is guarded in smoke tests:

```bash
./script/check_daily_driver_local_quality_audit_report.sh
```

Wrong-field safety proof should stay in the default smoke path too:

```bash
./script/check_prompt_app_proof_self_test.sh
./script/check_prompt_app_manifest_proof_self_test.sh
./script/check_sensitive_field_proof_self_test.sh
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
./script/trace_mark.sh --replay
./script/trace_mark.sh --replay smoke-slice
```

`--eval` runs the trace evaluation script from the saved mark. `--replay`
runs `AutocompleteTraceReplay` against only the fresh JSONL rows after that
mark, so stale historical trace rows do not mask current proof. The default
replay profile is `full`; use `smoke-slice` for bounded real-app smoke proof
that does not try to prove stale cancellation, annoyance, final kept horizon,
or model-result candidate metadata in the same slice.

For the daily-driver dogfood loop, prefer the wrapper that creates a local
redacted Markdown report:

```bash
./script/daily_driver_dogfood_session.sh status --app md.obsidian
./script/daily_driver_dogfood_session.sh start --app md.obsidian --label obsidian-note
# write normally for 10-20 minutes; accept, dismiss, and type through naturally
./script/daily_driver_dogfood_session.sh finish --app md.obsidian
# fill the Manual Trust Row in the report
./script/daily_driver_dogfood_session.sh review --report dist/daily-driver-dogfood/...
```

The report goes under `dist/daily-driver-dogfood/` by default. It includes the
session sample gate, non-annoyance gate, trace eval output, line bounds, and a
manual trust row. By default, `finish` requires at least 5 active minutes,
5 shown suggestions, 1 phrase suggestion, 1 accepted suggestion,
1 accepted-and-kept signal, 1 instant phrase fallback with <=1ms recorded
latency, a 15% accepted-kept / shown reach rate, and an 85/100 redacted
typing-feel score. Phrase suggestions must include metadata showing at least 3
visible words, so one-word or two-word phrase nubs do not count as daily-driver
proof. The typing-feel score summarizes shown/min,
accepted-kept rate, typed-over rate, accepted-then-deleted, late suggestions,
insertion failures, and caret failures without raw text. Use
`--min-kept-per-shown-percent` only when a specific dogfood lane needs a
stricter reach bar. Use `--allow-low-sample` only for harness/debug slices, not
daily-driver proof. Do not paste raw writing, prompts, screenshots, document
names, URLs, recipients, or subjects into that manual row.
Run `status` before `start` if possible. The dogfood gate records whether
SteadyType was running when the session began, and a session that starts while
the app is off does not count as daily-driver proof.
The same report has a trust-killer gate that fails closed on failed or duplicate
insertions, wrong-context accept suppression, caret geometry failures,
sensitive-field or unsupported-app presentations, detached placement without a
caret, focus steals, Tab conflicts, accepted-then-deleted signals, prompt-submit
risk, unsafe full accepts, and prompt content violations.
After filling the Manual Trust Row, `review --report` verifies that the automated
gate passed, the manual labels are filled, the app cell matches the report app
filter, the session minutes meet the active-minute minimum, the user reached for
it, suggestion quality is scored 4 or 5, placement is not described as wrong or
unstable, and they would keep it on tomorrow. The finished report also includes
a redacted safety snapshot for prompt no-submit and sensitive-field suppression,
and `review` fails closed if the safety snapshot or trust-killer pass marker is
missing or failed.

For a frozen replay slice, capture both bounds:

```bash
START_LINE=$(wc -l < "$HOME/Library/Logs/AutocompleteLab/traces.jsonl" | tr -d ' ')
# type for a while
END_LINE=$(wc -l < "$HOME/Library/Logs/AutocompleteLab/traces.jsonl" | tr -d ' ')
swift run AutocompleteTraceReplay \
  --profile smoke-slice \
  --start-line "$START_LINE" \
  --end-line "$END_LINE" \
  "$HOME/Library/Logs/AutocompleteLab/traces.jsonl"
```

For Codex dogfooding, use:

```bash
START_LINE=$(wc -l < "$HOME/Library/Logs/AutocompleteLab/traces.jsonl" | tr -d ' ')
# type in the Codex message box, accept with Tab/Shift-Tab, but do not submit
AUTOCOMPLETE_LAB_TRACE_START_LINE=$START_LINE \
AUTOCOMPLETE_LAB_TRACE_REQUIRE_APP=com.openai.codex \
  ./script/check_trace_eval.sh
```

## Current Product Boundary

For the lab, raw local traces can still be useful when tuning model behavior,
but they are an explicit debug mode. Do not upload typed text, prompts, outputs,
screenshots, or accepted text without explicit user consent.
