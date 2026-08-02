# Tilda retrieval ladder — 2026-08-02

## Verdict

The validated 1,000-case retrieval test shows a real quality signal, but the
candidate is **not promoted** under the current latency guardrail. Topic-matched
synthetic exemplars substantially improved useful completions and first-word
accuracy while reducing wrong interruptions. They also increased p95 latency
and missed opportunities.

This is a prompt-level proxy only. The current local socket has no retrieval
field, so exemplars were passed through its explicit page-context field. No
production memory or vector index was changed.

## Setup

- Frozen cases: the same 1,000 balanced cases used by the context ladder
  (browser, Slack, email, Messages, Notes, writing).
- Total requests: 3,000, with the same cases in every mode.
- Case selection SHA-256:
  `edc7e30c4ec83f531de9db72051a60d3bd4f5c4cd8a0f04e463dcaec585b7a5a`
- Corpus SHA-256:
  `eabbb6aeb5e26d8b20641f34920fe4589e5b11a937d5bd63afb4127f6986fa30`
- `no_retrieval`: app plus synthetic page context, no examples.
- `exact_retrieval`: two topic- and app-matched examples selected from the
  typed prefix only.
- `unrelated_retrieval`: two deliberately unrelated examples.
- All fixtures were synthetic. The app's raw capture flag was disabled during
  the run and restored afterward. Output bodies were not written.

## Scoreboard

| Mode | Useful accepts | Interruptions | Missed opportunities | First-word match | p95 latency | Keystrokes saved/case |
|---|---:|---:|---:|---:|---:|---:|
| No retrieval | 106 / 10.6% | 745 / 74.5% | 149 / 14.9% | 22.1% | 103 ms | 0.756 |
| Topic-matched retrieval | 222 / 22.2% | 496 / 49.6% | 282 / 28.2% | 45.5% | 167 ms | 4.246 |
| Unrelated retrieval | 181 / 18.1% | 611 / 61.1% | 208 / 20.8% | 32.8% | 143 ms | 2.719 |

All three modes completed with zero protocol errors.

## Interpretation

1. **Retrieval is doing real work.** Topic-matched examples more than doubled
   useful accepts and first-word match versus no retrieval.
2. **Matching matters.** Topic-matched examples beat unrelated examples by 41
   useful accepts and 115 fewer interruptions.
3. **The prompt is too expensive right now.** Topic-matched retrieval adds 64 ms
   to p95 latency versus no retrieval and causes more missed opportunities. It
   is a quality win, but not yet a product-ready tradeoff.
4. **Some of the lift is probably few-shot scaffolding.** Unrelated examples
   also help, so the next test must separate “the model got useful examples”
   from “the retriever found the right examples.”

## Integrity correction

The first exploratory pass was discarded. Its fixture selector could reuse the
same source sentence and used the hidden continuation to choose a topic. That
was look-ahead leakage. The final run excludes the current source sentence and
selects topics from the typed prefix only. The discarded output is not used for
the verdict.

## Next experiment

Keep the retrieval idea, but test a smaller prompt: one matched exemplar,
shorter formatting, and a compact local index. Keep a candidate only if it
retains most of the useful-accept gain while bringing p95 back near the 103 ms
no-retrieval baseline and reducing missed opportunities.

## Artifacts

Validated aggregate results:
`~/.cache/steadytype-eval/gym/runs/retrieval-ladder-20260802/results-final.json`

No app code, model files, personal data, production settings, or live memory
were changed.
