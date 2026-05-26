# TypeAhead Opportunity Matrix

Date: 2026-05-26

Scores are 1-5. Higher is better for user value, annoyance reduction, privacy
fit, repo fit, and proofability. Lower is better for effort and technical risk.

| Idea | User value | Annoyance reduction | Privacy fit | Effort | Risk | Repo fit | Proofability | Decision |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| Plain "why no suggestion?" explanations for blocked fields | 5 | 5 | 5 | 1 | 1 | 5 | 5 | Shipped this pass |
| Keep `Tab` one-word only and full accept separate | 5 | 5 | 5 | 1 | 1 | 5 | 5 | Already core product rule |
| More visible local/offline proof in Settings | 5 | 4 | 5 | 2 | 2 | 5 | 5 | Next small product pass |
| Sensitive-field reason badges | 5 | 5 | 5 | 2 | 2 | 4 | 4 | Good next UI pass |
| Per-app frequency controls | 4 | 4 | 4 | 3 | 3 | 3 | 3 | Later; current pause/disable is enough |
| Browser production-page allowlist | 4 | 3 | 2 | 4 | 5 | 2 | 3 | Avoid until proof exists |
| Google Docs support | 4 | 3 | 2 | 5 | 5 | 2 | 3 | Keep blocked |
| Terminal/prompt support beyond proof mode | 3 | 4 | 2 | 5 | 5 | 2 | 3 | Keep proof-only |
| Whole-suggestion `Tab` accept parity | 3 | 1 | 3 | 2 | 4 | 1 | 4 | Avoid; conflicts with SteadyType safety |
| True inline ghost text everywhere | 4 | 2 | 3 | 5 | 5 | 2 | 2 | Avoid for MVP |
| Persistent voice learning by default | 4 | 2 | 1 | 5 | 5 | 2 | 2 | Avoid; opt-in dogfood only |
| Website-style broad category claims | 2 | 1 | 1 | 2 | 4 | 1 | 1 | Avoid |

## Highest Leverage Slice

The safest improvement is a trust layer over existing suppression logic. The
repo already blocks secure fields, search, URL/address bars, short forms,
unproven browser surfaces, unsupported apps, runtime-not-ready states, and
proof-only prompt surfaces. The missing piece is the tester-facing explanation.

Shipped now:

- `SuggestionSilenceExplanationPolicy`
- app wiring for activation-policy silence messages
- tests for search, URL/address, forms, secure fields, unproven surfaces,
  unknown fields, timing waits, selected text, sensitive content, and code
  context

Why this won:

- It copies no TypeAhead UI or copy.
- It turns a TypeAhead public gap into a SteadyType advantage.
- It is easy to prove with unit tests.
- It does not widen app support or increase privacy risk.
- It makes beta feedback clearer without storing typed text.
