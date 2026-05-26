# Cotabby Opportunity Matrix

Date: 2026-05-26

Scores are 1 to 5. Higher is better except effort and risk, where 5 means
heavier or riskier.

| Idea | User value | Annoyance reduction | Privacy fit | Effort | Tech risk | Repo fit | Proofability | Decision |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| Plain "why quiet" explanations | 5 | 5 | 5 | 2 | 1 | 5 | 5 | Ship now |
| Raise hottest AX poll loop from 50ms to 80ms | 4 | 5 | 5 | 1 | 2 | 5 | 5 | Ship now |
| Browser webmail blocked/proof-needed class | 4 | 5 | 5 | 2 | 1 | 5 | 5 | Ship now |
| Guided TextEdit-first practice | 5 | 4 | 5 | 3 | 2 | 5 | 4 | Already mostly present |
| Per-app pause and disable | 5 | 5 | 5 | 3 | 2 | 5 | 5 | Already present |
| Screen Recording visual context | 3 | 2 | 1 | 4 | 4 | 2 | 3 | Avoid for beta default |
| Clipboard context | 2 | 1 | 1 | 3 | 4 | 1 | 2 | Avoid by default |
| Bring-your-own model UI | 3 | 2 | 4 | 4 | 4 | 2 | 3 | Later |
| Grammar correction mode | 4 | 3 | 4 | 4 | 3 | 2 | 3 | Later, separate mode |
| Multilingual tuning | 3 | 2 | 5 | 4 | 3 | 2 | 3 | Later |
| Browser Google Docs support | 4 | 2 | 3 | 5 | 5 | 2 | 2 | Keep blocked |
| Production Slack/Discord/ChatGPT support | 4 | 2 | 2 | 5 | 5 | 2 | 2 | Keep proof-only or blocked |

## Shipped From This Pass

- `SuggestionSilenceExplanationPolicy` turns internal block reasons into calm,
  user-facing reasons.
- `FocusPollingCadencePolicy` now has an 80ms minimum active AX poll cadence.
- `BrowserHostedSurfacePolicy` now classifies browser webmail separately from
  generic unknown pages across Gmail, Outlook, Yahoo Mail, Fastmail, Proton Mail,
  and iCloud Mail, and requires reply-specific latency/undo proof.

## Explicit Non-Goals

- No Screen Recording requirement.
- No clipboard context.
- No broad "works everywhere" support language.
- No copied Cotabby UI, code, assets, or copy.
