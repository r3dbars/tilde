# Autoeval: SteadyType user-feel benchmark

## Verdict
blocked by the serialized merger hold before post-change Swift measurement.

## Scoreboard
| # | Knob | Status | Primary result | Guardrails | Decision |
|---|---|---|---|---|---|
| 0 | baseline | baseline | mock 6.33 shown keys/case; batch 1.67 shown keys/case; batch generation p95 476–541 ms | 3 synthetic fixture cases; aggregate-only artifacts | starting point |
| 1 | aggregate user-feel scorecard | blocked | not measured | focused Swift assertions did not run | hold |
| 2 | max tokens 12 | not run | — | — | merger hold |
| 3 | context 240 chars | not run | — | — | merger hold |
| 4 | no built-in few-shot | not run | — | — | merger hold |
| 5 | suffix on | not run | — | — | merger hold |

## Metric
- Added aggregate measurements for pause-to-suggestion p50/p95, eligible-pause visible rate, case-weighted typing stability, and exact next-word acceptance quality.
- Frozen evaluator and corpus: `docs/evals/typing-replay-fixture.jsonl`, existing replay scorer/gate, and fixed batch command in `resume.md`.
- No raw typed text, prompts, model output, screenshots, paths, app names, or identifiers are written by the new scorecard.

## Baseline
- Existing unmodified head: `99dc4fcb`.
- Existing evaluator artifacts: `baseline-existing.md`, `baseline-batch.md`, and matching JSONL files in this run directory.
- Cheap proof: Swift parse, `git diff --check`, Python compile, and replay-report privacy self-test passed.

## Risks and next run
- Focused Swift test compilation was canceled before assertions by the explicit serialization hold; full Swift tests, `proof.sh fast`, and `build_and_run.sh --verify` were not run.
- Manual real-app keyboard, focus, secure-field, insertion, Tab, Shift-Tab, and Escape proof remains `UNKNOWN`.
- After release, run focused tests, then the unchanged batch benchmark, repeat noisy baseline/winner runs, and test each remaining knob one at a time.

## Review
- Independent static review: `/Users/redbars/.codex/maestro/runs/20260718T115020Z-steadytype-user-feel-static-review-claude`.
- Review findings were applied: removed vacuous acceptance-proof metric and changed stability to one result per visible case.
