# Tilda autoresearch confirmation — 2026-08-02

## Result

The six closest screen candidates were each run twice on the same frozen
3,000-case synthetic subset. All 18,000 requests completed without protocol
errors. No candidate is promoted.

- Case hash: `6c69cbdb0325e8ab38ce35fe6f3a24ba46c618d97e01422d5da0a3d2e0d591b2`
- Ledger: `/Users/redbars/.cache/steadytype-eval/gym/autoresearch-missed-opportunities-20260802/confirm/results.jsonl`
- Summary: `/Users/redbars/.cache/steadytype-eval/gym/autoresearch-missed-opportunities-20260802/confirm/summary.json`
- Baseline mean: 302.5 safe accepts, 464.5 misses, 2,233 interruptions,
  p95 248.5 ms, zero errors

The two baseline repeats also exposed meaningful latency variance: p95 was
180 ms and 317 ms. That is why a single fast repeat cannot make a latency
claim, and why no candidate should be shipped from this synthetic campaign
without repeated and real-device timing evidence.

## Candidate outcomes

| Candidate | Safe accepts | Misses | Interruptions | P95 | Decision |
| --- | ---: | ---: | ---: | ---: | --- |
| `echo-guard-10` | +4.0 | -72.5 | +68.5 | 290 ms | reject: too many interruptions |
| `repeat-penalty-1.05` | -10.0 | -49.0 | +59.0 | 187.5 ms | reject: loses accepts and adds interruptions |
| `retrieval-2` | -8.0 | +3.5 | +4.5 | 119 ms | reject: no coverage gain |
| `screen-chars-300` | -18.0 | -2.5 | +20.5 | 112.5 ms | reject: loses accepts |
| `screen-reply-framing` | +0.5 | -8.5 | +8.0 | 144.5 ms | reject: gain is below the 0.5-point miss threshold |
| `temperature-0.2` | +10.5 | +33.5 | -44.0 | 268 ms | reject: fewer interruptions but more misses |

The important lesson is that the current 1,546-miss problem is not fixed by
making the system generally more willing to speak. The apparent miss gains
from `echo-guard-10` and `repeat-penalty-1.05` are mostly a trade from silence
to wrong or noisy offers. The balanced candidate from the 1,000-case screen,
`temperature-0.2`, did not reproduce; it produced more misses on confirmation.

## Runtime state

The campaign restored the normal runtime settings after the last attempt:
temperature `0.1`, token budget `24`, token confidence floor `0.11`, visible
word cap `6`, echo guard `8`, and synthetic usage capture enabled. No model
weights, production defaults, or live app behavior were changed.

## Next stage

Do not combine these rejected knobs. First add aggregate-only miss-reason
proxies to the evaluator: empty final with no partial, partial stream without a
final, cleaner/echo rejection, token/word cap, and timeout/protocol error.
Then screen the remaining supported generation and scheduling controls on a
fresh held-out split. The aim is to find which failure bucket is responsible
for each miss before touching retrieval or personal adaptation.
