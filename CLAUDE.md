# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Read this with `AGENTS.md`. This repo is **SteadyType**, a standalone macOS autocomplete lab — a menu bar app that shows quiet inline writing suggestions near the caret. It is intentionally separate from the main Transcripted app and treated as a throwaway-friendly experiment, not a committed product feature.

Per-folder `AGENTS.md` + `CLAUDE.md` pairs exist throughout the tree and carry local rules; read the one for the folder you are editing.

## Commands

This is a macOS-only SwiftPM package (`swift-tools 6.2`, targets macOS 26, Apple Silicon for the real runtime). The app cannot be built or run on Linux; only the pure `AutocompleteLabCore` tests are platform-light.

The public command facade has exactly five operations:

- Build the app bundle without launching: `./script/steadytype build`
- Run the fast pre-merge test gate: `./script/steadytype test`
- Run the broad local smoke suite: `./script/steadytype smoke`
- Run the checked-in quality eval suite: `./script/steadytype eval`
- Check or build release artifacts: `./script/steadytype release --check` (a bare `release` builds the archive; `release --notarize` uploads it to Apple)

Use the focused internals below only when narrowing a failure or maintaining the facade:

- All Swift tests: `swift test --jobs 1`
- Core (pure) tests: `swift test --jobs 1 --filter AutocompleteLabCoreTests`
- App tests: `swift test --jobs 1 --filter AutocompleteLabAppTests`
- A single test: `swift test --jobs 1 --filter AutocompleteLabCoreTests.<SuiteName>/<testName>`
- Package shape after docs/target changes: `swift package describe`
- MLX patch (run after `swift package resolve`, before building the app): `./script/patch_mlx_swift_lm.sh` — applies `patches/mlx-swift-lm/gemma4-optiq-scaled-linear.patch` to the resolved checkout. It is idempotent and no-ops if already applied.
- Fast gate implementation: `./script/proof.sh fast`; `./script/steadytype test` delegates here. It runs whitespace/conflict checks, Python byte-compilation, harness self-tests, the coverage manifest, core Swift tests, and a non-blocking proof-manifest report.
- Broad internal pre-beta gate: `./script/beta_readiness.sh`, plus the specific `script/check_*.sh` for the proof surface you changed.

The fast gate is **tiered**: blocking checks fail the build; proof-status checks that still need a pending *manual* proof (e.g. `check_proof_manifest.sh`) run report-only. Keep proof gates honest — don't promote a report lane to blocking until its manual proof actually lands.

Most scripts have a paired `*_self_test.sh` that validates the script itself (`steadytype` has `steadytype_self_test.sh`; `proof.sh` has `proof_self_test.sh`).

## Architecture

The system is split into two layers, and the split is load-bearing — keep it.

- **`Sources/AutocompleteLabCore/`** — pure, deterministic Swift. No AppKit, Accessibility, MLX, file dialogs, screenshots, or process management. All autocomplete *decisions* live here as small, individually testable policy types.
- **`Sources/AutocompleteLabApp/`** — the executable menu bar app: native Mac plumbing (Accessibility, event taps, insertion), UI controllers, and the real MLX model runtime. It wires core policies to native effects; it should hold as little decision logic as possible.

### The live suggestion loop

1. `App/main.swift` + `App/AppDelegate.swift` start the menu bar process and request Accessibility permission.
2. `Mac/AccessibilityClient.swift` + `Mac/SerialFocusedTextAXReader.swift` read the focused text field (text before/after caret, role, geometry) on a polling cadence governed by core `Session/FocusedText*Policy` types.
3. `App/SuggestionOrchestrator.swift` (the `@MainActor` heart of the app) builds a `CompletionRequest` and drives the request lifecycle, layering several predictors: doc-local n-gram, common-phrase, word-completion ranking, and the model engine.
4. The model path goes through the core `CompletionEngine` protocol (`Engine/CompletionEngine.swift`). Implementations: `RuntimeBackedCompletionEngine` (wraps a model runtime), `LocalCompletionEngine`, and `MockCompletionEngine` for deterministic dev/tests. The real runtime is `Runtime/MLXModelRuntime.swift` (app-owned, app-installed model asset) behind `Runtime/AppModelRuntimeFactory.swift`.
5. Whether a suggestion is *shown* is decided by a stack of pure `Session/` gates and suppressors — `SuggestionRequestGate`, `SuggestionPresentationGate`, `SuggestionAcceptanceGuard`, annoyance/repetition/cooldown/uncertainty policies, etc. This "quiet unless invited" gating is the product's core behavior.
6. `UI/SuggestionPanelController.swift` renders the floating overlay near the caret (geometry resolved by core `Geometry/` policies). `Mac/KeyboardEventTap.swift` + core `Session/KeyboardCapture*`/`KeyboardAction` translate `Tab` (accept next word), `Shift-Tab` (accept full visible), and `Esc` (dismiss). Accepted text is inserted by `Mac/InsertionEngine.swift`, then verified by `Session/InsertionVerification*` policies.

### Cross-cutting subsystems

- **Compatibility** (`Core/Compatibility/`, `Core/Configuration/`): per-app `CompatibilityProfile` + `CompatibilityRouter` choose the insertion mode and acceptance capabilities per target app. Prompt/terminal apps stay one-word and fail-closed; sensitive/secure fields are hard-blocked (`Session/SensitiveTextFieldPolicy`, `AcceptedTextSafetyPolicy`).
- **Tracing & privacy** (`Core/Tracing/`, `Core/Text/`, `Mac/Redaction*`, `Mac/*TraceLog`): all diagnostics are local and redacted by default. Raw or screenshot traces are short-lived and strictly opt-in. `Sources/AutocompleteTraceReplay/` is a CLI that replays redacted traces back through core logic.
- **Proof system**: support claims are policy + proof, not optimism. `docs/product/proof-manifest.json` is the current truth for what the app supports; `script/check_*` scripts verify each proof surface and `beta_readiness.sh` aggregates them.

## Conventions and rules

- **Privacy is a product requirement.** Never store or transmit raw typed text, prompts, model output, accepted text, screenshots, document names, URLs, or recipients unless the user has explicitly opted in. Don't print these in scripts or logs.
- **Keep decisions in core.** If behavior can be expressed as pure Swift, it belongs in `AutocompleteLabCore` with a focused test, not in the app shell. Favor small policy types over large stateful objects.
- **Keep the model runtime app-owned.** Production UX must not require users to start Ollama, llama.cpp, Python, or any separate server. Mock engines are fine for dev/tests only.
- **Keep support claims strict.** If a proof gate is missing, say it is missing. Don't broaden compatibility claims ahead of proof.
- **Add tests with each meaningful behavior change**, and update the matching proof docs when you change annoyance, acceptance, visibility, insertion, or fallback behavior.
- **Every tracked folder gets an `AGENTS.md` and a `CLAUDE.md`.** When adding guide files inside a SwiftPM target folder, also add the path to that target's `exclude:` list in `Package.swift` so the package still loads.
- **Dependency patches** under `patches/` are temporary and version-pinned; prefer fixing app code over patching upstream, and re-run runtime tests after changing a patch.
