# IME tuning log

A running lab notebook for the input-method experience. Every lever we pull gets
an entry: what we tried, why, what happened, verdict. Newest entries at the top
of each section. Add an entry BEFORE tweaking a lever — check here first so we
never re-run a dead experiment.

Verdicts: **KEEP** (shipped, working) · **REVERTED** (tried, undone — reason
recorded) · **DEAD END** (proven impossible, do not retry) · **OPEN** (needs
more dogfood data).

## Current dial settings

| Dial | Value | Where |
|---|---|---|
| Pause before ghost appears | 180ms | `GhostInputController.scheduleGhostAfterPause` |
| Min letters before dictionary completes | 3 | `GhostInputController.dictionaryCompletion` |
| Min context before model is asked | 12 chars | `GhostInputController.requestModelGhost` |
| Context sent to model | last 1000 chars | `GhostInputController.requestModelGhost` |
| Fast-layer chain length | 4 words | `GhostInputController.predict` |
| Model | Gemma E4B it-OptiQ 4bit | `RuntimeBootstrapPlan.preferredMLX` |
| Prompt KV cache | on (default) | `AUTOCOMPLETE_LAB_MLX_KV_CACHE` |
| Socket timeout (IME side) | 700ms | `GhostBrainClient.timeout` |
| Accept keys | Tab=word, Shift-Tab=all, Esc=dismiss | `GhostInputController.handle` |

## 2026-07-22 — foundation day

### Rendering channel
- **Marked text via IMKit** — inline suggestions render inside the app's own
  text in TextEdit, Notes, Obsidian, Chrome, Atlas, Claude Code. **KEEP** —
  this is the product architecture.
- **Grey ghost styling** — custom attributes (`.foregroundColor`,
  `.underlineStyle: 0`, `.underlineColor: .clear`, `.markedClauseSegment`) all
  ignored by NSTextView; all four TSM hilite presets (`kRawText`,
  `kConvertedText`, `kSelectedConvertedText`, `kNoHilite`) render IDENTICALLY
  (composing underline, normal text color). **DEAD END** — third parties cannot
  style marked text; the underline is permanent. Owner accepted it.
- **Caret position during ghost** — `selectionRange (0,0)` keeps the caret
  before the ghost in NSTextView apps; Chromium-family apps draw it at the
  ghost's END regardless. **DEAD END** (app-controlled) — mitigated by
  pause-debounce below.

### Rhythm / feel
- **Per-keystroke ghost re-display** — felt aggressive, and caret got visually
  lost while typing fast. **REVERTED** in favor of:
- **180ms pause-debounce** — ghost only appears when typing rests; caret stays
  normal while fingers move. **KEEP** — solved both complaints in one move.
  Dial: 180ms; snappier or lazier is a one-line change.
- **Auto-space after accept** — accepting the last word (or whole ghost) adds a
  trailing space so typing continues with the next word; typing `.` `,` etc.
  right after swallows the space (iOS-style). **KEEP** — owner-requested QoL.

### Acceptance
- **Multi-word chains, Tab=one word (stable chain, no re-roll),
  Shift-Tab=all, Esc=dismiss** — **KEEP**; owner: "works amazingly."
- **Tilde as accept-all** — floated, not wired. **OPEN** — conflict: `~` is a
  real character; stealing it while a ghost shows breaks typing literal `~`.

### Fast layer (instant, no model)
- **Doc-vocabulary completion only** (spike v1) — completes only words already
  typed this session. Felt dumb alone. **KEEP as first preference** but:
- **System dictionary fallback** (`NSSpellChecker.completions`,
  likelihood-ranked, 3+ letters) — instant real vocabulary, zero shipped data.
  **KEEP**. Noise dial = min-letters (3).
- **Doc bigrams + common next-word table + phrase openers** — chain filler.
  **KEEP** for now; candidate for deletion if model-only proves out (below).

### Model layer
- **Apple FoundationModels as the brain** — worked, decent continuations,
  ~word-boundary only. **KEEP as fallback** when the app/socket is down.
- **SteadyType MLX over unix socket** (`GhostBrainServerHost` ⇄
  `GhostBrainClient`, newline-JSON) — **KEEP**. Qwen3.5-4B measured
  300–360ms warm (no cache identity), mid-word wordCompletion mode 110–240ms.
- **Server infers engine mode** — mid-word → `.wordCompletion`, boundary →
  `.phraseContinuation`. Fixed garbled mid-word answers (phrase mode returned
  " ime to get it right" for "somet"). **KEEP**.
- **Generation counter drops stale model answers** — no ghosts for text you've
  moved past. **KEEP**.

### Deployment facts (cost hours; never rediscover)
- Bundle ID must contain `.inputmethod.` · notarization mandatory (Gatekeeper
  silently hides unnotarized IMEs) · register via `TISRegisterInputSource`
  (re-run if TextInputMenuAgent restarts) · first-ever registration needed a
  full restart · user must add + switch keyboard in System Settings manually.
  All encoded in `script/build_ime.sh` + `Sources/InlineGhostIME/README.md`.

## 2026-07-22 — latency & model round

- **Gemma E4B it-OptiQ as default model** — measured through the full socket
  path on the owner's machine: **~1.05–1.15s per suggestion, flat**. Identical
  repeated contexts: no speedup (so not a prefill/cache issue — that's the
  model's generation cost here). Tiny context: same ~1.1s AND returned empty.
  ~3.5× slower than Qwen3.5-4B (4bit) on the same path. **REVERTED** same day —
  Qwen3.5-4B stays default. **OPEN follow-ups:** try Gemma E2B (not on disk
  yet) and other E4B quants/runtimes before declaring Gemma dead; the owner
  likes its prose taste in Cotypist.
- **KV-cache identity through the socket** — discovery: the prompt KV cache was
  ON all along but MISSED every IME request because `appBundleIdentifier` and
  `fieldIdentityDescription` were absent (miss reasons: missing-app /
  missing-field-identity). IME now sends `client.bundleIdentifier()` +
  `client.uniqueClientIdentifierString()`. Measured with Qwen: cold 458ms →
  warm ~315–330ms; identical repeats plateau at ~315ms. **KEEP** — modest win;
  at 1000-char contexts generation dominates, not prefill, so the cache alone
  can't reach 150ms. Note: `.wordCompletion` mode never uses the cache by
  design — only boundary requests benefit.
- **Context sent to model: 300 → 1000 chars** — no measurable latency penalty
  with cache identity in place. **KEEP**.
- **Model-only routing** (drop the instant layer entirely) — DECISION RULE
  agreed with owner: flip only if boundary latency ≤ ~150ms. Measured floor is
  ~315ms → **rule not met; two layers stay** for now.
- **Streaming first tokens through the socket** — server forwards
  `onPartialSuggestion` partials as `{"suggestion":…,"partial":true}` lines;
  IME presents each partial (stale-guarded), final replaces. Measured: 3
  partials per response, **first partial ~270–290ms vs final ~315–345ms** —
  only ~45ms saved, because generation doesn't START until ~250ms in (see
  next entry). **KEEP** — harmless now, multiplies once prefill is fixed
  (first chunk would land ~30–80ms).
- **ROOT CAUSE of the ~250ms floor (diagnosed from `mlx-completion-timing` in
  `~/Library/Logs/SteadyType/diagnostics.log`):** warm boundary request at
  ~1,040 prompt tokens = prepare 19ms + session 20ms + **firstChunk ~250ms**
  (prefill) + short tail. KV cache verdict: **miss, reason
  `untrimmable-prompt-cache`** — the prompt template appends closing markers
  AFTER the user context, so cache reuse requires trimming those suffix tokens,
  and this model's cache type cannot trim. Every keystroke re-prefills the
  full prompt. Also learned: identical-context repeats miss by design
  (`empty-token-append`), so never benchmark the cache with identical prompts.
  Diagnostics decode trick: values are privacy-redacted to `String(N chars)` —
  decode enum values by length (miss=4, untrimmable-prompt-cache=24).
- **NEXT LEVER (well-scoped): prefix-only prompt cache.** Store/reuse the KV
  cache for system+context only (everything BEFORE the template's closing
  markers), so consecutive keystrokes append cleanly with no trimming. Expected
  to cut firstChunk from ~250ms to tens of ms; combined with streaming, first
  ghost words at ~50–100ms — under the 150ms model-only threshold. **OPEN.**
