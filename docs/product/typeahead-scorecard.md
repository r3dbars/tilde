# TypeAhead-Inspired Scorecard

Date: 2026-05-26

Scale: 1-10. This is a product-readiness score, not a claim that the app is
ready for broad release.

| Area | Before | After | Why |
| --- | ---: | ---: | --- |
| Suggestion quality | 7 | 7 | No model or ranking change in this pass. |
| Timing | 7 | 7 | No cadence change in this pass. |
| Non-annoyance | 7 | 7 | Existing burst, Esc, cooldown, and typed-over logic remain. |
| Tab safety | 9 | 9 | SteadyType keeps `Tab` one-word only. |
| Esc/snooze behavior | 8 | 8 | Existing field quieting remains. |
| Sensitive-field suppression | 8 | 9 | Suppression already existed; the reason is now clearer. |
| Browser/form suppression | 8 | 9 | Existing browser/form blocks now get clearer explanation text. |
| Visual placement | 7 | 7 | No placement change in this pass. |
| Latency | 6 | 6 | No runtime speed change in this pass. |
| Local-first/privacy | 8 | 8 | Existing local runtime and redaction remain. |
| Onboarding/trust | 7 | 8 | Quiet-state explanations are more human. |
| Diagnostics | 8 | 9 | Trace metadata now includes `silenceExplanation` for activation-policy blocks. |
| Beta readiness | 6 | 7 | Better tester comprehension without expanding support claims. |
| Test coverage | 8 | 9 | New unit tests cover the silence explanation policy. |

## Readout

The app was already stronger than TypeAhead on proof-gated support,
sensitive-field suppression, local redacted diagnostics, and `Tab` safety.

The biggest scorecard movement is trust. When a suggestion does not appear,
SteadyType can now say "search fields stay quiet" or "forms stay quiet"
instead of exposing internal policy names.

## Remaining Risks

- Manual smoke proof can still be stale after app-code changes.
- Chrome production pages remain blocked by design.
- Prompt and terminal hosts remain proof-only.
- True inline visual parity remains fragile outside proven targets.
- Runtime latency still needs current-build proof before any public speed claim.
