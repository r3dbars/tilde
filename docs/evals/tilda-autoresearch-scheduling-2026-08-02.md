# Tilda scheduling probe — 2026-08-02

## Question

Could request debounce explain the missed opportunities, and would a shorter
debounce reveal more useful suggestions before the next keystroke?

This is an evaluator-only probe. It does not change the app's live scheduler,
capture real usage, or promote a setting.

## Protocol

- 1,000 frozen synthetic `exact_3` cases.
- Case hash: `87dcab65e07bb0a8490f1e5935a21a9d0d86c354f6fa0b9cd82b8cf48a925273`.
- The model response and latency were measured once per case.
- Deterministic synthetic inter-keystroke gaps were assigned from 5–240 ms.
- Each policy was then scored as `debounce + measured latency <= gap`.
- Capture was disabled and word-completion handling was enabled only for this
  synthetic run; both were restored afterward.

## Results

| debounce | suggestions | revealed before next key | reveal rate | canceled stale |
| ---: | ---: | ---: | ---: | ---: |
| 0 ms | 820 | 212 | 25.85% | 608 |
| 10 ms | 820 | 185 | 22.56% | 635 |
| 25 ms | 820 | 157 | 19.15% | 663 |
| 50 ms | 820 | 127 | 15.49% | 693 |
| 100 ms | 820 | 62 | 7.56% | 758 |
| 120 ms | 820 | 45 | 5.49% | 775 |
| 200 ms | 820 | 2 | 0.24% | 818 |

There were zero protocol errors. Median reveal delay was 83 ms at zero
debounce, 94 ms at 10 ms, 108 ms at 25 ms, 134 ms at 50 ms, 184 ms at 100 ms,
201 ms at 120 ms, and 233 ms at 200 ms.

## Decision

This explains why a large debounce would hide opportunities, but it is not a
quality win by itself: the probe models timing and staleness, not whether a
revealed suggestion is accepted and kept. We therefore do **not** promote a
debounce change from this probe.

The useful follow-up is a real event-level scheduling holdout that scores
accepted/kept, dismissed, and typed-over outcomes while varying debounce. Until
that exists, keep the product scheduler unchanged and treat 0 ms as a timing
upper bound, not a recommendation.

## Artifact

Raw aggregate output (no text bodies):
`/Users/redbars/.cache/steadytype-eval/gym/autoresearch-missed-opportunities-20260802/scheduling-probe-1000.json`
