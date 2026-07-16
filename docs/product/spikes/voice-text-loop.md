# Voice → Text Loop Spike

Date: 2026-06-14
Status: spike (design doc + isolated core PoC). Not wired into the app. Off by
default.

## Verdict

The defensible idea is real and the prediction seam is cheap: feeding recent
**spoken** transcript text into the existing doc-local n-gram path makes a
phrase the user only *said* surface as an inline suggestion, with no new model,
no audio, and no network. This spike proves that in pure core with unit tests.

Recommendation: **graduate to a gated internal dogfood**, not to beta. The
prediction mechanism is proven; what is unproven is the *privacy plumbing* for a
second sensitive text source. Graduation work is privacy proof, not modeling.
See [Recommended next step](#recommended-next-step).

## Why this is defensible

SteadyType already owns the hard part of inline prediction: caret tracking,
quiet-unless-invited gating, safe insertion, and a local model runtime.
Transcripted already owns local dictation. The durable wedge is the **loop**
between them:

- Cotypist-style autocomplete has no audio layer — it can only predict from what
  you typed.
- Dictation tools (Apple Dictation, Whisper/Superwhisper-style apps) transcribe
  speech but have no inline next-phrase prediction.
- Apple is unlikely to connect a third-party dictation buffer to a third-party
  autocomplete engine.

Predicting **in the user's own recent voice** — using both typed history *and*
recently spoken transcript history, fused on-device — is something neither side
of the market does today. The signal is also unusually good: people often say a
phrase moments before they type it ("ok so the launch is gated on the latency
budget…" → then they type "The launch is gated on the…"). That is exactly the
n-gram continuation this path is built to complete.

## What this spike builds (and what it does not)

Built — all pure `AutocompleteLabCore`, off by default:

- `RecentSpokenTranscriptProviding` — the one protocol seam against
  Transcripted. Returns recent spoken snippets, oldest-first.
- `InMemorySpokenTranscriptProvider` and `SpokenTranscriptFixture` — stub
  providers (in-memory list, or parsed from a local fixture file's text). No
  audio, no Transcripted dependency, no I/O in core.
- `RecentSpokenContextPolicy` — the opt-in flag plus bounds (`isEnabled` default
  **false**, `maxEntries`, `maxCharactersPerEntry`).
- `VoiceContextPhrasePredictor` — the fusion wrapper. Owns the flag + provider,
  delegates all matching to the unchanged doc-local predictor. This is the whole
  graduation/throwaway unit.
- One additive change to `DocLocalNGramPhrasePredictor`: a
  `spokenContextTexts: [String] = []` parameter and a third corpus source,
  `spoken-transcript`.

All of the above live in
`Sources/AutocompleteLabCore/Engine/VoiceContextPhrasePredictor.swift` plus the
small parameter on
`Sources/AutocompleteLabCore/Engine/DocLocalNGramPhrasePredictor.swift`. Tests:
`Tests/AutocompleteLabCoreTests/VoiceContextPhrasePredictorTests.swift`. Sample
fixture: `docs/product/spikes/voice-text-loop-sample-transcript.txt`.

Deliberately **not** built:

- No real Transcripted audio/transcript wiring.
- No network or upload of any kind.
- No `SuggestionOrchestrator` / app-runtime wiring. The spike is core-only so it
  cannot change live behavior or the privacy export surface until graduation.
- No new model. This reuses the deterministic n-gram path, not the MLX engine.

To **discard**: delete `VoiceContextPhrasePredictor.swift`, its test file, this
folder, and the one `spokenContextTexts:` parameter. Nothing else depends on it.

## Data flow

```
Transcripted (separate app)                SteadyType
─────────────────────────                  ──────────
 mic → local dictation                     typed text + caret context
        │                                            │
        ▼  (on-device only)                          │
 recent transcript buffer                            │
        │                                            │
        │  RecentSpokenTranscriptProviding  ◄── integration boundary
        ▼  .recentSpokenContextEntries()             │
 RecentSpokenContextPolicy (opt-in flag, bounds)     │
        │  []  when disabled / no provider           │
        ▼                                            ▼
        └────────────►  DocLocalNGramPhrasePredictor  ◄── typed + local-page corpora
                         (matches a suffix of what you're typing against the
                          spoken corpus; emits the continuation that followed)
                                     │
                                     ▼
                         CommonPhraseContinuationSelection → normal gates → ghost text
```

The integration boundary is exactly one protocol method,
`recentSpokenContextEntries() -> [String]`. A graduated build implements it by
reading Transcripted's already-on-device, already-redacted recent transcript
buffer (e.g. a local file or shared container Transcripted writes). The spike
implements it with a fixture. **Raw transcript text never leaves the Mac and is
never uploaded** — it is read locally, matched locally, and only a short
continuation is ever shown.

## How spoken text becomes a prediction signal

The doc-local predictor already builds n-gram "corpora" from two sources: the
text before the cursor (`before-cursor`) and remembered local page context
(`local-context`). It looks for the longest suffix of what you are currently
typing that also appears earlier in a corpus, then offers the words that
followed it there.

This spike adds a third corpus source, `spoken-transcript`, fed from the bounded
spoken entries. Because the matching engine is shared, a spoken phrase competes
on the same footing as typed text. Worked example (from the tests and the sample
fixture):

- Spoken earlier: *"Let's circle back on the latency budget before the beta
  cutoff"*
- Now typing: *"I think we should circle back on the"*
- Suggestion: *" latency budget before the beta cutoff"* — surfaced purely from
  the spoken corpus, tagged `order-4-spoken-transcript` in the trace metadata.

**Recency weighting falls out for free.** The predictor already scores a match
higher the later it appears in its corpus (`startIndex / corpusTokenCount`).
Entries are ordered oldest-first and joined as separate lines, so the freshest
utterance scores highest — the "recency-weighted personalization signal" with no
new scoring code.

**Precedence is conservative.** When typed/local context and the spoken corpus
match equally well, typed wins (source rank `before-cursor < local-context <
spoken-transcript`). Speech augments the typed signal; it never overrides what
the user can already see. Behavior-profile gating is unchanged, so spoken
context is still blocked in search/code/forms/prompt fields exactly like the
typed path.

## Privacy stance

Spoken text is **at least as sensitive as typed text** — arguably more, because
people dictate things they would not type in public. So it inherits every rule
in [PRIVACY-BETA.md](../../../PRIVACY-BETA.md) and adds none of its own
loopholes:

1. **On-device only.** The transcript is read locally through the provider
   seam, matched locally, and discarded. There is no remote path, consistent
   with "What Is Never Uploaded By Default."
2. **Opt-in, default off.** `RecentSpokenContextPolicy.isEnabled` defaults to
   `false`. With the flag off (or no provider), `contextTexts(...)` returns `[]`
   and the prediction path is byte-for-byte identical to today's typed-only
   behavior. A unit test locks this in.
3. **Bounded.** Only the most recent `maxEntries` are kept, each capped to
   `maxCharactersPerEntry`, so a long dictation session cannot grow the matching
   window without limit.
4. **Redacted traces.** The predictor emits only shape metadata
   (`docLocalNGramMatch=order-4-spoken-transcript`), never raw spoken text. A
   test asserts a private sentence in the spoken corpus does not appear in trace
   metadata, matching the existing doc-local redaction test.

### Sentinel coverage (required before graduation)

The export proof in
[`RawTraceReportExportTests.swift`](../../../Tests/AutocompleteLabAppTests/RawTraceReportExportTests.swift)
plants private *sentinels*, runs the visible Settings exporter's implementation,
and fails if any sentinel survives. Because this spike adds **no app or runtime
surface**, there is nothing for that test to catch yet — and adding a spoken
sentinel now would be dishonest proof (it could never appear). That gate becomes
mandatory the moment spoken text touches the app:

- Add a spoken-specific sentinel (e.g. `proof-private-spoken-…`) to the test's
  synthetic inputs and private-sentinel checks, so a leak of spoken text into
  any shareable file or trace field fails the build.
- Add a spoken-text row to
  [docs/product/beta-privacy-data-checklist.md](../beta-privacy-data-checklist.md)
  and note the Transcripted local-read dependency in
  [docs/product/dependency-sdk-data-inventory.md](../dependency-sdk-data-inventory.md).

Until those exist, the honest claim is: *the prediction mechanism is proven; the
spoken-text privacy proof is pending.*

## Proof status

- 11 new pure-core tests in
  `Tests/AutocompleteLabCoreTests/VoiceContextPhrasePredictorTests.swift` cover:
  spoken-only surfacing (wrapper, raw seam, and fixture paths), off-by-default,
  trace-metadata redaction, profile gating, typed-over-spoken precedence, and
  policy/fixture bounds.
- `swift test --jobs 1` passes (full suite green).
- No proof-manifest, compatibility, or export claims were broadened.

## Open questions

- **Where does the transcript come from concretely?** A file Transcripted
  writes, a shared App Group container, or an XPC read? Whatever it is must be
  local and let the user see/clear it.
- **How aggressively should speech be weighted vs. typing?** The spike keeps
  spoken below typed on ties. Personalization might want spoken *above* generic
  local-page context. Needs dogfood signal, not a guess.
- **Staleness / scope.** How recent is "recent" (last N minutes? this field
  only?), and should spoken context reset on app/field switch like the doc-local
  field corpus does?
- **Entry-boundary correctness.** Entries are newline-joined so continuations do
  not bleed across utterances; confirm that holds for multi-line transcripts.
- **Does it actually feel like "me"?** N-gram replay surfaces *exact* spoken
  phrases. True voice-style personalization may eventually want the spoken corpus
  to condition the MLX engine, not just the n-gram path. Bigger, separate spike.
- **Annoyance.** Surfacing things you said out loud could feel surprising.
  Needs the same non-annoyance pass the typed path went through.

## Recommended next step

**Graduate to a gated internal dogfood (Justin-only), behind the existing
flag**, in this order:

1. Land the spoken sentinel in `RawTraceReportExportTests` and the
   privacy-checklist/dependency rows **first** (privacy proof before wiring).
2. Wire `VoiceContextPhrasePredictor` into `SuggestionOrchestrator` next to the
   existing `docLocalContextTexts` path, reading a local fixture or a real
   Transcripted local buffer via the provider seam, still default-off.
3. Dogfood: does a just-spoken phrase completing as you type feel helpful or
   uncanny? Answer the weighting and annoyance questions with real use.

Discard if step 3 shows the suggestions feel intrusive or the privacy plumbing
for a second sensitive source proves heavier than the benefit. The isolation
above makes that a clean revert.
