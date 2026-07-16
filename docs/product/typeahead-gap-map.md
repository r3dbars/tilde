# TypeAhead Gap Map

Date: 2026-05-26

This maps public TypeAhead lessons onto the current SteadyType codebase.

## Core Loop

TypeAhead public loop:

- type in another app,
- pause,
- see ghost text,
- accept all with `Tab`,
- accept one word with `Right Arrow`,
- dismiss with `Esc`,
- keep typing to ignore.

SteadyType map:

- `Sources/AutocompleteLabApp/App/AppDelegate.swift`: polling, focused field
  processing, scheduling, key handling, and app-level orchestration.
- `Sources/AutocompleteLabCore/Session/SuggestionTriggerPolicy.swift`:
  cadence and pause timing.
- `Sources/AutocompleteLabCore/Session/CompletionActivationPolicy.swift`:
  whether a field should request a suggestion.
- `Sources/AutocompleteLabCore/Session/KeyboardAction.swift` and
  `KeyboardActionRouter`: `Tab`, full accept shortcut, `Esc`, and undo routing.
- `Sources/AutocompleteLabApp/Mac/KeyboardEventTap.swift`: live key capture.

Current stance is safer than TypeAhead parity: `Tab` accepts one word only, and
full accept is a separate action.

## Placement

TypeAhead claims inline ghost text at the cursor.

SteadyType map:

- `Sources/AutocompleteLabApp/UI/SuggestionPanelController.swift`: AppKit
  overlay panel.
- `Sources/AutocompleteLabCore/Geometry/SuggestionPanelFrameCalculator.swift`:
  placement math.
- `Sources/AutocompleteLabCore/Geometry/PlacementHealth.swift`: placement trust.
- `Sources/AutocompleteLabCore/Compatibility/InlineGhostPlacementResolver.swift`:
  render decisions.
- `docs/product/caret-locked-research-queue.md`: caret-locking proof queue.

Gap: real inline visual feel is still proof-gated. Keep floating overlay and
mirror fallback until exact app proof exists.

## App Compatibility

TypeAhead claims broad app support and lists exceptions for remote desktop,
VMs, and non-standard fields.

SteadyType map:

- `Sources/AutocompleteLabCore/Configuration/CompatibilityProfile.swift`
- `Sources/AutocompleteLabCore/Configuration/BrowserHostedSurfacePolicy.swift`
- `Sources/AutocompleteLabCore/Configuration/PromptEditorFingerprintPolicy.swift`
- `docs/product/compatibility-matrix.md`
- `docs/product/manual-smoke-checklist.md`
- `docs/product/proof-manifest.json`

Gap: SteadyType intentionally has narrower public support. This is a feature,
not a defect, until proof exists.

## Sensitive Fields

TypeAhead has strong local-only privacy claims. I did not find an explicit
public password/search/payment/private-prompt suppression story.

SteadyType map:

- `Sources/AutocompleteLabCore/Session/SensitiveTextFieldPolicy.swift`
- `Sources/AutocompleteLabCore/Session/AXFieldClassifier.swift`
- `Sources/AutocompleteLabCore/Session/CompletionActivationPolicy.swift`
- `Sources/AutocompleteLabCore/Session/SensitiveFieldProofHarness.swift`
- `script/check_sensitive_field_proof.sh`

Gap closed this pass:

- `Sources/AutocompleteLabCore/Session/SuggestionSilenceExplanationPolicy.swift`
  now turns internal block reasons into plain tester-facing explanations.
- `Sources/AutocompleteLabApp/App/AppDelegate.swift` uses those explanations
  for activation-policy blocks while keeping trace reasons stable.

## Privacy And Diagnostics

TypeAhead's public proof is mostly docs plus Activity Monitor/firewall guidance.

SteadyType map:

- `Sources/AutocompleteLabApp/Mac/RawAutocompleteTraceLog.swift`
- `Sources/AutocompleteLabApp/Mac/LocalReportExporter.swift`
- `Sources/AutocompleteLabApp/App/PrivacyExportProofCommand.swift`
- `Sources/AutocompleteLabCore/Tracing/AutocompleteTracePrivacyFilter.swift`
- `docs/product/eval-and-tracing.md`
- `script/check_trace_eval.sh`
- `script/check_runtime_network_egress.py`
- `script/check_current_build_privacy_export.sh`

Gap: the diagnostics system is strong, but the in-the-moment reason text needed
to be less internal. This pass improves that path.

## Runtime

TypeAhead uses app-owned local models with `llama.cpp` and GGUF according to
public docs.

SteadyType map:

- `Sources/AutocompleteLabApp/Runtime/AppModelRuntimeFactory.swift`
- `Sources/AutocompleteLabApp/Runtime/MLXModelRuntime.swift`
- `Sources/AutocompleteLabApp/Runtime/LocalModelAssetInstaller.swift`
- `Sources/AutocompleteLabCore/Runtime/RuntimeReadinessGuidance.swift`
- `docs/research/runtime-options.md`

Gap: no change needed for this pass. The app-owned MLX path matches the product
stance better than an Ollama-style server.

## Proof

TypeAhead public docs do not expose a proof manifest. SteadyType already does.

SteadyType map:

- `swift test --jobs 1`
- `./script/check_sensitive_field_proof.sh`
- `./script/check_trace_eval.sh`
- `./script/manual_smoke_status.sh --strict`
- `./script/model_latency_report.py --default-model-proof`
- `./script/beta_readiness.sh`

For this pass, the strongest proof is unit coverage for the new explanation
policy plus full Swift tests.
