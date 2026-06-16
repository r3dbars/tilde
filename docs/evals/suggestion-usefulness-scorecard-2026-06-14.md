# Suggestion Usefulness Scorecard - 20 Synthetic Cases

Score: 100/100

This deterministic harness uses synthetic, disposable writing situations only. It asks whether the current local suggestion stack produces text that is useful, short, non-repetitive, safe, and quiet enough to avoid obvious annoyance.

## Summary

- Candidate rows scored: 20.
- Display-eligible rows: 18.
- Shown suggestions: 18/18.
- Useful suggestions: 20/20.
- Short suggestions: 20/20.
- Non-repetitive suggestions: 20/20.
- Safe or suppressed rows: 20/20.
- Non-annoyance gates: 6/6.

| Source | Accept-worthy | Shown | Useful | Short | Non-repetitive | Safe |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| canned-bridge | 4/4 | 4/4 | 4/4 | 4/4 | 4/4 | 4/4 |
| doc-local-ngram | 4/4 | 4/4 | 4/4 | 4/4 | 4/4 | 4/4 |
| model-candidate-ranker | 8/8 | 6/6 | 8/8 | 8/8 | 8/8 | 8/8 |
| word-completion | 4/4 | 4/4 | 4/4 | 4/4 | 4/4 | 4/4 |
| Total | 20/20 | 18/18 | 20/20 | 20/20 | 20/20 | 20/20 |

## Case Evidence

| Case | Source | Actual | Useful | Short | Non-repetitive | Safe | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| model-meeting-next-step | model-candidate-ranker |  clear next step | yes | yes | yes | yes | pass |
| model-review-risk | model-candidate-ranker |  real user risk | yes | yes | yes | yes | pass |
| model-simple-moves-forward | model-candidate-ranker |  move it forward | yes | yes | yes | yes | pass |
| model-small-check | model-candidate-ranker |  run one small check | yes | yes | yes | yes | pass |
| model-product-change | model-candidate-ranker |  one clear change | yes | yes | yes | yes | pass |
| model-open-questions | model-candidate-ranker |  open questions quickly | yes | yes | yes | yes | pass |
| model-password-silence | model-candidate-ranker | silence | yes | yes | yes | yes | pass |
| model-search-silence | model-candidate-ranker | silence | yes | yes | yes | yes | pass |
| bridge-take-look | canned-bridge |  take a look | yes | yes | yes | yes | pass |
| bridge-keep-simple | canned-bridge |  keep it simple | yes | yes | yes | yes | pass |
| bridge-what-think | canned-bridge |  what you think | yes | yes | yes | yes | pass |
| bridge-follow-up | canned-bridge |  follow up | yes | yes | yes | yes | pass |
| doc-local-release-note | doc-local-ngram |  name one clear change | yes | yes | yes | yes | pass |
| doc-local-trust-section | doc-local-ngram |  stay short and honest | yes | yes | yes | yes | pass |
| doc-local-demo | doc-local-ngram |  open questions quickly | yes | yes | yes | yes | pass |
| doc-local-proof-row | doc-local-ngram |  include source and result | yes | yes | yes | yes | pass |
| word-transcripted | fast-word-completion | ted | yes | yes | yes | yes | pass |
| word-permission | fast-word-completion | sion | yes | yes | yes | yes | pass |
| word-reliable | fast-word-completion | le | yes | yes | yes | yes | pass |
| word-instant | fast-word-completion | ant | yes | yes | yes | yes | pass |

## Non-Annoyance Gates

| Gate | What it proves | Result |
| --- | --- | --- |
| display-high-risk | high risk is suppressed before display | pass |
| one-brain-high-risk | one-brain preview keeps high risk as a hard veto | pass |
| one-brain-learned-restraint | one-brain preview reports learned restraint when it binds | pass |
| low-kept-probability | low accepted-and-kept probability suppresses phrase help | pass |
| annoyance-repeated-typed-over | repeated typed-over suggestions quiet the current field | pass |
| annoyance-accepted-kept | accepted-and-kept evidence reduces annoyance pressure | pass |

## Decision

This scorecard is green when the score stays at 100/100, every source remains accept-worthy, expected suppressions stay silent, and all non-annoyance gates pass. It is deterministic harness proof, not private dogfood or live model telemetry.
