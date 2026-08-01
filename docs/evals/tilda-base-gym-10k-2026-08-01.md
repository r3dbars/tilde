# Tilda base-model gym: 10,000 synthetic cases

## Status

Completed 2026-08-01 on the canonical local Phase 1 gym. The personal app was
restored after the run. No production branch or app defaults changed.

## Goal

Measure the shared Tilda base brain before personal memory or a per-user LoRA
layer is introduced. The benchmark should find useful completions, missed
opportunities, interruptions, and protocol/runtime failures across diverse
writing surfaces without reading personal typing history or screenshots.

## Test design

- 10,000 deterministic synthetic cases generated outside the repository.
- Cases are full synthetic messages replayed at word boundaries through the
  same local Ghost socket used by the app.
- Surface distribution includes browser text, Slack-style work, email,
  Messages-style texting, notes, and writing contexts that should stay quiet.
- Screen/OCR context is forced off for this baseline so the result measures the
  base brain rather than a live frontmost window.
- The gym writes only aggregate scorecard fields and hashed failure rows. Raw
  synthetic context and suggestions are not written to the report.

## Primary measures

- Safe-prefix acceptance: the suggestion matches the known synthetic
  continuation from the beginning.
- Missed opportunity rate: no suggestion where a safe continuation exists.
- Interruption rate: a wrong or unexpected suggestion that would interrupt the
  writer.
- Keystrokes saved per case and per spoken case.
- p50/p95/max request latency.
- Socket/protocol errors and partial responses.

## Guardrails

- Exactly 10,000 completed cases are required.
- The adversarial verifier must pass before the live run.
- No raw bodies in `scorecard.json` or `wreckage.jsonl`.
- The base model must be verified from the actual app launch path.
- This is synthetic quality/runtime evidence only. It does not prove native
  caret placement, keyboard acceptance, insertion verification, or real-user
  accepted-and-kept behavior.

## Auto-research loop

The first pass was the frozen baseline. A second pass replayed the same
10,000 synthetic rows (six model outputs containing a prohibited digit shape
were replaced with an aggregate-safe `[redacted]` sentinel) through the
offline policy tournament. The tournament ran 1,000 deterministic policy
experiments, passed its 10-case adversarial verifier, and rechecked six
winner packets successfully.

The important finding is that the first utility function over-rewards silence:
its full-exam champion set a 53-character minimum suggestion length and spoke
zero times. That reduced interruptions to 0, but also produced 0 safe accepts
and 10,000 missed opportunities. It is not a product improvement and was not
promoted. The next loop must enforce a usefulness floor (safe accepts and
missed-opportunity limits) before ranking interruption reductions. No candidate
was promoted to the model, personal layer, or production.

## Model note

This run uses the installed generic Gemma 2 2B GGUF base asset. It is not the
personal model and it is not a LoRA/personalization run. The app is restored to
its persisted personal configuration after the benchmark.

## Evidence

Run artifacts live outside the repository at
`~/.cache/steadytype-eval/gym/runs/base-10k-20260801/`; raw synthetic traces
are disposable and were not committed. Aggregate evidence:

- Corpus: 600 deterministic synthetic messages, 16,582 possible word cuts;
  the run selected exactly 10,000. Corpus SHA-256:
  `eabbb6aeb5e26d8b20641f34920fe4589e5b11a937d5bd63afb4127f6986fa30`.
- Model: generic Gemma 2 2B base GGUF, 1,708,581,792 bytes; model SHA-256:
  `01e4078857ea9680422769a67f97646dd944a9a0713c4430abe586cf135c7de5`.
- Baseline: 9,051 spoke (90.51%); 880 safe accepts (8.80%); 8,171
  interruptions (81.71%); 949 missed opportunities (9.49%); 0 protocol
  errors; 6,405 keystrokes saved; p50 latency 49 ms, p95 107 ms; all 10,000
  requests reported `page_attached: false`.
- Failure piles: 7,441 wrong-first-word, 730 wrong-tail, and 8,171 total
  interruptions. The 880 clean rows are the useful seed set for the next
  quality pass.
- Research: 1,000 offline policy experiments over a 10,000-row redacted
  synthetic trace; verifier 10/10 PASS and winner recheck PASS. The champion
  was rejected because it silenced everything.

This is synthetic quality/runtime evidence only. It does not prove native
caret placement, keyboard acceptance, insertion verification, or real-user
accepted-and-kept behavior.
