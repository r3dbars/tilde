# IBus Typing Booster Pass Scorecard

Date: 2026-05-26

Scale: 10 is best.

| Category | Before | After | Notes |
| --- | ---: | ---: | --- |
| Suggestion quality | 8 | 8 | No model/output changes in this pass. |
| Timing | 8 | 9 | New default pace is calmer for first installs. |
| Non-annoyance | 8 | 9 | Lower default activation pressure reduces surprise popups. |
| Tab safety | 9 | 9 | Unchanged: Tab remains one-word accept only while a visible suggestion is valid. |
| Esc/snooze behavior | 8 | 8 | Existing field quieting stays in place. |
| Sensitive-field suppression | 9 | 10 | Broader password-manager and private secret hints added. |
| Browser/form suppression | 9 | 9 | Existing dirty branch already touches browser webmail; this pass did not stage it. |
| Visual placement | 8 | 8 | No placement changes. |
| Latency | 8 | 8 | No runtime changes. |
| Local-first/privacy | 9 | 10 | Better automatic off-record behavior for password-manager-like surfaces. |
| Onboarding/trust | 8 | 9 | Calmer default makes first-run less surprising. |
| Diagnostics | 8 | 8 | No diagnostics UI change in this pass. |
| Beta readiness | 7 | 8 | Safety improved; manual proof still gates beta. |
| Test coverage | 8 | 9 | Added/updated focused unit tests for defaults and suppression. |

## Remaining Risks

- Existing dirty branch work around browser/webmail and visible-page context needs separate proof before staging.
- Changing the default pace affects new installs and first-run resets, not users who already have persisted tuning.
- On-demand summon remains unbuilt. It needs a dedicated shortcut, not Tab.

## Verification

Targeted:

```bash
swift test --jobs 1 --filter 'SuggestionAggressivenessTests|SensitiveTextFieldPolicyTests|AXFieldClassifierTests|CompletionActivationPolicyTests'
```

Full:

```bash
swift test --jobs 1
```
