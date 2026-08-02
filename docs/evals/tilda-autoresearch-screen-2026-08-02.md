# Tilda autoresearch screen — 2026-08-02

## Status

The first screening stage is complete. It ran one frozen 1,000-case synthetic
subset with the exact same evaluator, model server, and request protocol for a
baseline plus all 34 one-knob candidates. Every request completed without a
protocol error. No candidate was promoted from this screen; the strongest
configs move to repeated confirmation rather than being combined blindly.

The run is local-only. Usage capture was disabled for synthetic traffic and
restored afterward. No raw prompt, screen text, model output, or personal
writing was written to the ledger.

- Cases: 1,000
- Case hash: `87dcab65e07bb0a8490f1e5935a21a9d0d86c354f6fa0b9cd82b8cf48a925273`
- Ledger: `/Users/redbars/.cache/steadytype-eval/gym/autoresearch-missed-opportunities-20260802/results.jsonl`
- Baseline mode: `exact_3`
- Baseline: 112 safe accepts, 732 interruptions, 156 missed opportunities,
  p50 82 ms, p95 155 ms, zero errors

## What the screen taught us

The original 10,000-case guardrails cannot be applied literally to a
1,000-case screen. A 50-case miss threshold is too large and p95 is noisy at
this size. The ledger was repaired with scaled screening gates: at 1,000
cases, at least five fewer misses, no safe-accept loss, no more than five
additional interruptions, and p95 no more than 20 ms above the screen
baseline. Final 10,000-case confirmation will return to the strict gates in
the autoresearch plan.

No candidate met those gates. The closest candidates were:

| Candidate | Safe accepts | Misses | Interruptions | P95 | Read |
| --- | ---: | ---: | ---: | ---: | --- |
| `temperature-0.2` | +4 | -13 | +9 | 150 ms | best balanced signal; needs repeat confirmation |
| `echo-guard-10` | -5 | -26 | +31 | 153 ms | fewer misses by becoming noisier; reject unless later quality improves |
| `repeat-penalty-1.05` | -4 | -23 | +27 | 152 ms | same trade-off; not safe yet |
| `retrieval-2` | -4 | -15 | +19 | 147 ms | retrieval count alone is not a win |
| `screen-chars-300` | -15 | -18 | +33 | 124 ms | less context lowers misses but costs accepts and adds interruptions |
| `screen-reply-framing` | -7 | -10 | +17 | 150 ms | no balanced gain |

The most important negative results are stronger than the small wins:

- Removing the token confidence floor (`0` or `.05`) destroyed safe accepts
  and increased interruptions. The floor is a useful safety boundary.
- The instruct prompt caused a large coverage collapse: 320 more misses and
  112 fewer safe accepts in this deck. Do not replace the raw continuation
  prompt based on a generic prompt intuition.
- More visible words and lower echo guards did not produce a free coverage
  increase. They mostly moved cases from silence into interruptions.
- The screen did not prove a winner. It identified `temperature-0.2` as the
  first balanced candidate to repeat, while the other candidates are useful
  trade-off controls and negative controls.

## Next action

Run repeated 3,000-case confirmation for six candidates: `temperature-0.2`,
`echo-guard-10`, `repeat-penalty-1.05`, `retrieval-2`,
`screen-chars-300`, and `screen-reply-framing`. Keep a candidate only if its
gain survives both repeats and the paired interaction remains within the
strict safety/latency gates. No model-weight or production code change is
authorized by this screen.
