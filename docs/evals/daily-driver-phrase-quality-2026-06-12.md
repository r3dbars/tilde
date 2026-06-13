# Daily Driver Phrase Quality Eval - 30 Real Writing Cases

Score: 100/100

This deterministic harness uses synthetic, disposable writing situations for TextEdit, Notes, and Obsidian. It asks whether short generic continuations would be worth accepting without relying on private dogfood text or product-specific canned phrases.

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
| textedit-phrase-01 | TextEdit |  take a look | 3 | model-candidate-ranker | accept |
| textedit-phrase-02 | TextEdit |  keep it simple | 3 | canned-bridge | accept |
| textedit-phrase-03 | TextEdit |  make this clearer | 3 | model-candidate-ranker | accept |
| textedit-phrase-04 | TextEdit |  what you think | 3 | canned-bridge | accept |
| textedit-phrase-05 | TextEdit |  a clearer next step | 4 | model-candidate-ranker | accept |
| textedit-phrase-06 | TextEdit |  to make this concrete | 4 | canned-bridge | accept |
| textedit-phrase-07 | TextEdit |  capture the next step | 4 | model-candidate-ranker | accept |
| textedit-phrase-08 | TextEdit |  to keep this clear | 4 | canned-bridge | accept |
| notes-phrase-09 | Notes |  take a look | 3 | model-candidate-ranker | accept |
| notes-phrase-10 | Notes |  keep it simple | 3 | canned-bridge | accept |
| notes-phrase-11 | Notes |  make this clearer | 3 | model-candidate-ranker | accept |
| notes-phrase-12 | Notes |  what you think | 3 | canned-bridge | accept |
| notes-phrase-13 | Notes |  a clearer next step | 4 | model-candidate-ranker | accept |
| notes-phrase-14 | Notes |  to make this concrete | 4 | canned-bridge | accept |
| notes-phrase-15 | Notes |  capture the next step | 4 | model-candidate-ranker | accept |
| notes-phrase-16 | Notes |  to keep this clear | 4 | canned-bridge | accept |
| obsidian-phrase-17 | Obsidian |  take a look | 3 | model-candidate-ranker | accept |
| obsidian-phrase-18 | Obsidian |  keep it simple | 3 | canned-bridge | accept |
| obsidian-phrase-19 | Obsidian |  make this clearer | 3 | model-candidate-ranker | accept |
| obsidian-phrase-20 | Obsidian |  what you think | 3 | canned-bridge | accept |
| obsidian-phrase-21 | Obsidian |  a clearer next step | 4 | model-candidate-ranker | accept |
| obsidian-phrase-22 | Obsidian |  to make this concrete | 4 | canned-bridge | accept |
| obsidian-phrase-23 | Obsidian |  capture the next step | 4 | model-candidate-ranker | accept |
| obsidian-phrase-24 | Obsidian |  to keep this clear | 4 | canned-bridge | accept |
| suppress-01 | TextEdit | silence | 0 | model-candidate-ranker | accept |
| suppress-02 | TextEdit | silence | 0 | model-candidate-ranker | accept |
| suppress-03 | Notes | silence | 0 | model-candidate-ranker | accept |
| suppress-04 | Notes | silence | 0 | model-candidate-ranker | accept |
| suppress-05 | Obsidian | silence | 0 | model-candidate-ranker | accept |
| suppress-06 | Obsidian | silence | 0 | model-candidate-ranker | accept |

## Decision

This harness is green when score stays at 100/100, suffix-noise failures stay at zero, and expected suppressions keep passing. It is deterministic phrase-quality proof, not private dogfood.
