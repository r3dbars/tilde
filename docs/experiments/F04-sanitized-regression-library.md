# F04 — Sanitized permanent regression library

Status: SUPPORTED
Experiment class: runtime
Owner: Tilde research program
Pre-registered: 2026-08-29T14:45:00Z
Completed: 2026-08-29T15:30:00Z

## Pre-registration

### Hypothesis

Freezing every historically discovered scoring loophole and interaction
failure as a deterministic, synthetic, text-safe case — where the frozen
guard must stay safe AND the known-unsafe arm must keep reproducing the
historical failure — will stop those failures from silently returning as
"wins" in future experiments.

### Why this should work

The Q04/Q05 era proved two failure shapes. First, scoring loopholes:
one- and two-word candidates fell below the three-word scene-echo floor, so
short caps made safety-rejected echoes score as shown; aggressive repeat
penalty raised raw scores by speaking more; removing prompt examples and
weakening the factual filter looked like improvements (ledger
`qwen-9b-scoring-confounds`). Second, interaction failures the real-host
gate must never wave through: duplicate insertion, focus-change damage,
runtime-restart damage, and marked-text corruption.

A regression case that only asserts "production is safe" rots: a refactor
can make the historical trap unrepresentable and the case passes forever
while guarding nothing. Every F04 case therefore has two halves — the guard
holds, and the loophole is still reproducible under the named unsafe arm —
so a toothless case fails loudly and must be consciously retired.

### Control

The repository before this change: the loopholes are documented in the
Learning Ledger but no automatic test reproduces them; a future change
could reintroduce any of them without failing proof.

### Treatment

`LabPermanentRegressions` in `Sources/TildeLabKit/Scoring/`, with one
stable case ID per known failure class:

| Case ID | Guard | Unsafe reproduction |
| --- | --- | --- |
| `regression.short-cap-echo-bypass.v1` | full candidate rejected as scene echo | two-word cap truncates under the echo floor and shows it |
| `regression.repeat-penalty-aggression.v1` | cleaner does not show repeated babble verbatim | diagnostic arm with self-repetition off shows more of it |
| `regression.wrong-scene-facts.v1` | numbers-and-names grounding rejects an invented number | grounding off delivers it |
| `regression.stale-target-delivery.v1` | 25-second-old snapshot refused by the 20-second freshness gate | bypassing the gate still classifies the stale scene |
| `regression.prompt-example-removal.v1` | production prompt carries the example-scaffold instruction line | minimal recipe drops it |
| `regression.factual-filter-weakening.v1` | strict preset rejects the invented number even with grounding declared off | production preset with grounding off shows it |
| `regression.duplicate-insertion.v1` | one stale insertion fails the interaction gate | identical clean evidence passes it |
| `regression.focus-change.v1` | one focus-change failure fails the gate | clean evidence passes |
| `regression.runtime-restart.v1` | one runtime-restart failure fails the gate | clean evidence passes |
| `regression.marked-text-damage.v1` | one committed-text corruption fails the gate; streaming reveal exposes only the stable word-boundary prefix | clean evidence passes |

All scenario text is synthetic. The suite runs inside `swift test`, so it
is blocking in `./script/proof.sh fast` and cannot be skipped by any
campaign or average score.

The repeat-penalty case is a deterministic proxy: the sampler-level
confound cannot run without a model, so the case freezes the cleaner's
self-repetition protection, which is the deterministic guard that made the
historical babble scoreable. The three interaction-failure cases test the
sensitivity and specificity of `LabInteractionEvidenceAnalyzer` — the gate
that real-host evidence must pass — not a live host.

### Primary metric

All ten cases report `guardHolds == true` and `loopholeReproduced == true`
in every test run, with stable IDs matching `caseIdentifiers` exactly.

### Hard gates

- No private writing, screen text, prompts, candidates, or local paths in
  any case, detail string, or this record.
- Cases are deterministic: no model, no network, no clock dependence
  beyond fixed synthetic dates.
- A failing case cannot be waived by any average score.

### Kill rule

Reject the design if a failure class cannot be represented without private
content, or if a case can only assert the guard without reproducing its
loophole (toothless-by-construction).

### Frozen provenance

- Git commit: implementation started from `3bc5a4ac` (retention clamp)
- Model / helper hashes: not applicable; deterministic instrument test
- Suite: `Tests/TildeLabKitTests/LabPermanentRegressionTests.swift`

## Result

Status: SUPPORTED

All ten cases pass: every guard holds and every loophole is still
reproducible. Two fixture corrections were needed during implementation
(the stale-scene snapshot required two speaker blocks to classify as a
conversation; the stable stream prefix trims its trailing boundary), both
adjusting the synthetic fixture, not the guarded behavior. The Learning
Ledger queue item `sanitized-regression-library` is marked
completed-foundation.

### Limitations

- The repeat-penalty case guards the deterministic cleaner protection, not
  the sampler distribution itself; a model-level repeat-penalty sweep would
  still need its own registered experiment.
- The interaction cases prove the evidence gate's sensitivity, not real
  host behavior; the owner-triggered host matrix remains the live proof.

### Follow-up

With F01–F04 complete, Stage 0 exits when F03's live ingest is judged on a
clean full-file count from the rebuilt IME. Then close the Qwen decision
and start H01.
