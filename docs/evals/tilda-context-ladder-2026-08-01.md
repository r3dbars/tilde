# Tilda context ladder — 2026-08-01

## Verdict

The 1,000-case context ladder completed against the running local Tilda app with
4,000 total synthetic requests. No clear winner is promoted. App and page
context changed the tradeoff, but neither beat the prefix-only baseline on both
usefulness and latency. The memory result is a **proxy**, not proof of a real
vector-memory layer: the existing socket protocol has no retrieval field, so a
synthetic preference block was passed through its explicit page-context field.

## Setup

- Corpus: the frozen synthetic corpus from the base gym; no personal text,
  screenshots, identifiers, or network calls.
- Cases: 1,000 balanced word-cut cases, 166–167 per synthetic surface
  (browser, Slack, email, Messages, Notes, writing).
- Case selection SHA-256:
  `edc7e30c4ec83f531de9db72051a60d3bd4f5c4cd8a0f04e463dcaec585b7a5a`
- Corpus SHA-256:
  `eabbb6aeb5e26d8b20641f34920fe4589e5b11a937d5bd63afb4127f6986fa30`
- The app's raw capture flag was disabled for the run and restored afterward.
- Only aggregate scorecards were written; model output bodies were not saved.

## Scoreboard

| Mode | Useful accepts | Interruptions | Missed opportunities | First-word match | p95 latency | Page attached |
|---|---:|---:|---:|---:|---:|---:|
| Prefix only | 111 / 11.1% | 762 / 76.2% | 127 / 12.7% | 21.4% | 90 ms | 0%
| App aware | 100 / 10.0% | 785 / 78.5% | 115 / 11.5% | 21.4% | 109 ms | 0%
| App + page context | 100 / 10.0% | 754 / 75.4% | 146 / 14.6% | 21.6% | 136 ms | 100%
| Full-context proxy | 106 / 10.6% | 754 / 75.4% | 140 / 14.0% | 23.3% | 145 ms | 100%

All four modes completed with zero protocol errors.

## What this says

1. **App identity alone is not a quality win yet.** It changed register and
   reduced missed opportunities slightly, but produced fewer useful accepts and
   more interruptions than prefix-only.
2. **Page context helps restraint a little.** It lowered interruptions by 8
   cases versus prefix-only, but cost latency and increased missed opportunities.
3. **The synthetic memory proxy recovered some quality.** It raised useful
   accepts from 100 to 106 and first-word match from 21.6% to 23.3% versus page
   context alone, but p95 latency rose to 145 ms. This is encouraging but not a
   real retrieval evaluation.
4. **There is no reason to scale to 100,000 yet.** The next high-value work is a
   real retrieval interface or offline prompt harness, plus a usefulness floor
   that prevents “silence everywhere” from winning the score.

## Next experiment

Add a deterministic, local retrieval fixture to the evaluator (not production
memory), with 3–5 synthetic exemplars selected by app and topic. Compare no
retrieval versus exact-match retrieval versus deliberately unrelated retrieval
on this same frozen case set. Keep a candidate only if useful accepts and
first-word accuracy improve without raising p95 latency above the current
baseline or increasing interruptions.

## Artifacts

Aggregate results:
`~/.cache/steadytype-eval/gym/runs/context-ladder-20260801/results.json`

The run changed no app code, model files, production settings, or live data.
