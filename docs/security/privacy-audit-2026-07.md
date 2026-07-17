# Privacy Audit — July 2026

Audit date: 2026-07-17
Baseline: `origin/main` at `12a8a0a1`
Method: source review plus synthetic sentinel tests only. No personal writing or user content was inspected.

## Result

Two medium-severity privacy boundary failures were confirmed and fixed on separate branches. No network transmission path, permissive local artifact, or unredacted default export was found.

| ID | Severity | Finding | Status |
| --- | --- | --- | --- |
| PA-01 | Medium | Explicit raw-content and screenshot trace opt-ins could persist content from suppressed fields and from ordinary fields whose activation assessment detected secret-shaped text (`Sources/AutocompleteLabApp/App/AppDelegate.swift:2507`, `Sources/AutocompleteLabCore/Session/CompletionActivationPolicy.swift:204`, `Sources/AutocompleteLabApp/Mac/RawAutocompleteTraceLog.swift:376`). | Fixed in draft PR [#168](https://github.com/r3dbars/steadytype/pull/168) with a fail-closed logger boundary, activation-decision wiring, and synthetic regression coverage. |
| PA-02 | Medium | Sensitive profiles could reach Personal Capture before the later profile guard, while denylisted apps had no effective profile and were therefore treated as non-sensitive (`Sources/AutocompleteLabApp/App/AppDelegate.swift:1717`, `Sources/AutocompleteLabApp/App/AppDelegate.swift:1737`, `Sources/AutocompleteLabApp/App/AppDelegate.swift:1930`). | Fixed in draft PR [#169](https://github.com/r3dbars/steadytype/pull/169) with an authoritative support-status guard before AX reads. |
| PA-03 | Low | Native communication apps do not yet have an explicit Personal Capture blocklist contract; the policy has browser-hosted and field checks only (`Sources/AutocompleteLabCore/Session/PersonalCapturePolicy.swift:81`). | Follow-up [#166](https://github.com/r3dbars/steadytype/issues/166). |
| PA-04 | Low | Developer environment overrides for raw and screenshot tracing do not share the Settings UI's one-hour expiry (`Sources/AutocompleteLabApp/Mac/RawAutocompleteTraceLog.swift:75`). | Follow-up [#163](https://github.com/r3dbars/steadytype/issues/163). |
| PA-05 | Low | Trace signal fields rely on current call-site discipline instead of typed allowlists at the persistence boundary (`Sources/AutocompleteLabApp/Mac/RawAutocompleteTraceLog.swift:398`, `Sources/AutocompleteLabApp/Mac/RawAutocompleteTraceLog.swift:436`). | Follow-up [#165](https://github.com/r3dbars/steadytype/issues/165). |

## Confirmed fixes

### PA-01 — sensitive surfaces in raw traces

`RawAutocompleteTraceLog` normally redacts typed text, but explicit raw tracing bypassed that redaction (`Sources/AutocompleteLabApp/Mac/RawAutocompleteTraceLog.swift:376-442`). The activation-policy trace call could still supply text from a suppressed field or an ordinary compose field blocked as `.sensitiveContent` (`Sources/AutocompleteLabApp/App/AppDelegate.swift:2507-2522`). The app now derives trace sensitivity from both field classification and the activation decision. The logger also fails closed when `fieldKindSuppressed=true`, and drops both raw text and screenshot paths for that event. Synthetic sentinels cover every text-bearing field, metadata, screenshot paths, and the ordinary-field activation seam (`Tests/AutocompleteLabAppTests/RawTracePrivacyExpiryTests.swift:107-177`).

Reviewed boundaries:

- secure Accessibility fields return before trace capture (`Sources/AutocompleteLabApp/App/AppDelegate.swift:1885`);
- browser-hosted surfaces send empty text (`Sources/AutocompleteLabApp/App/AppDelegate.swift:2166-2176`);
- native suppressed fields and normal fields with secret-shaped content reach the activation-policy event and are now redacted at the logger boundary;
- screenshot capture occurs only after activation succeeds, and the logger also drops any sensitive screenshot path defensively.

### PA-02 — Personal Capture sensitive-app bypass

The disabled-app branch could call `pollPersonalCaptureOnly` before the later `profile.isSensitive` suggestion guard, and the unsupported-app branch passed `nil` for denylisted apps (`Sources/AutocompleteLabApp/App/AppDelegate.swift:1717-1757`). The central entry point then interpreted a missing profile as non-sensitive before reading the field (`Sources/AutocompleteLabApp/App/AppDelegate.swift:1930-1939`). It now passes `CompatibilityProfileStore.supportStatus` into `PersonalCapturePolicy.allowsAppRead` before any Accessibility read. Synthetic policy tests prove both a denylisted password manager and a supported-sensitive app remain blocked, while the wiring test locks the authoritative store lookup (`Tests/AutocompleteLabCoreTests/PersonalCapturePolicyTests.swift:8-35`, `Tests/AutocompleteLabAppTests/LiveSuggestionWiringTests.swift:63-72`).

## Verified controls

- Personal Capture is off by default (`Sources/AutocompleteLabApp/App/AppSettings.swift:125-135`) and local-only. Policy rejects secure fields, sensitive text patterns, browser-hosted editors, and suppressed field kinds (`Sources/AutocompleteLabCore/Session/PersonalCapturePolicy.swift:81-127`).
- Default raw traces redact all text-bearing event fields and metadata before persistence (`Sources/AutocompleteLabApp/Mac/RawAutocompleteTraceLog.swift:399-442`).
- Diagnostic report export runs every event through `RedactionLayer.redactedDefaultTrace`; its manifest states that raw text and screenshots are excluded (`Sources/AutocompleteLabApp/Mac/LocalReportExporter.swift:22-67`).
- Personal journals, derived indexes, traces, and exports use `SecureLocalStorage` with owner-only directory and file permissions (`0700` and `0600`), including after atomic rewrites (`Sources/AutocompleteLabApp/Mac/SecureLocalStorage.swift:18-94`).
- `UserDefaults` contains Personal Capture and other settings, not its journal text (`Sources/AutocompleteLabApp/App/AppSettings.swift:73-75`); accepted style memory persists aggregate counters (`Sources/AutocompleteLabCore/Session/AcceptedTextStyleMemory.swift:19-27`, `Sources/AutocompleteLabCore/Session/AcceptedTextStyleMemory.swift:110-132`). Model completion cache state is memory-only (`Sources/AutocompleteLabCore/Engine/LocalCompletionEngine.swift:180-208`).
- The production completion contract constructs an in-process MLX runtime from a local model directory (`Sources/AutocompleteLabApp/Runtime/AppModelRuntimeFactory.swift:67-100`); the scoped source sweep found no production upload, analytics SDK, crash reporter, or cloud completion call.
- Production diagnostics metadata is redacted at its write boundary (`Sources/AutocompleteLabApp/Mac/DiagnosticsLog.swift:59-64`). The older `TraceLogger` has no production caller; its overlap with the active trace path is tracked as hardening in PA-05 (`Sources/AutocompleteLabApp/Mac/TraceLogger.swift:1`).

## Retention notes

Settings-based raw-content and screenshot tracing expires after one hour and performs cleanup. The developer environment override gap is PA-04. Default redacted diagnostic traces remain until the user deletes them, matching the documented diagnostics contract. Personal Capture journals are intentionally durable local writing memory when the user opts in.

## Logger grep sweep

The audit ran `rg -n '\b(print|NSLog|os_log|Logger)\s*\(' Sources script`. `Sources` contains six `print` call sites, all in explicit proof or report CLI paths; the app proof command prints only the generated local export path (`Sources/AutocompleteLabApp/App/PrivacyExportProofCommand.swift:33-42`) and replay commands print generated reports (`Sources/AutocompleteTraceReplay/main.swift:106-116`, `Sources/SteadyTypeReplayEval/main.swift:376-383`). No `NSLog`, `os_log`, or `Logger(` call site exists in `Sources` or `script`. Script matches are command output and test/proof helpers; the raw-output quality-audit mode requires a separate environment opt-in (`script/local_quality_audit.py:783-815`). No non-opt-in typed-text logging leak was confirmed.

## Proof

Each fix branch must pass:

```sh
./script/proof.sh fast
```

The targeted synthetic suites are:

```sh
swift test --jobs 1 --filter RawTracePrivacyExpiryTests
swift test --jobs 1 --filter PersonalCapturePolicyTests
swift test --jobs 1 --filter LiveSuggestionWiringTests
```

These suites passed 6, 7, and 7 tests respectively on the corrected PR heads.

Privacy export behavior is additionally covered by `RawTraceReportExportTests`, `PrivacyExportProofCommandTests`, and the fast proof gate. Manual or live-user-content proof was neither required nor performed for this source-level audit.
