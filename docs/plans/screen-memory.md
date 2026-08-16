# Screen Memory — agent implementation plan

Status: PROPOSED. Owner approval = merging this PR. Do not begin Phase 1+
until Phase 0 (governance) is merged. This plan is the single source of truth
for the feature; update it in-place as phases land.

## Mission and philosophy

Give Tilde sight and memory: on-device OCR of the full screen, an
understanding layer that classifies what the user is doing, a redaction gate
that strips secrets, and persistence of the redacted text into the encrypted
Personal History store as training data for the personal model.

Owner-set philosophy ("local maximalism", decided 2026-08-16): the privacy
boundary is the DEVICE, not the capture. Because nothing ever leaves the Mac,
Tilde may capture and retain what cloud products never could. The reversal of
the prior OCR ban is deliberate and goes on the record in Phase 0.

Non-negotiables that survive from the old covenant:
- On-device only. No cloud, no network egress, ever. Release egress proofs
  stay blocking and unchanged.
- Secrets never persist. Redaction runs BEFORE storage, fail-closed: if the
  redactor errors, the capture is dropped, never stored raw.
- User sovereignty: master toggle (off by default at launch), per-app
  exclusions (shared with Personal History), one-click delete-everything,
  visible storage meter. Secure Event Input suspends capture unconditionally.
- No raw screen text in logs, diagnostics, or any report. Sentinel-tested.

## Prior art to port, not rebuild

- July lineage (checkout `/Users/redbars/redbars/code/transcripted-autocomplete-lab`):
  `script/ocr_probe.swift` (capture+Vision spike), `script/ocr_eval.py`
  (context-arm eval), docs/quiz-lessons.md "Screen context (OCR) is worth a
  lot" (EM@1 14.5%→17.2% with OCR context). Port concepts and prompt shapes;
  the code predates the current architecture, so re-implement inside it.
- Redaction model: `nvidia/gliner-PII` (HF), non-generative span detector,
  55+ entity types, ~92% recall, trained on the Nemotron-PII synthetic set.
- Measurement machinery that now exists and July lacked: golden_eval,
  replay-eval (`--replay-eval-json`), shown/accepted counters, synthetic
  typist arena (session scratchpad `typist_arena.py` — port to
  `script/` when the context arm needs it).

## Architecture placement (repo rules apply)

- `Sources/AutocompleteLabApp` owns: ScreenCaptureKit capture, Vision OCR,
  TCC permission flow, redactor model runtime, persistence. It is already the
  sole owner of Personal History; Screen Memory extends that ownership.
- `Sources/AutocompleteLabCore` owns (pure, deterministic, tested): scene
  classification policy, context assembly/budgeting, redaction RULES layer
  (regex/checksum — the model layer stays app-side), event types and their
  size caps, retention policy.
- `Sources/InlineGhostIME` is UNCHANGED. Screen context joins the prompt
  app-side in the completion engine; the IME never sees screen data.
- Every PR: tests with behavior, `./script/proof.sh fast` green, implement →
  independent review (codex-reviewer) → fix pass. Small PRs; the complexity
  budget gate applies (feature additions per the documented structural-rule
  scoping, see commit 05734565).

## Phase 0 — Governance (1 PR, blocks everything)

1. AGENTS.md: replace the OCR/Screen-Recording ban with the Screen Memory
   covenant: on-device only; redact-before-persist fail-closed; capture
   excluded in secure input and excluded apps; no screen text in
   diagnostics; owner-visible controls mandatory.
2. PRIVACY.md: new section — what is captured (full display OCR text), when
   (event-driven, listed triggers), where it lives (encrypted store, path,
   key custody), what never persists (redacted spans, excluded apps, secure
   input), how to see usage (storage meter) and delete (delete-all also
   destroys the key). State plainly that the OTHER side of a conversation
   appears on screen and is captured; per-app exclusion is the control.
3. docs/security/threat-model.md: new assets (screen text at rest/in
   memory), new adversaries considered (local malware reading the store —
   mitigated same as Personal History; shoulder-surfing the purple indicator
   is the honesty feature), residual risks stated honestly.
4. Roadmap pointer from docs/model-lessons.md ("screen context, July
   evidence" entry) to this plan.

## Phase 1 — Capture engine (2 PRs)

PR 1a `claude/screen-capture-engine`:
- `ScreenCaptureService` (app): ScreenCaptureKit full-display capture.
  Triggers: focused-window change; typing-pause ≥2s while a completion
  session is active; hard cadence cap 1 capture / 5s; nothing when the
  toggle is off, screen is locked, secure input is active, or frontmost app
  is excluded.
- Vision `VNRecognizeTextRequest` (accurate mode) per display; output
  blocks: {text, boundingBox, windowOwnerBundleID?, windowTitle?} using
  SCWindow metadata to attribute text to windows where possible.
- Output struct `ScreenSnapshot` is memory-only in this phase. No storage.
- TCC flow: menu item requests Screen Recording permission with a plain
  explanation sheet; degraded-gracefully when denied (feature simply off,
  status line in menu says so).
- Tests: trigger policy (Core-side `CaptureTriggerPolicy`), exclusion logic,
  cadence cap. Capture itself gets a manual probe script only
  (`script/screen_capture_probe.swift`, real caller: this plan's Phase 4
  battery/latency measurements).

PR 1b `claude/screen-capture-power`:
- Instrumented duty-cycle: capture+OCR time per event, events/hour, added
  battery draw measured via `powermetrics` sampling harness; budget: <2%
  battery/day, OCR p95 <250ms per capture on M1. Results recorded in
  docs/model-lessons.md. If over budget: drop capture resolution first
  (OCR tolerates 0.5x), then cadence.

## Phase 2 — Scene understanding + prompt assembly (2 PRs)

PR 2a `claude/scene-classifier` (Core, pure):
- `ScreenScene.classify(snapshot, frontmostBundleID, fieldText) -> Scene`
  where Scene = {mode: replying|referencing|composing,
  conversationTurns: [{speaker: self|other, text}], referenceSnippets:
  [String]}.
- Heuristics v1 (deterministic, tested; no LLM):
  - frontmost app ∈ chat registers AND OCR blocks form a vertical
    message-list geometry above the field → replying; alternate-speaker
    attribution by horizontal alignment buckets (left/right) when
    detectable, else mark speaker unknown-other.
  - OCR text from a NON-frontmost window while composing in frontmost →
    referencing; snippet = the largest text block sharing ≥1 rare word
    (tf-idf against a small stopword list) with the current sentence.
  - else composing.
- Everything capped: ≤3 turns, ≤600 chars turns total, ≤400 chars reference,
  deduped against field text (no double-feeding what IMKit already sees).
- Optional Gemma micro-classification (single 6-token prompt) behind
  `TILDE_SCENE_LLM=1` dev flag; ships only if it beats heuristics in the
  Phase 4 arena A/B.

PR 2b `claude/context-prompt-assembly`:
- Extend `RawContinuationPrompt` with an optional context block per mode
  (replying: "Conversation:\n<turns>\n" prefix; referencing:
  "Reference:\n<snippet>\n"), preserving the existing scaffold and the
  3,000-char total budget (context block gets at most 1,000 of it; field
  text always wins ties). Engine (`LlamaCompletionEngine`) consumes the
  latest fresh `ScreenSnapshot`-derived Scene (staleness cap 20s) — never
  awaits capture; absent/stale scene = exactly today's behavior.
- Tests: budget math, staleness, dedupe, prompt snapshots per mode.

## Phase 3 — Redaction + persistence (3 PRs)

PR 3a `claude/redaction-rules` (Core, pure):
- `SecretRules.scrub(text) -> (clean, findings)`: Luhn-validated card
  numbers; IBAN; SSN patterns; API-key shapes (AWS `AKIA…`, `sk-…`,
  `ghp_…`, generic high-entropy ≥32-char tokens); JWTs; PEM blocks; email
  and phone (configurable, default scrub for persistence, keep for
  prompt-context); replacement token `⟨redacted:type⟩`. Table-driven, one
  test vector per rule, plus a planted-secrets corpus test asserting 100%
  rule-layer recall on structured secrets.

PR 3b `claude/redaction-model`:
- Convert `nvidia/gliner-PII` to Core ML (script `script/convert_gliner.py`,
  operator-run like model packaging; pin by sha256 in the release driver as
  a second bundled model input). Bundle adds ~300–400MB — owner accepted.
- App-side `RedactionService`: rules first, GLiNER spans second (confidence
  ≥ threshold, default 0.5), applied to every ScreenSnapshot BEFORE any
  persistence. Fail-closed: model load/inference error → capture dropped,
  `screen-capture-dropped reason=redactor` diagnostic (count only).
- Default-excluded apps regardless of user settings: password managers
  (1Password, Bitwarden, KeePass*, Keychain Access), Terminal in secure
  input. List lives in Core, tested.
- Redaction eval harness `script/redaction_eval.py`: synthetic corpus of
  planted secrets in realistic screen text (generate via agents, commit the
  corpus — synthetic only); blocking bar: ≥99% recall structured (rules),
  ≥90% recall unstructured (model layer), measured per release like the
  golden eval self-test.

PR 3c `claude/screen-memory-store`:
- New `PersonalHistoryEvent` case `screenContext`: {app, windowTitle?,
  sceneMode, redactedText ≤4KB, capturedAt}. Same encrypted append-only
  store, same Keychain key, same consent-identifier regime.
- Retention: rolling byte budget (default 256MB) with oldest-first pruning;
  storage meter line in the menu ("Screen Memory: N MB · last capture …");
  delete-all wipes screen events with everything else (already does, same
  store — add a test proving it).
- Training feed rules (IMPORTANT, tested):
  - SELF-typed text (existing insertion events) remains the ONLY trainer of
    the personal next-word model's "how I write" table.
  - screenContext events feed a separate context-prior table (what
    conversations I'm in look like) consumed at blend time; they NEVER
    enter the self-writing table (the model must not learn to write like
    the user's interlocutors).
  - Replay-eval may reconstruct scene context for boundaries (flagged arm
    `--context screen`), enabling offline A/B of context on/off on real
    history going forward.
  - Fine-tune export is explicit-user-action only (out of scope here; note
    for the fine-tune plan).

## Phase 4 — Proof gates (1 PR + runs)

- Arena context arm: extend the typist arena so personas emit a synthetic
  "screen" (the conversation prior turns) delivered via the Scene path;
  A/B accept and interruption rates, context on vs off. Ship-bar: accept
  rate up, interruption rate not up.
- Golden eval context arm: corpus records already carry `prior_messages`;
  feed them through the Scene path in a `--arm context` run. Bar: ≥ +2
  EM@1 points (July precedent +2.7).
- Replay A/B on real history once ≥1 week of screenContext events exist.
- Latency: suggestion p50 unchanged (capture is async; assert no lock
  contention via timing test).
- Privacy sentinels: extend the golden-eval-style selftest — plant sentinel
  strings in a fake snapshot, assert they appear in NO log, diagnostic,
  report, or store-when-redacted path.
- Battery: PR 1b harness re-run with full pipeline.

## Phase 5 — Rollout

1. Dev flag dogfood (owner only), 1 week, watching menu accept-rate and
   `screen-capture-*` counters. Turn the flag on with
   `defaults write bar.r3d.tilde ScreenMemoryDevMode -bool true` — this is
   the form that survives a normal Finder/Dock launch (Tilde is an
   `LSUIElement` app, so it does not inherit a Terminal shell's exported
   environment). `TILDE_SCREEN_MEMORY_DEV=1` still works for a one-off
   Terminal-launched run. Either is sufficient; see
   `TildeSettings.screenMemoryDevModeEnabled`.
2. Opt-in menu toggle "Screen Memory (local only)", default OFF, shipped
   through the standard notarized release driver (remember: helper sha
   re-pin after each release re-sign; GLiNER model becomes a third pinned
   input).
3. After 14 days of owner data: keep opt-in vs default-on decision, recorded
   in docs/model-lessons.md with the numbers.

## PR series summary (order, each small, each reviewed)

0. governance (docs only)
1a. capture engine  1b. power budget
2a. scene classifier  2b. prompt assembly
3a. redaction rules  3b. redaction model  3c. store + training feeds
4. proof harnesses + runs (arena/quiz/replay context arms, sentinels)
5. rollout toggle + release

## Risks and mitigations

- Recall-lesson risk (local capture ≠ perceived-safe): mitigations are the
  product features themselves — encryption, exclusions, meter, delete-all,
  redaction eval bar, purple indicator. PRIVACY.md states the counterparty
  reality plainly.
- TCC re-consent nags: accepted UX cost; menu shows permission state.
- Bundle grows ~400MB (redactor): owner accepted (precedent: model bundle
  grew 1.5GB for Gemma 4).
- OCR quality on low-contrast/retina-scaled text: measured in 1b; not a
  blocker (bad OCR text mostly fails the scene classifier and is unused).
- Speaker attribution errors poison context turns: capped influence (≤600
  chars), never trains the self table, and the arena A/B will catch net harm.

## Open questions for the owner (answer before Phase 3)

1. Retention budget default: 256MB rolling OK, or larger?
2. Emails/phone numbers: scrub from PERSISTED text by default (plan says
   yes) — confirm, since they're also genuinely useful personal vocabulary.
3. Browser private-browsing windows: attempt detection and skip (best
   effort), or treat like any window?
