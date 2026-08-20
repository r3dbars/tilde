# Model lessons

Durable, measured findings about Tilde's model and evaluation. Newest first.
Add an entry only with numbers behind it; superseded entries get corrected, not
deleted.

## 2026-08-16 — Screen Memory capture power probe (Phase 1b)

Built `script/capture_power_probe.sh` (real caller: this entry) to check
Screen Memory's two Phase 1b budgets — battery < 2%/day, capture+OCR p95 <
250ms — against a dev build (`script/build_and_run.sh`'s `dist/Tilde.app`,
never `/Applications`), isolated from the owner's real running Tilde via the
existing `--release-proof` lane (dedicated port 17873; the duplicate-instance
guard makes a colliding second production-mode launch self-terminate before
touching anything, so release-proof plus `TILDE_SCREEN_MEMORY_DEV=1` — newly
wired to also start the window-change observer under that same dev flag,
`Sources/AutocompleteLabApp/App/AppDelegate.swift` — is the only safe lane).

**OCR p95 result (real, measured on this Mac, Apple M5 Max): FAILS budget.**
16 real captures over a 90s window of scripted app-switching (Finder ↔
Calculator, ~1 switch/3s against the 5s cadence cap): mean capture+OCR
459ms, p95 694ms, max 694ms, min 322ms — all measured via the new
`duration_ms` field on the `screen-capture-completed` diagnostic. Every
single capture exceeded the 250ms budget; the plan's own fallback applies
("drop capture resolution first — OCR tolerates 0.5x — then cadence").
`VNRecognizeTextRequest`'s `.accurate` mode on a full-display image is the
suspect; Phase 1b's own next step per the plan is trying `.fast` mode and/or
a sub-1x capture scale before shipping past the dev flag. Block counts
scaled with screen content density (32–132 OCR blocks per capture) with no
obvious correlation to duration in this small sample — worth a larger run
before concluding resolution is the dominant cost over block count.

**Battery result: BLOCKED, not measured.** `powermetrics` requires root;
this environment's `sudo` has no cached credential and cannot prompt
interactively for a password, so the harness correctly refuses to guess and
exits 3 with the exact remediation printed (owner's move: run
`script/capture_power_probe.sh` from an interactive terminal so `sudo` can
prompt once, or install a `NOPASSWD` sudoers rule scoped to the exact
`powermetrics --samplers cpu_power -i <n> -n <n>` invocation the script
uses). Screen Recording TCC, expected to be the other likely blocker per the
plan, turned out NOT to be blocking in this run — the dev build already had
a grant (unclear origin standard for this Mac; the OCR numbers above are
proof it captured for real, not degraded/skipped). A Mac where the dev
build has never been granted access will additionally need: open System
Settings → Privacy & Security → Screen Recording → enable the entry for the
`dist/Tilde.app` build in use, or click Allow on the system consent dialog
that appears on first capture attempt while the toggle and dev flag are on.

Two pre-existing bugs found and fixed while building this harness, both in
`Sources/AutocompleteLabCore/Text/DiagnosticsMetadataRedactor.swift` (shipped
in the Phase 1a capture-engine PR, #352): `ScreenCaptureService`'s
`blocks`/`duration_ms` fields and every one of its `reason=` skip values
(`permission`, `cadence`, `disabled`, `screen-locked`, `secure-input`,
`no-active-session`, `below-threshold`, `excluded-window`,
`enumeration-failed`, `no-display`) were outside the redactor's allowlist and
were silently collapsing to `String(N chars)` in `diagnostics.log` — the
duty-cycle numbers this probe needs did not exist in readable form at all
before this fix, and nothing could distinguish a permission skip from a
cadence skip either. Caught by this harness's own live run (`reason=disabled`
where `permission` was expected, traced to a second, unrelated bug in the
harness itself: `defaults write` was targeting the app's own bundle-id
domain instead of `TildeSettings`'s actual shared app-group suite,
`bar.r3d.inputmethod.InlineGhost`).

Follow-ups: re-run with `powermetrics` once sudo is available for a real
battery number; try `.fast` Vision recognition and/or 0.5x capture scale
against the OCR budget miss; run at production cadence (not scripted
aggressive switching) for a realistic events/hour baseline — this run's ~640
captures/hour is a stress ceiling, not typical usage.

## 2026-08-16 — screen context (OCR), July evidence — roadmap pointer

Not yet built here. The July lineage (checkout
`transcripted-autocomplete-lab`, `docs/quiz-lessons.md` entry "Screen context
(OCR) is worth a lot") measured EM@1 14.5% → 17.2% (+2.7 points) when a
golden-eval case was given OCR'd screen context alongside the usual prompt —
the single largest lever found in that lineage. That evidence is why Screen
Memory (full on-device OCR + redaction + persistence, gated behind a new
covenant in `AGENTS.md` and `PRIVACY.md`) is now planned rather than shelved.
Full plan, phased PR series, and ship bars (≥ +2 EM@1 points on the golden
eval context arm, replicating the July precedent) live in
`docs/plans/screen-memory.md` on PR #347 (not yet merged as of this entry —
that plan lands separately from this Phase 0 governance PR, so the path does
not resolve on `main` until #347 merges). Governance (Phase 0, this PR) merges
before any capture code (Phase 1+) begins; update this entry with real numbers
once Phase 4's context-arm runs land.

## 2026-08-15 — Gemma 4 E2B base becomes the production model

Head-to-head against the shipped Gemma 2 2B base (both Q4_K_M, same helper,
same deterministic quiz cutting and scoring as `script/golden_eval.py`, greedy
decoding, production scaffolds and token budgets):

| Register (corpus) | Gemma 2 2B | Gemma 4 E2B | delta |
|---|---|---|---|
| chat (Discord-Dialogues, 1,000 cases) | 13.6% EM@1 | 17.1% | +3.5 |
| email (AESLC bodies, 500 cases) | 36.2% | 35.8% | tie |
| prose (blog corpus, 500 cases) | 26.6% | 24.2% | −2.4 |
| blended (2,000 cases) | 22.5% | 23.6% | +1.1 |

Latency comparable (solo-run p50 71ms vs 78ms). Keystrokes saved per case
+19% blended. Owner decision: ship it — chat is the dominant personal register
and the hardest one, and the prose gap closes with a scaffold change (below).
Shipped as version 0.1.1 build 2700 through the full release driver
(notarized, stapled, Gatekeeper-accepted); previous Gemma 2 app retained as a
local rollback copy.

Lessons:

- **Base beats instruct still holds, and the base checkpoint is the hidden
  one.** Community GGUF mirrors of Gemma 4 are exclusively the `-it` variants;
  the pretrained checkpoint exists only in Google's own repo (ungated). The
  July bakeoff scored Gemma 4 only via its instruct variants (15.1–23.2%) and
  wrongly wrote off the family; the base variant wins the chat register
  outright. Always locate and test the base checkpoint before judging a model
  family.
- **A register win does not generalize.** The +6.5 chat delta at 200 cases
  shrank to +3.5 at 1,000 and did not carry to email (tie) or prose (loss).
  Any future model claim needs all three registers before a switch decision.
- **Scaffold tuning recovers register losses.** A six-example prose scaffold
  brought Gemma 4 prose from 26.8% to 28.8% (250-case screen), parity with
  Gemma 2's 28.4%. A shorter email scaffold nudged email to 42.0% vs 41.6%.
  Prompt knobs must be re-swept whenever the base model changes.
- **The token-budget knob is a no-op for EM@1 and keystrokes under greedy
  decoding** — first words are identical regardless of budget; only scaffold
  choice moved scores. Budget matters for suggestion length and latency, not
  first-word accuracy.
- **Effective-parameter models break the size/latency trade.** Gemma 4 E2B is
  a 4.6B-parameter model with 2B-class activation: 12B-class family knowledge
  at 78ms p50. The currently pinned Q4_K_M is exactly 3,427,861,984 bytes;
  it is downloaded to verified Application Support storage instead of being
  embedded in `Tilde.app`. Text-only conversion is
  provable: the converted GGUF carries 601 language-model tensors and zero
  vision/audio tensors (audited with gguf-py), 8.7GB text-only vs 10.2GB
  multimodal safetensors.
- **Eval corpora are rebuildable from public data**: chat from
  mookiezi/Discord-Dialogues, email from Yale-LILY/aeslc bodies, prose from
  the blog authorship corpus, all filtered into the `{"text": ...}` corpus
  contract. Registers differ wildly in difficulty (email 36% vs chat 14%
  EM@1) — never compare scores across corpora, only paired arms on identical
  case selections.

Follow-ups this created: adopt the size6 prose scaffold in
`RawContinuationPrompt.swift`; count suggestions *shown* (accept counts have
no denominator today); replay evaluation against retained Personal History so
candidate configs are scored on real typing without live dogfooding time.

## 2026-08-15 — competitive landscape check

Nine-plus macOS ghost-text apps now exist (KeyType, TabType, Shadowtype,
Cotabby, Wysp, MacAutocomplete, GhostType, Ghostwriter, others). Every one
integrates via the Accessibility API plus an event tap; none is an IMKit input
method. None combines real input-method integration, a bundled local model,
and on-device personalization. Two implementation ideas worth study: KV-cache
"speculative parking" during word-by-word accept walks (TabType), and Apple
Intelligence as an optional zero-bundle backend (Cotabby). Two unshipped
lanes anywhere in the ecosystem: a small base model pretrained on casual chat
register, and natural-language fill-in-the-middle — both are
continued-pretraining projects on top of a strong base model, and
`llama-server` already exposes an `/infill` endpoint if FIM ever lands.
