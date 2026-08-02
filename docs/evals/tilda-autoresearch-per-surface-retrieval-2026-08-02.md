# Tilda per-surface retrieval confirmation — 2026-08-02

## Question

Does choosing a different retrieval count by app surface improve quality over
the global `exact_3` policy?

The proposed policy was browser=3, email=2, messages=1, notes=3, slack=0,
writing=0. It came from a retrospective estimate and required fresh
confirmation before it could be considered.

## Protocol

- Two disjoint fresh 10,000-case splits.
- Split 1 hash: `78e2f91278fac0a773e4c622a78f5682616ed367d8210e5c09b68e8bc9a8955f`.
- Split 2 hash: `3dd91ef06c68695d98147d4c9cde7f2576032a9687a05b9850358a3d61a85801`.
- Aggregate metrics only; no production retrieval policy changed.
- An earlier run used a reaped app/stale runtime settings and was discarded;
  only the corrected capture-off, word-mode synthetic runs below count.

## Results

| split | policy | safe accepts | misses | interruptions | p95 latency |
| --- | --- | ---: | ---: | ---: | ---: |
| 1 | global `exact_3` | 143 | 1,702 | 8,155 | 329 ms |
| 1 | per-surface | 130 | 1,673 | 8,197 | 237 ms |
| 2 | global `exact_3` | 133 | 1,804 | 8,063 | 162 ms |
| 2 | per-surface | 132 | 1,787 | 8,081 | 160 ms |

The proposed policy reduced misses by 29 and 17, respectively, but lost 13
and 1 safe accepts and added 42 and 18 interruptions. It does not satisfy
the keep rule on either split.

## Decision

Reject the per-surface retrieval policy. The apparent miss reduction is not a
quality improvement because it trades away safe completions and increases
interruption rate. Keep global `exact_3` while testing better exemplar quality
and ranking instead of surface-specific counts.

Raw aggregate artifact:
`/Users/redbars/.cache/steadytype-eval/gym/autoresearch-missed-opportunities-20260802/per-surface-retrieval-confirmation.json`
