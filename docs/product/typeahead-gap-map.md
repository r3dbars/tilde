# TypeAhead Gap Map

Reviewed: 2026-05-26

## Current Strengths

SteadyType already has strong versions of the safest TypeAhead lessons:

- Local-first runtime: `Sources/AutocompleteLabApp/Runtime/`
- App-owned model install and repair: `Sources/AutocompleteLabApp/Runtime/LocalModelAssetInstaller.swift`
- Redacted traces by default: `Sources/AutocompleteLabApp/Mac/RawAutocompleteTraceLog.swift`, `Sources/AutocompleteLabCore/Tracing/`
- App proof gates: `docs/product/compatibility-matrix.md`, `docs/product/proof-manifest.json`
- Settings trust controls: `Sources/AutocompleteLabApp/UI/SettingsWindowController.swift`
- `Tab` one-word accept: `Sources/AutocompleteLabApp/App/AppDelegate.swift`, `Sources/AutocompleteLabCore/Session/AcceptedTextSafetyPolicy.swift`
- Esc/session silence: `Sources/AutocompleteLabApp/App/AppDelegate.swift`
- Annoyance learning: `Sources/AutocompleteLabCore/Session/AnnoyanceSuppressor.swift`, `Sources/AutocompleteLabApp/Mac/AnnoyanceSuppressorActor.swift`

## Main Gap

The product has the right safety behavior, but some user-facing status text still used internal codes such as `blockedFieldKind`, `tooLittleContext`, or `unfinishedWord`.

That is too engineer-facing for a beta. Users should see:

- "search fields stay quiet"
- "URL and address fields stay quiet"
- "secure fields stay quiet"
- "surface needs proof first"
- "waiting for more context"

## Files Mapped To The Fix

- New pure policy: `Sources/AutocompleteLabCore/Session/SuggestionSilenceExplanationPolicy.swift`
- App wiring: `Sources/AutocompleteLabApp/App/AppDelegate.swift`
- Privacy proof copy: `Sources/AutocompleteLabApp/UI/SettingsWindowController.swift`
- Real-app proof helper: `script/real_app_smoke.sh`
- Tests: `Tests/AutocompleteLabCoreTests/SuggestionSilenceExplanationPolicyTests.swift`

## Why This Fits The Repo

This repo already treats privacy and silence as product behavior. A small policy keeps the copy consistent and testable without building a new UI system.

The raw trace `reason` remains stable for tooling. The human explanation is added separately as `silenceExplanation`, which avoids turning typed text or freeform content into diagnostics.
