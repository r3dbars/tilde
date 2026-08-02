# Tilda expanded-screen confirmation — 2026-08-02

## Protocol

The two provisional candidates from the expanded 1,000-case screen were
repeated twice each on a fresh, disjoint 3,000-case split. The baseline and
each candidate used the same `exact_3` retrieval mode and the same cases.
Only aggregate metrics were written.

- Cases: 3,000
- Fresh split hash: `efd605fe581dd89e07f5165611a2a6cf136d832fea82b0e318eff201a9f697de`
- Repeats: 2 per configuration
- Errors: 0 in every completed run
- Capture was off only during the synthetic run; it was restored afterward.
- No runtime setting was promoted.

## Results

| configuration | safe accepts | misses | interruptions | p95 latency |
| --- | ---: | ---: | ---: | ---: |
| baseline | 34.0 | 515.0 | 2,451.0 | 171.5 ms |
| `TOKEN_BUDGET=8` | 34.0 | 486.5 | 2,479.5 | 107.0 ms |
| `MAX_SCREEN_CHARS=700` | 34.0 | 515.5 | 2,450.5 | 147.5 ms |

The keep rule for this stage requires at least 15 fewer misses, no safe-accept
loss, no more than 15 extra interruptions, and p95 within the bounded latency
limit. `TOKEN_BUDGET=8` reduced misses by 28.5 but added 28.5 interruptions,
so it is rejected as “speaks more” rather than “better.” The screen cap was
effectively baseline and did not reduce misses.

## Decision

Both provisional candidates are **rejected**. Keep the source defaults. The
next high-value experiment is retrieval fallback behavior: determine whether
arbitrary corpus-wide examples on weak matches are causing wrong offers, and
test available-only, same-app-only, and zero-on-weak-match policies on a fresh
screen before considering any promotion.

Raw aggregate artifact:
`/Users/redbars/.cache/steadytype-eval/gym/autoresearch-missed-opportunities-20260802/expanded-confirm/summary.json`
