# IBus Typing Booster Gap Map

Date: 2026-05-26

## Current SteadyType Strengths

| Lesson | Current repo fit |
| --- | --- |
| Do not suggest in risky fields | `SensitiveTextFieldPolicy`, `AXFieldClassifier`, `CompletionActivationPolicy`, `BrowserHostedSurfacePolicy`. |
| Keep app support proof-gated | `CompatibilityProfileStore`, `HostCompatibilityPolicy`, `docs/product/proof-manifest.json`. |
| Keep Tab safe | `KeyboardEventTapConsumptionPolicy`, `KeyboardActionRouter`, `SuggestionAcceptanceProofPolicy`, `AppDelegate`. |
| Dismiss and quiet the field | `AnnoyanceSuppressor`, `PrefixFamilyCooldownPolicy`, `suppressedFieldIdentities` in `AppDelegate`. |
| Keep local privacy proof | `AutocompleteTracePrivacyFilter`, `TraceLogger`, `RawAutocompleteTraceLog`, `PrivacyExportProofCommand`, `PersonalCapturePolicy`. |
| Explain support state | `SettingsWindowController`, `DiagnosticsWindowController`, `SuggestionSilenceExplanationPolicy` in the current working tree. |

## Gaps Found

| Gap | Why It Matters | Files |
| --- | --- | --- |
| Default pace was still fairly proactive for a first install | IBus complaints show surprise popups are a core churn path. | `Sources/AutocompleteLabCore/Session/SuggestionAggressiveness.swift` |
| Password-manager variants were not broad enough | IBus terminal/password reports make secret surfaces a hard stop condition. | `SensitiveTextFieldPolicy.swift`, `AXFieldClassifier.swift`, `CompletionActivationPolicy.swift` |
| No explicit summon-on-demand product mode | IBus `tabenable` is valuable, but SteadyType cannot use Tab for summon without breaking Tab accept. | Future: `KeyboardAction`, `AppSettings`, `SuggestionTriggerPolicy`, Settings UI |
| Learned suggestion removal is not first-class enough | IBus lets users remove learned candidates. SteadyType has learning stores, but not a crisp "never suggest this again" UI. | Future: `SuggestionRepetitionSuppressor`, `PersonalCaptureEpisodeStore`, Diagnostics/Settings |
| Browser-hosted webmail suppression is mid-flight in this worktree | Good safety direction, but belongs to the existing dirty branch work and needs proof-manifest alignment. | Current dirty files: `BrowserHostedSurfacePolicy.swift`, browser tests |

## Files Changed In This Pass

- `Sources/AutocompleteLabCore/Session/SuggestionAggressiveness.swift`
- `Sources/AutocompleteLabCore/Session/SensitiveTextFieldPolicy.swift`
- `Sources/AutocompleteLabCore/Session/AXFieldClassifier.swift`
- `Sources/AutocompleteLabCore/Session/CompletionActivationPolicy.swift`
- `Tests/AutocompleteLabCoreTests/SuggestionAggressivenessTests.swift`
- `Tests/AutocompleteLabCoreTests/SensitiveTextFieldPolicyTests.swift`
- `Tests/AutocompleteLabCoreTests/AXFieldClassifierTests.swift`
- `Tests/AutocompleteLabCoreTests/CompletionActivationPolicyTests.swift`

## Proof Map

Run:

```bash
swift test --jobs 1 --filter 'SuggestionAggressivenessTests|SensitiveTextFieldPolicyTests|AXFieldClassifierTests|CompletionActivationPolicyTests'
swift test --jobs 1
```

Manual proof still matters after app-code changes:

```bash
./script/build_and_run.sh --verify
./script/manual_smoke_status.sh --strict
```
