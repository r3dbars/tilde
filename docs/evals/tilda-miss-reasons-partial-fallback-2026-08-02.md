# Tilda miss reasons and partial fallback — 2026-08-02

## Miss-reason probe

On a 3,000-case exact-3 synthetic run, the socket-level miss proxy found:

- 335 misses with partial frames but no usable final frame;
- 153 misses with no partial and no transport error;
- zero protocol errors.

The partial bucket is the largest observable bucket, but it is not proof that
the partial text is safe to insert. The socket currently gives the evaluator
frame counts, not a trustworthy semantic label for why the final was empty.

## Partial fallback experiment

The research harness then replayed the same 3,000-case deck twice: normal final
frame behavior and a policy that offered the last non-empty partial only when
the final frame was empty. This was evaluator-only; no production code or
defaults changed.

| Policy | Safe accepts | Misses | Interruptions | P95 | Partial offers |
| --- | ---: | ---: | ---: | ---: | ---: |
| normal final-only | 315 | 489 | 2,196 | 123 ms | 0 |
| last-partial fallback | 365 | 154 | 2,481 | 124 ms | 334 |

Of the 334 fallback offers, only 62 were safe and 272 were interruptions. The
policy therefore recovers many apparent misses by turning them into wrong
offers. It fails the interruption guard by a wide margin and must stay
rejected. The lesson is simple: a missing final is a reliability signal, not
permission to insert an arbitrary partial.

Stricter minimum-word thresholds did not rescue the idea. On another 3,000
case run, the normal baseline was 308 safe accepts, 478 misses, and 2,214
interruptions. Minimum 2/3/4-word fallbacks produced respectively:

- 308 / 286 / 2,406;
- 295 / 330 / 2,375;
- 300 / 356 / 2,344.

The first number is safe accepts, the second misses, and the third
interruptions. Every threshold still violated the interruption guard.

## Next research target

Keep the final-frame safety rule. Use the partial bucket to guide a bounded
generation experiment instead: compare token budget, stream completion timing,
and a one-time bounded retry that requests a final only after a partial-only
response. Any retry must be scored for latency and interruptions, and must be
kept only if it improves the partial bucket without merely converting it into
noise.
