# Word Completion Quality Eval - 2026-05-09

Score: 9.6/10

This deterministic report uses app-surface-shaped cases for TextEdit, Notes,
Obsidian, and Chrome-like fields. It checks that word completion stays
one-word, quiet, and app-scoped while measuring miss behavior.

## Summary

| Surface | Shown | Candidate quality | Miss rate | Typed-over rate | Repeated miss suppressed | Prefix cooldown blocked | Partial accept |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Chrome-like fields | 3/4 | 100% | 33% | 33% | 1/1 | 1/1 | 1/1 |
| Notes | 3/4 | 100% | 0% | 0% | 0/0 | 0/0 | 1/1 |
| Obsidian | 3/4 | 100% | 0% | 0% | 0/0 | 0/0 | 1/1 |
| TextEdit | 2/4 | 100% | 0% | 0% | 0/0 | 0/0 | 1/1 |
| Total | 11/16 | 100% | 9% | 9% | 1/1 | 1/1 | 4/4 |

## Case Evidence

| Case | Surface | Expected | Actual | Action | Result | Partial accept |
| --- | --- | --- | --- | --- | --- | --- |
| textedit-dictation | TextEdit | tation | tation | accepted | ok | n/a |
| textedit-instant-partial | TextEdit | ant | ant | typedThrough | ok | ok |
| textedit-low-value-kind | TextEdit | silence | silence | expectedSilence | ok | n/a |
| textedit-two-letter-floor | TextEdit | silence | silence | expectedSilence | ok | n/a |
| notes-follow | Notes | low | low | accepted | ok | n/a |
| notes-important-partial | Notes | tant | tant | typedThrough | ok | ok |
| notes-action | Notes | ion | ion | accepted | ok | n/a |
| notes-short-fragment | Notes | silence | silence | expectedSilence | ok | n/a |
| obsidian-name | Obsidian | ian | ian | accepted | ok | n/a |
| obsidian-product-partial | Obsidian | ted | ted | typedThrough | ok | ok |
| obsidian-permission | Obsidian | sion | sion | accepted | ok | n/a |
| obsidian-code-word | Obsidian | silence | silence | expectedSilence | ok | n/a |
| chrome-confirm | Chrome-like fields | irm | irm | accepted | ok | n/a |
| chrome-submit | Chrome-like fields | tted | tted | typedThrough | ok | ok |
| chrome-documentary-typed-over | Chrome-like fields | umentary | umentary | typedOver | miss | n/a |
| chrome-low-value-this | Chrome-like fields | silence | silence | expectedSilence | ok | n/a |

## Decision

Word completion reaches 9.6/10 in this harness. The remaining gap to 10/10 is
live dogfood volume, not a need to make completions louder.
