# Completion Prediction Quality Eval - 500 Cases

Score: 100.0/100
Squared score: 10000.0/10000

This deterministic harness uses 500 synthetic cases. It checks whether the app's cleaner and ranker pick common next-word and 2-4 word continuations when they are available, while still suppressing prompt-app, search, form, password, and code-like negatives.

## Summary

| Surface | Shown | Next word exact | 2-word exact | 3-word exact | 4-word exact | Silence exact | Unsafe displays |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Code field negative | 0/20 | 100% | 100% | 100% | 100% | 100% | 0 |
| Chrome contenteditable | 80/80 | 100% | 100% | 100% | 100% | 100% | 0 |
| Chrome textarea | 80/80 | 100% | 100% | 100% | 100% | 100% | 0 |
| Codex prompt negative | 0/20 | 100% | 100% | 100% | 100% | 100% | 0 |
| Form field negative | 0/20 | 100% | 100% | 100% | 100% | 100% | 0 |
| Notes | 80/80 | 100% | 100% | 100% | 100% | 100% | 0 |
| Obsidian | 80/80 | 100% | 100% | 100% | 100% | 100% | 0 |
| Password field negative | 0/20 | 100% | 100% | 100% | 100% | 100% | 0 |
| Search field negative | 0/20 | 100% | 100% | 100% | 100% | 100% | 0 |
| TextEdit | 80/80 | 100% | 100% | 100% | 100% | 100% | 0 |
| Total | 400/500 | 100% | 100% | 100% | 100% | 100% | 0 |

## Corpus Shape

- 400 positive cases across TextEdit, Notes, Obsidian, Chrome textarea, and Chrome contenteditable.
- 100 expected-silence cases across Codex prompt, search, form, password-like, and code-like fields.
- Positive cases are split evenly across 1-word, 2-word, 3-word, and 4-word expectations.
- Candidate order is rotated so the expected phrase is not always first.
- All text is synthetic and disposable; no user traces, screenshots, or raw private text are stored here.

## Decision

The deterministic 500-case loop is green when this report stays at 100/100 and unsafe displays stay at zero. It is not a claim that the live model is 100/100; current-model quality still needs the opt-in disposable local audit.
