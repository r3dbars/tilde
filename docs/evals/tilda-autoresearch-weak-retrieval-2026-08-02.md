# Tilda weak-match retrieval fallback screen — 2026-08-02

## Question

When fewer than three same-app, same-topic exemplars exist, is the current
corpus-wide fallback worse than returning fewer or more local examples?

## Protocol

- 3,000 fresh synthetic cases, three retrieved examples requested.
- Case hash: `0e3075f6cd10a621907a3d90b54a02f19cbef2f11c485a608f1b36052ffe2ee6`.
- `current`: existing behavior, arbitrary corpus-wide fallback.
- `available-only`: return only the exact matches available.
- `zero-on-weak-match`: return no examples when exact matches are sparse.
- `same-surface-only`: fill from the same app surface, never another surface.
- Aggregate metrics only; no production retrieval code or setting changed.
- Errors were zero for every policy.

## Results

| policy | safe accepts | misses | interruptions | p95 latency |
| --- | ---: | ---: | ---: | ---: |
| current | 49 | 509 | 2,442 | 141 ms |
| available-only | 44 | 513 | 2,443 | 141 ms |
| zero-on-weak-match | 44 | 512 | 2,444 | 137 ms |
| same-surface-only | 47 | 518 | 2,435 | 137 ms |

The current policy is the best of this screen. Available-only and zero-on-
weak-match both lost five safe accepts. Same-surface-only lost two safe
accepts and added nine misses. None meets the keep rule.

## Decision

Reject all three fallback changes. This synthetic corpus does not support
replacing the current fallback yet. The result also narrows the next question:
the important improvement is likely better exemplar quality/ranking, not a
blanket “never cross surfaces” rule.

Raw aggregate artifact:
`/Users/redbars/.cache/steadytype-eval/gym/autoresearch-missed-opportunities-20260802/weak-retrieval-fallback-3000.json`
