# Tilda fresh retrieval holdout — 2026-08-02

## Verdict

The fresh holdout supports adding a small, local retrieval layer around the
base model. Three topic- and app-matched exemplars were the best overall
variant in this run: they produced the most safe accepts, the best first-word
match, fewer interruptions than baseline, and only a 12 ms p95 latency cost.

This is evidence for a feature flag and a real-user pilot, not a production
promotion. The socket test passes retrieved text through its existing page
context field because the current protocol has no retrieval field. No app
code, model weights, or production index changed.

## Setup

- Fresh holdout: 10,000 synthetic cases, balanced across browser, Slack, email,
  Messages, Notes, and writing.
- Total requests: 40,000 (the same 10,000 cases in each of four modes).
- Case-ID SHA-256:
  `8cc464bfebb9c61596d399bf1ee3cd174b65f221e5874d14fcc9d18e4bcc1d53`
- Retrieval-corpus SHA-256:
  `eabbb6aeb5e26d8b20641f34920fe4589e5b11a937d5bd63afb4127f6986fa30`
- `none`: no retrieved examples.
- `exact_1`, `exact_2`, `exact_3`: one, two, or three app- and topic-matched
  examples. The topic is derived from the typed prefix only.
- The current source sentence is excluded from retrieval. The hidden
  continuation is never used by the selector.
- All fixtures were synthetic. Raw usage capture was disabled during the run
  and restored to enabled afterward. Suggestion bodies were not written.

## Scoreboard

| Mode | Safe accepts | Interruptions | Missed opportunities | First-word match | p50 / p95 latency | Keystrokes saved/case |
|---|---:|---:|---:|---:|---:|---:|
| No retrieval | 902 / 9.02% | 7,541 / 75.41% | 1,557 / 15.57% | 24.71% | 52 / 123 ms | 1.031 |
| 1 matched example | 950 / 9.50% | 7,552 / 75.52% | 1,498 / 14.98% | 26.95% | 62 / 119 ms | 1.164 |
| 2 matched examples | 935 / 9.35% | 7,548 / 75.48% | 1,517 / 15.17% | 27.62% | 67 / 127 ms | 1.181 |
| 3 matched examples | **953 / 9.53%** | **7,501 / 75.01%** | 1,546 / 15.46% | **28.03%** | 72 / 135 ms | **1.194** |

Every mode completed with zero protocol errors.

## What the result means

1. **Three examples win overall in this synthetic mix.** Versus no retrieval,
   they add 51 safe accepts, improve first-word match by 3.32 percentage
   points, and reduce interruptions by 40 cases.
2. **The latency tradeoff is bounded here.** P95 rises from 123 ms to 135 ms.
   That is a 12 ms cost, within the tradeoff approved for this experiment.
3. **More context is not automatically better.** Two examples had slightly
   better first-word match than one, but fewer safe accepts. The exact number
   should remain a tunable setting, not a baked-in model change.
4. **The effect varies by surface.** Retrieval helped Notes and email most.
   Slack and writing did not gain safe accepts consistently, so the next
   implementation should be app-aware and allowed to retrieve zero examples
   when confidence is low.

## Recommendation

Implement retrieval as a local, feature-flagged layer around the base model:

1. Start with up to three short, app-matched exemplars only when the local
   index has a confident topic match.
2. Keep the no-retrieval path as the fallback for weak matches, sensitive
   fields, or latency over budget.
3. Run a bounded personal pilot and compare the same episode metrics before
   and after: safe accepts, interruptions, missed opportunities, first-word
   match, p95 latency, and per-app results.
4. Do not fine-tune the base model from this test. Retrieval is a context
   layer; model training should wait for a larger, adversarially reviewed
   dataset and a clear regression gate.

## Artifact

Validated aggregate results:
`~/.cache/steadytype-eval/gym/runs/fresh-holdout-retrieval-20260802/results-final.json`

No production settings, personal data, live memory, or deployed app behavior
were changed.
