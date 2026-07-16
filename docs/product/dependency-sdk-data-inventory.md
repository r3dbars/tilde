# Dependency And SDK Data Inventory

Last checked: 2026-07-16.

This inventory is built from `Package.swift`, the current app bundle,
`Info.plist` permissions, and repo scripts.

## Summary

- No analytics SDK.
- No crash reporting SDK.
- No remote telemetry SDK.
- No bundled third-party `.framework` or `.dylib` is expected in the app bundle.
- Model install can contact Hugging Face only when the user starts install or
  repair. Normal autocomplete should run locally after the model is present.
- Default diagnostics should not include typed text, prompts, model output,
  accepted text, screenshots, URLs, document titles, recipients, or subjects.

## Swift Packages

| Dependency | Why it exists | Data it can touch | Leaves the Mac by default |
| --- | --- | --- | --- |
| `mlx-swift-lm` from `https://github.com/ml-explore/mlx-swift-lm.git` | Local MLX model loading and inference. | Local model files, prompts inside process memory, generated tokens inside process memory. | No. |
| `swift-huggingface` from `https://github.com/huggingface/swift-huggingface.git` | User-triggered model snapshot download and install. | Model repository metadata and model files. | Yes, only for model install or repair. Typed text is not needed for this path. |
| `swift-transformers` from `https://github.com/huggingface/swift-transformers.git` | Tokenizer and Hub support used by the local model runtime. | Local tokenizer/model files. | No during normal autocomplete. |

## Built App Bundle

`script/check_dependency_inventory.sh` inspects the current
`dist/SteadyType.app` bundle.

Expected bundle contents:

- `Contents/MacOS/SteadyType`
- `Contents/MacOS/SteadyTypeTextEventHelper`
- `Contents/Resources/AppIcon.icns`
- `Contents/Resources/mlx-swift_Cmlx.bundle/default.metallib`
- `Contents/Info.plist` and signing metadata
- system-linked Apple and Swift libraries from the executable

Expected absent bundle contents:

- analytics SDK frameworks
- crash reporting SDK frameworks
- remote telemetry SDK frameworks
- local model weights

`script/check_lightweight_budget.py` enforces the exact shipped payload and
release size ceiling documented in `lightweight-budget.md`.

## App Permissions

`Info.plist` should contain:

- `NSAccessibilityUsageDescription`: needed to inspect the focused text field,
  caret bounds, and insert only accepted suggestions.
- `NSAppleEventsUsageDescription`: needed only for opted-in terminal host
  adapters that use macOS Automation to insert accepted suggestion text into a
  supported prompt without submitting it.

The app signature should include:

- `com.apple.security.automation.apple-events`: required by hardened runtime
  for the same opted-in terminal host Automation path.

`Info.plist` should not contain:

- camera permission
- microphone permission
- screen recording permission
- location permission
- contacts permission
- calendar permission

## Script And Network Inventory

| Path | Network use | Privacy note |
| --- | --- | --- |
| `script/build_and_run.sh` | SwiftPM package resolution can fetch package code during development builds. | Build-time only. Not a beta runtime telemetry path. |
| `script/download_mlx_model.py` | Downloads selected model snapshots from Hugging Face. | User-triggered model setup. Does not need typed text. |
| `Sources/AutocompleteLabApp/Runtime/LocalModelAssetInstaller.swift` | Downloads the app-owned local model. | User-triggered install or repair. |
| `Sources/AutocompleteLabApp/Runtime/ModelAssetInstaller.swift` | Downloads model snapshots through Hub support. | User-triggered install or repair. |
| `script/local_completion_runtime.py` | Can run local runtime experiments against configured model paths. | Developer tool. Not required for testers. |
| `script/real_app_smoke.sh` | Can open browser fixtures and local test pages. | Manual proof tool. Not default app behavior. |
| `script/check_runtime_network_egress.py` | Observes process network connections. | Proof tool. Does not send app data. |

## Check

Run:

```bash
./script/check_dependency_inventory.sh
```

The check rebuilds the app bundle if needed, verifies package pins, checks app
permissions, records linked libraries under ignored diagnostics output, and
fails if analytics or crash SDK references appear.
