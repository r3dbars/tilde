# Tilda true-empty retry probe — 2026-08-02

## Question

Can one bounded retry recover a useful completion when the first response is
truly empty, without retrying partial streams or protocol failures?

## Protocol

- 3,000 fresh synthetic `exact_3` cases.
- Case hash: `6853108e40df57336e392e20c64a51600b6a48440cd2122bd357c72c9cf29167`.
- Retry only when the first response had an empty final suggestion, zero
  partial frames, and no error.
- The retry reused the same request; no production retry path changed.
- Aggregate metrics only; capture and synthetic-only settings were restored.

## Results

| policy | safe accepts | misses | interruptions | p95 latency |
| --- | ---: | ---: | ---: | ---: |
| no retry | 41 | 552 | 2,407 | 136 ms |
| true-empty retry | 41 | 550 | 2,409 | 136 ms |

149 cases were eligible. The second request recovered zero safe accepts,
left 147 cases missed, and produced two wrong interruptions. It reduced misses
by only two while adding two interruptions.

## Decision

Reject the retry. The strict eligibility rule prevented a broad reliability
regression, but the small recovery did not create useful completions. The next
retry work should wait for better event-level labels or a distinct generation
strategy; repeating the same request is not enough.

Raw aggregate artifact:
`/Users/redbars/.cache/steadytype-eval/gym/autoresearch-missed-opportunities-20260802/empty-retry-3000.json`
