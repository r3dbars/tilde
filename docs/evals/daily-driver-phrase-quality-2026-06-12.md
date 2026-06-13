# Daily Driver Phrase Quality Eval - 30 Real Writing Cases

Score: 100/100

This deterministic harness uses synthetic, disposable writing situations for TextEdit, Notes, and Obsidian. It asks the product question directly: would this visible suggestion be worth accepting?

## Acceptance Bar

A displayed phrase passes only when it is 3-8 words, matches the expected meaning terms, avoids assistant/action/sensitive text, and does not restart recent context. One- or two-word phrase nubs count as suffix-noise failures in this eval.

## Summary

- Rows scored: 30.
- Display-eligible rows: 24.
- Suppressed/no-suggestion rows: 6.
- Accept-worthy rows: 30/30.
- 3-8 word phrase rate: 100%.
- Relevance score: 100%.
- Suffix-noise failures: 0.
- Expected suppressions passed: 6/6.

| Surface | Shown | 3-8 words | Relevant | Suffix-noise failures | Silence exact | Would accept |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Notes | 8/8 | 100% | 100% | 0 | 2/2 | 100% |
| Obsidian | 8/8 | 100% | 100% | 0 | 2/2 | 100% |
| TextEdit | 8/8 | 100% | 100% | 0 | 2/2 | 100% |
| Total | 24/24 | 100% | 100% | 0 | 6/6 | 100% |

## Case Evidence

| Case | Surface | Actual | Words | Source | Result |
| --- | --- | --- | ---: | --- | --- |
| textedit-phrase-01 | TextEdit |  light and clear | 3 | model-candidate-ranker | accept |
| textedit-phrase-02 | TextEdit |  stays short and specific | 4 | predictive-phrase-fallback | accept |
| textedit-phrase-03 | TextEdit |  run one small check | 4 | model-candidate-ranker | accept |
| textedit-phrase-04 | TextEdit |  clear next step | 3 | predictive-phrase-fallback | accept |
| textedit-phrase-05 | TextEdit |  the key details clearly | 4 | model-candidate-ranker | accept |
| textedit-phrase-06 | TextEdit |  small focused tasks | 3 | predictive-phrase-fallback | accept |
| textedit-phrase-07 | TextEdit |  owner and deadline | 3 | model-candidate-ranker | accept |
| textedit-phrase-08 | TextEdit |  something fast and reliable | 4 | predictive-phrase-fallback | accept |
| notes-phrase-09 | Notes |  light and clear | 3 | model-candidate-ranker | accept |
| notes-phrase-10 | Notes |  stays short and specific | 4 | predictive-phrase-fallback | accept |
| notes-phrase-11 | Notes |  run one small check | 4 | model-candidate-ranker | accept |
| notes-phrase-12 | Notes |  clear next step | 3 | predictive-phrase-fallback | accept |
| notes-phrase-13 | Notes |  the key details clearly | 4 | model-candidate-ranker | accept |
| notes-phrase-14 | Notes |  small focused tasks | 3 | predictive-phrase-fallback | accept |
| notes-phrase-15 | Notes |  owner and deadline | 3 | model-candidate-ranker | accept |
| notes-phrase-16 | Notes |  something fast and reliable | 4 | predictive-phrase-fallback | accept |
| obsidian-phrase-17 | Obsidian |  light and clear | 3 | model-candidate-ranker | accept |
| obsidian-phrase-18 | Obsidian |  stays short and specific | 4 | predictive-phrase-fallback | accept |
| obsidian-phrase-19 | Obsidian |  run one small check | 4 | model-candidate-ranker | accept |
| obsidian-phrase-20 | Obsidian |  clear next step | 3 | predictive-phrase-fallback | accept |
| obsidian-phrase-21 | Obsidian |  the key details clearly | 4 | model-candidate-ranker | accept |
| obsidian-phrase-22 | Obsidian |  small focused tasks | 3 | predictive-phrase-fallback | accept |
| obsidian-phrase-23 | Obsidian |  owner and deadline | 3 | model-candidate-ranker | accept |
| obsidian-phrase-24 | Obsidian |  something fast and reliable | 4 | predictive-phrase-fallback | accept |
| suppress-01 | TextEdit | silence | 0 | model-candidate-ranker | accept |
| suppress-02 | TextEdit | silence | 0 | model-candidate-ranker | accept |
| suppress-03 | Notes | silence | 0 | model-candidate-ranker | accept |
| suppress-04 | Notes | silence | 0 | model-candidate-ranker | accept |
| suppress-05 | Obsidian | silence | 0 | model-candidate-ranker | accept |
| suppress-06 | Obsidian | silence | 0 | model-candidate-ranker | accept |

## Decision

This harness is green when score stays at 100/100, suffix-noise failures stay at zero, and expected suppressions keep passing. It is deterministic phrase-quality proof, not private dogfood.
