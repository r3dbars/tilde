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

## 2026-07-22 — GEMMA RECIPE SOLVED: E4B + scaffolded raw completion

- **The winning combination:** llama.cpp 10080 + `google/gemma-4-E4B-it-qat-q4_0-gguf`
  + RAW completion mode (no chat template → no thinking) + a 2-example
  "documents being continued" scaffold + strip the trailing space + stop on
  newline, temperature 0, ~14 tokens.
- **Measured: 106–248ms per suggestion** (owner's bar: 200–300ms). Quality on
  the exact probes Qwen failed: casual register natural and in-voice ("way
  better than " → "I thought it would."), persona repro continues the USER
  ("I'm curious to see if it can handle complex instructions."), email prose
  excellent ("get approval from the board before we can move forward").
- **Mid-word remains weak** (" thing", "te a clear set") — by design the
  dictionary layer owns mid-word; the llama.cpp bridge should NOT route
  wordCompletion mode to Gemma.
- **NEXT (the build): llama-server bridge** — app manages the llama-server
  process (launchd-style child, port or unix socket), a `CompletionEngine`
  conformance speaks /completion with this recipe, phraseContinuation routes
  to Gemma/llama.cpp while wordCompletion stays MLX/dictionary; per-model
  engine choice behind the same ghost socket. Server restart for iteration:
  `llama-server -hf google/gemma-4-E4B-it-qat-q4_0-gguf --port 8873 -c 2048`.
- Prior investigation details below (MLX dead end; E2B/config modes).

## 2026-07-22 — Gemma quest: MLX dead end, llama.cpp promising

- **Gemma-4-on-MLX: DEAD END (three strikes).** (1) E4B it-OptiQ: loads only
  via our hand patch, ~1.1s. (2) plain-4bit E2B: PLE shape mismatch
  ("per_layer_model_projection… Actual [8960,192], expected [8960,384]").
  (3) OptiQ E2B: missing quant keys ("layers.15.self_attn.k_proj.weight not
  found"). mlx-swift-lm Gemma 4 support is not production-ready; python
  mlx-lm on this machine too old to cross-check (py3.9 / mlx_lm 0.29 has no
  gemma4). Qwen3.5-4B restored as MLX default. Do not retry MLX-Gemma until
  mlx-swift-lm ships native Gemma 4 support.
- **llama.cpp + Gemma 4 E2B (google/gemma-4-E2B-it-qat-q4_0-gguf): the engine
  story is excellent, the prompt story needs work.**
  - brew llama.cpp 8500 predates Gemma 4 ("unknown model architecture:
    gemma4") — upgraded to 10080, loads and runs flawlessly.
  - **Latency: warm full suggestions ~100-160ms; mid-word ~35-70ms** with
    llama-server's built-in prompt cache (`cache_prompt`) — comfortably under
    the owner's 200-300ms bar. Engine reliability + speed thesis CONFIRMED.
  - **Quality per mode:** CHAT mode: E2B-QAT is thinking-first; with default
    template all tokens went to reasoning_content; with `--reasoning-budget 0`
    the narration leaked into content ("The user wants me to continue…").
    RAW completion: email prose genuinely good ("are aiming for a launch by
    the end of Q3"), but casual register gave empties/artifacts ("100%…" after
    trailing-space prompts — strip the trailing space before prompting), and
    mid-word suffixes unreliable ("somet" → "ing" [someting]). ASSISTANT-
    PREFILL: llama-server did not continue the final assistant message
    (restarted the turn) — needs the continue-final-message capability or
    template surgery.
  - **Restart for iteration:** `llama-server -hf
    google/gemma-4-E2B-it-qat-q4_0-gguf --port 8873 -c 2048
    --reasoning-budget 0`.
- **Next (scoped):** (a) raw-mode scaffold: few-shot header + trailing-space
  fix + stop-sequences, re-probe casual register; (b) try E4B QAT GGUF
  (Cotypist's quality tier) same way; (c) if quality lands, build the
  llama-server bridge behind `CompletionEngine` (app manages the process;
  same socket protocol; per-model engine choice — Qwen/MLX and
  Gemma/llama.cpp can coexist).

## 2026-07-22 — screen context round, part 4 (the leak was the FALLBACK)

- **Persona refusals persisted after part 3's fix — root cause found:** the
  refusal ghosts were never Qwen. When the brain answers EMPTY (its confidence
  gate choosing silence — very common in casual text), `GhostBrainClient`
  returned nil, indistinguishable from "brain unreachable", so the IME fell
  through to **Apple's FoundationModels fallback** — which had none of the
  persona fixes and no cleaner. Fixes, all **KEEP**:
  1. Wire semantics: an answered-but-empty response now returns "" (silence to
     be respected); nil strictly means unreachable. **Apple fires only when the
     app is actually down.**
  2. Apple session instructions get the same identity anchor (user's own
     voice, never a chatbot, questions continued not answered).
  3. IME-side `cleanedModelOutput` now kills persona markers — insurance for
     the Apple path, which bypasses the engine's cleaner.
  LESSON: every model path needs the same output discipline — a fallback
  without the filters becomes the loudest voice precisely when the main model
  is being appropriately quiet.
- **Model taste (owner):** Qwen judged "really horrible" for this use vs
  Gemma's prose (Cotypist evidence). Deep-dive research into Gemma MLX quants
  (HF) running — candidates must hit <400ms/suggestion and ideally have
  copyable caches. Results to be recorded here.

## 2026-07-22 — screen context round, part 3 (persona-slip fix)

- **Assistant-persona leak (dogfood catch, screenshot):** with an AI
  conversation on screen and typed text that questioned/addressed an AI, the
  model slipped into chatbot persona: ghost = "I'm sorry, but as an AI chatbot
  developed". Repeating pattern. Three-layer fix, all **KEEP**:
  1. System prompt identity anchor (top of prompt): "You type the next words IN
     THE USER'S OWN VOICE… never a chatbot… a question gets continued, never
     answered."
  2. OCR guidance: even when the visible context is an AI conversation, only
     ever continue the USER's side; never adopt a persona from the screen.
  3. Cleaner backstop `isAssistantPersonaLeak`: persona markers anywhere in a
     candidate ("as an AI", "language model", "AI chatbot", "I cannot
     assist"…) reject it; plain human apologies still pass. Focused test pins
     the live repro.
  Verified on the exact repro: normal continuations, no persona.
- **Residual quirks observed (OPEN):** (a) the model can predict "your next
  words" by COPYING your own draft/message visible elsewhere on screen —
  technically banned by guidance but not enforced; candidate lever: cleaner
  dedupe of candidates against visible-context lines. (b) 4-word-span
  repetition of the current sentence is prompt-banned but not
  cleaner-enforced; candidate lever if seen in dogfood.

## 2026-07-22 — screen context round, part 2 (latency-first + relationship-aware)

- **Event-driven capture (owner's design):** screenshots now happen at capture
  MOMENTS — app activation (NSWorkspace observer; OCR completes while the human
  is still settling into the window), new field session (field identity change
  on the socket), or typing resuming after an 8s idle gap. **While a burst is
  active the attached context is FROZEN** so the prompt prefix stays stable and
  the KV cache keeps hitting; if a burst starts before its capture lands, the
  context attaches once mid-burst then freezes. Verified: `page:true` with
  stable context through a burst; memory steady (~5.6GB RSS, no leak).
  **KEEP.** (Earlier app "crash" was self-inflicted: raw-binary launches
  bypassed single-instance dedupe → two 5.6GB instances → system kill. Always
  launch via `open`.)
- **Relationship-aware OCR guidance (owner catch):** raw OCR text was framed
  without telling the model WHAT it is. `promptGuidance` rewritten: it is a
  noisy snapshot of the visible screen, never text to continue; its
  relationship to the typing is unknown and must be inferred — a message being
  REPLIED to (reply should address it), source material being commented on,
  the user's own earlier writing (stay consistent), or unrelated UI. Grounding
  uses (names, register, topic, style) spelled out; OCR-chrome and quoting
  bans kept. OCR eval suite assertions updated to the new phrases. Verified
  live: "Yes I agree, the screen aware approach " → "is the best way forward"
  with our conversation on screen.

## 2026-07-22 — screen context round

- **Screen-context (OCR) wired into IME requests.** The pre-keyboard
  `VisiblePageContextProvider` (ScreenCaptureKit + Vision OCR, cached,
  permission-gated) was dormant; `GhostScreenContextBridge` now feeds it from
  socket requests, deriving capture geometry from the requesting app's
  frontmost window (CGWindowList — the IME has no AX geometry). Enabled via
  the existing `VisiblePageContextEnabled` default (owner opted in; Screen
  Recording granted + app relaunched). Server responses report `"page":bool`
  for observability. **Verified live:** with this conversation on screen,
  "I hope the " → "OCR pipeline is" — the model used on-screen text. **KEEP.**
- **Mechanics:** first request in a field kicks the async capture (no context
  yet); subsequent requests attach the cached OCR text. Refresh cadence is the
  provider's own policy.
- **OPEN:** (a) each OCR refresh changes the top of the prompt → prompt KV
  cache resets — consider freezing page context per field session to protect
  hit latency; (b) app denylist for never-capture apps; (c) measure suggestion
  quality lift vs the extra ~200 prompt tokens; (d) the model self-censoring in
  casual text may improve with page context (higher confidence) — re-probe.

## 2026-07-22 — edge-case hardening round

- **Ghost committed by mouse click (code-audit catch):** `commitComposition` was
  not overridden, and the default can COMMIT marked text when the client ends
  composition (click, caret move, focus shift) — inserting an unaccepted ghost
  as real text. Now overridden to clear instead: **the ghost only ever becomes
  text via explicit Tab/Shift-Tab.** **KEEP** — trust-critical invariant.
- **Option-key passthrough:** Option combos now pass through untouched so
  dead-key accents (Option-E, e → é) and special characters (©, ñ, ø) compose
  normally; previously the printable branch could commit the raw dead-key char.
  **KEEP.** Manual verification of é-composition still needed (dead-key state
  machine interaction with IMEs is subtle).
- **Free rides confirmed by design:** secure/password fields bypass third-party
  input methods entirely (macOS routes around us); Tab keeps its day job
  whenever no ghost is showing; the IME process is respawned on demand by
  imklaunchagent after a crash (typing continues after ~a keystroke).
- **Known open edge cases (manual test checklist):** undo granularity after
  accepts (Cmd+Z), autocorrect coexistence, key-repeat (held keys), non-US
  keyboard layouts under the IME, emoji picker input, dictation interplay,
  IME kill mid-sentence (crash-recovery drill), marked-text behavior in
  Google Docs (custom composition handling).

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
- **Prefix cache SHIPPED (three coordinated changes):**
  1. **Prompt style v12 (core):** all instructions (including the answer label)
     moved into the SYSTEM prompt; the user prompt is context-terminal — ends
     with "Before cursor:\n<context>". Consecutive keystrokes now strictly
     extend the previous prompt's tokens.
  2. **Two-stage prefill (runtime):** stage 1 brings the cache to end-of-prefix
     state and stores a copy; stage 2 appends the template's closing markers
     (~9 tokens, probe-measured once per model) and generates.
  3. **2-token boundary margin:** the stored prefix ends 2 tokens before the
     context end, because the trailing space/partial word re-tokenizes when the
     next word arrives ("outputs " + "feel" → space merges into "Ġfeel") and a
     stored cache ending on a volatile token forces an untrimmable miss.
  **Measured on hit: firstChunk 13ms (was ~250ms); first ghost word ~70ms,
  final ~134ms — UNDER the 150ms model-only threshold.**
- **Hit-rate reality (from diagnostics, mixed real+bench traffic):** hits fire
  during continuous same-paragraph typing (the hot path). Dominant miss is
  `paragraph-changed` (RuntimeSessionCachePolicy resets the cache when the
  current paragraph is no longer an extension — i.e., every Enter/newline),
  then `field-changed` (honest cold start). **OPEN levers:** (a) relax the
  paragraph guard — token-prefix checking in the lookup already guarantees
  correctness, so the guard mostly costs hits; (b) the cache holds ONE entry —
  per-field entries would survive brief app/field switches; (c) re-verify the
  residual `untrimmable-prompt-cache` misses disappear post-margin.
- **"Suffix" label echo (dogfood catch, same day):** prompt v12's
  "Answer with: Suffix:" system line made the model sometimes echo the literal
  word "Suffix" as the ghost. **Fixed in v13**: the answer label is gone
  entirely (the instructions already specify the format — the label was legacy
  priming for base models), and `CompletionOutputCleaner` now rejects
  colon-less bare label echoes ("Suffix", "Next words", "Next 3-8 words…") as
  a permanent backstop with a focused test. Verified on the exact repro:
  "…it is intere" → "sted". LESSON: when relocating prompt text, watch for the
  model treating instructions as content to echo.
- **Model-only routing threshold (≤150ms) is now MET on cache hits.** Decision:
  dogfood the feel first; flip to model-only once hit rate is proven in real
  typing (paragraph guard relaxation likely needed first).
- **Quality triage (owner: "longer suggestions are really really bad" +
  "instant words feel turned off").** Diagnosed via socket probes + diagnostics:
  (1) In casual/chat-style text the engine SUPPRESSES its phrase output
  (`low-top-score`, 0.75–0.85 vs threshold; `no-candidates`) — so what the owner
  saw as "bad long suggestions" was the FAST layer's generic word chains
  (common-next-word table strung 4 deep) standing unreplaced. (2) Mid-word,
  erratic small-model suffixes ("want to underst" → "anding") were overwriting
  precise dictionary completions. Email-style prose on cache hits was GOOD
  ("coordinate with" → "the backend team"), so this is context-dependent
  confidence, not cache corruption.
  **Fix (silence beats junk):** generic common-next-word table DELETED (fast
  layer now needs real evidence: doc vocab, dictionary, doc bigrams ≥2, phrase
  openers); mid-word the model no longer overwrites a non-empty fast completion
  (it only fills gaps); boundary phrases remain model-only-when-confident.
  Expected feel: quieter, but every ghost is either precise or confident.
  **OPEN:** ranker threshold for casual registers (0.75–0.85 candidates might
  deserve display in chat contexts); send fieldKind/behavior hints through the
  socket so profiles apply.
