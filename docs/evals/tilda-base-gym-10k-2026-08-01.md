# Tilda base-model gym: 10,000 synthetic cases

## Status

Run launched 2026-08-01. This document records the setup and will be updated
with the aggregate result and research-loop decisions when the run finishes.

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

The first pass is the frozen baseline. Candidate changes must use the same
10,000-case corpus and scoring rules. A candidate is kept only when it improves
the aggregate utility without worsening interruption, error, latency, or
privacy guardrails. Failure clusters are recorded as the next research queue;
no candidate is promoted automatically to the personal layer or production.

## Model note

This run uses the installed generic Gemma 2 2B GGUF base asset. It is not the
personal model and it is not a LoRA/personalization run. The app is restored to
its persisted personal configuration after the benchmark.

## Evidence

The run directory and exact command are recorded in the coordinating task
ledger. Add the final aggregate-only scorecard, failure clusters, and the next
experiment here after completion.
