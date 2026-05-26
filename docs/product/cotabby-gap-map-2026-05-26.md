# Cotabby Gap Map

Date: 2026-05-26

## Current SteadyType Strengths

| Lesson | Current repo surface |
| --- | --- |
| Local-first runtime should be app-owned | `Sources/AutocompleteLabApp/Runtime/AppModelRuntimeFactory.swift`, `Sources/AutocompleteLabApp/Runtime/MLXModelRuntime.swift`, `docs/research/runtime-options.md` |
| Suggestions should be proof-gated by app | `Sources/AutocompleteLabCore/Compatibility/AppCompatibilityProfile.swift`, `Sources/AutocompleteLabCore/Compatibility/CompatibilityRouter.swift`, `docs/product/compatibility-matrix.md` |
| Tab must be safe | `Sources/AutocompleteLabCore/Session/SuggestionAcceptanceGuard.swift`, `Sources/AutocompleteLabCore/Session/SuggestionAcceptanceProofPolicy.swift`, `Tests/AutocompleteLabCoreTests/SuggestionAcceptanceGuardTests.swift` |
| Sensitive fields should fail closed | `Sources/AutocompleteLabCore/Session/SensitiveTextFieldPolicy.swift`, `Sources/AutocompleteLabCore/Session/AXFieldClassifier.swift`, `Tests/AutocompleteLabCoreTests/SensitiveTextFieldPolicyTests.swift` |
| Browser-hosted surfaces need exact proof | `Sources/AutocompleteLabCore/Configuration/BrowserHostedSurfacePolicy.swift`, `Tests/AutocompleteLabCoreTests/BrowserHostedSurfacePolicyTests.swift` |
| Placement needs current proof | `Sources/AutocompleteLabCore/Geometry/SuggestionPanelFrameCalculator.swift`, `Sources/AutocompleteLabApp/UI/SuggestionPanelController.swift`, `docs/product/visual-placement-screenshots/` |
| Accepted text must survive | `Sources/AutocompleteLabCore/Session/AcceptedAndKeptLearning.swift`, `Sources/AutocompleteLabApp/App/AcceptanceSurvivalChecker.swift`, `docs/product/eval-and-tracing.md` |
| Diagnostics need redaction | `Sources/AutocompleteLabCore/Tracing/AutocompleteTracePrivacyFilter.swift`, `Sources/AutocompleteLabApp/Mac/RedactionLayer.swift`, `DIAGNOSTIC-EXPORT.md` |

## Gaps Found

| Gap | Why it matters | Repo mapping | Action |
| --- | --- | --- | --- |
| Some block reasons were too implementation-shaped | "Blocked: blockedFieldKind" is true but not helpful to a tester | `AppDelegate`, new `SuggestionSilenceExplanationPolicy` | Shipped plain explanations |
| Browser webmail was folded into generic unknown browser pages | Cotabby issue #226 shows webmail can lag and miss input | `BrowserHostedSurfacePolicy` | Shipped explicit `webmail` block for Gmail, Outlook, Yahoo Mail, Fastmail, Proton Mail, and iCloud Mail |
| Active AX polling was still at 50ms | Cotabby hotfix raised 50ms to 80ms after lag reports | `FocusPollingCadencePolicy`, `AppDelegate` | Shipped 80ms floor |
| Webmail proof was not named in docs | Without a named proof lane it can accidentally graduate under generic Chrome | `compatibility-matrix.md`, scorecard docs | Documented as blocked |

## Files Changed By This Pass

- `Sources/AutocompleteLabCore/Session/SuggestionSilenceExplanationPolicy.swift`
- `Sources/AutocompleteLabCore/Session/FocusPollingCadencePolicy.swift`
- `Sources/AutocompleteLabCore/Configuration/BrowserHostedSurfacePolicy.swift`
- `Sources/AutocompleteLabApp/App/AppDelegate.swift`
- `Tests/AutocompleteLabCoreTests/SuggestionSilenceExplanationPolicyTests.swift`
- `Tests/AutocompleteLabCoreTests/FocusPollingCadencePolicyTests.swift`
- `Tests/AutocompleteLabCoreTests/FocusedTextPollGatePolicyTests.swift`
- `Tests/AutocompleteLabCoreTests/BrowserHostedSurfacePolicyTests.swift`

## Proof Commands

```bash
swift test --jobs 1 --filter 'BrowserHostedSurfacePolicyTests|FocusPollingCadencePolicyTests|FocusedTextPollGatePolicyTests|SuggestionSilenceExplanationPolicyTests'
swift test --jobs 1
```

If app behavior is being revalidated manually, use:

```bash
./script/manual_smoke_status.sh --strict
./script/check_sensitive_field_proof_self_test.sh
./script/check_trace_eval.sh
```
