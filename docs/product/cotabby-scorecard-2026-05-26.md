# Cotabby Pass Scorecard

Date: 2026-05-26

Scores are local judgment for this pass, not a replacement for
`steadytype-product-scorecard.md`.

| Area | Before | After | Evidence |
| --- | ---: | ---: | --- |
| Suggestion quality | 90 | 90 | No prompt/model quality change |
| Timing | 70 | 73 | Active AX cadence now floors at 80ms |
| Non-annoyance | 78 | 82 | Webmail blocked by name; quiet reasons clearer |
| Tab safety | 74 | 75 | Webmail cannot accidentally accept before proof |
| Esc/snooze behavior | 84 | 84 | No direct change |
| Sensitive-field suppression | 94 | 95 | Browser webmail added as a proof-needed surface |
| Browser/form suppression | 90 | 94 | Browser webmail separated from generic unknown pages |
| Visual placement | 70 | 70 | No geometry change; multi-display proof still needed |
| Latency | 70 | 72 | Lower AX heat; fresh runtime latency proof still needed |
| Local-first/privacy | 94 | 94 | No new data access |
| Onboarding/trust | 68 | 71 | "why quiet" explanations are clearer |
| Diagnostics | 90 | 92 | `silenceExplanation` adds redacted proof context |
| Beta readiness | 70 | 71 | Safer browser stance, but manual gates still block |
| Test coverage | 75 | 78 | Added focused tests for new policies |

## What Improved

- Browser email no longer hides inside generic browser blocking across Gmail,
  Outlook, Yahoo Mail, Fastmail, Proton Mail, and iCloud Mail.
- "Blocked" states are less cryptic.
- The hottest AX polling path is less aggressive.

## Remaining Risks

- This does not prove real Gmail or Outlook support.
- This does not fix all browser editor or multi-display placement issues.
- The 80ms cadence should get fresh latency and typing-performance proof before
  any beta claim changes.
