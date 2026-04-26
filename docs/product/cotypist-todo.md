# Co-Typist-Style Todo

This is the working list for making the lab feel like a real Mac autocomplete app.

## Now

- [x] Verify insertion after every accept.
  - Detect whether the target text actually changed.
  - Keep the remaining suggestion only when the accepted text landed.
  - Suppress the field after failed accepts.
  - [x] Try known safe non-clipboard fallback insertion modes before giving up.

- [x] Finish safe compatibility passes.
  - [x] Encode known primary/fallback paths and a visible debug summary per profile.
  - TextEdit: keep as the green reference app.
  - Notes: title/body/list fields use key-event insertion because AX selected-text insertion can report success without moving the caret.
  - Obsidian: keep CodeMirror behavior stable across AX element churn; do not suppress the whole field after one flaky key-event verification miss.
  - Mail: safe diagnostics pass shows compose body as AXWebArea with empty direct value, no selected range, and no selected-text insertion; profile is diagnostics-only until a safe adapter is verified.
  - Chrome: local textarea passed AX capability checks; live one-word and full accept verified with mirror anchoring and AX value replacement because Chrome's selected-text insert is a no-op.
  - Atlas: keep unsupported until the focused AX element is reliably available.
  - [x] Capture the current app stance in `docs/product/compatibility-matrix.md`.

- [x] Persist user control.
  - [x] Persist per-app disable across launches.
  - [x] Keep Esc suppression until blur and log the reason.
  - [x] Make the current app state obvious in the menu and diagnostics.
  - [x] Cancel pending suggestions immediately when the current app is disabled.

## Local Runtime

- [x] Replace the mock runtime with a real app-owned local runtime path.
  - Keep `ModelRuntime` as the boundary.
  - Prefer MLX first for practical Apple Silicon integration.
  - Keep LiteRT-LM as a tracked fallback.
  - [x] Validate the MLX/Hugging Face model directory shape before exposing it to the user.
  - [x] Show and reveal the expected MLX model folder from the menu and diagnostics.
  - [x] Add download/warm/ready/failed states before exposing it to the user.
  - [x] Suppress suggestions until the local runtime is ready.
  - [x] Link `mlx-swift-lm` and add the first real `MLXModelRuntime`.
  - [x] Add a local MLX download helper.
  - [x] Package MLX Metal kernels into the standalone app bundle.
  - [x] Switch the playable default to Qwen3 0.6B after Gemma 4 E2B failed current `mlx-swift-lm` weight loading.
  - [x] Upgrade the playable default to Qwen3 1.7B for better autocomplete quality.
  - [x] Upgrade the playable default to Gemma 4 26B A4B through the MLX VLM loader.
  - [x] Switch the live autocomplete default to Qwen3.5 9B 4-bit for a faster quality/latency tradeoff.
  - [x] Add a Qwen3.5 4B 4-bit live-model trial for lower-latency phrase completion.
  - [x] Prove production readiness only when the app is using the native preferred runtime, not mock fallback.
  - [x] Never require Ollama, llama.cpp, or any separate user-started server.

- [x] Keep inference tiny.
  - [x] Prompt from a small current sentence/paragraph context window.
  - [x] Cap retained model text to the visible word window.
  - [x] Generate 2-8 visible words.
  - [x] Suppress one-word twitch completions before they reach the UI.
  - [x] Keep reasoning off.
  - [x] Cancel stale requests when typing continues.

## UX Polish

- [x] Make the panel calmer.
  - [x] Reduce flicker while typing quickly.
  - [x] Reposition on caret changes without stealing focus.
  - [x] Use floating mirror mode when inline bounds are unstable.
  - [x] Keep panel frames valid on narrow or cramped screens.

- [x] Make failure states understandable.
  - [x] Show local model readiness and mock fallback reason.
  - [x] Log only privacy-safe shape data.
  - [x] Explain blocked suggestions by reason in diagnostics.
  - [x] Suppress repeated blocked-suggestion diagnostics for the same field state.

## QA

- [x] Build repeatable smoke checks.
  - [x] Add a manual smoke checklist for TextEdit, Notes, Obsidian, and Chrome.
  - [x] Add a manual smoke recorder that validates per-app diagnostics.
  - [x] Record successful manual app passes in an append-only smoke-run ledger.
  - [x] Add a self-test for the manual smoke recorder across target app profiles.
  - [x] Add a status command and proof gate for missing manual app passes.
  - [x] Verify launch/runtime/status diagnostics in the smoke script.
  - [x] Wait for Gemma 4 MLX readiness in the smoke script.
  - [x] Gate smoke on trace eval self-test coverage.
  - App-specific checks below should only be marked done after `docs/product/manual-smoke-runs.md` has a matching pass.
  - [x] TextEdit one-word accept and full accept.
  - [x] Notes one-word accept and full accept.
  - [x] Obsidian one-word accept and full accept.
  - [x] Chrome text field one-word and full accept.

- [x] Build the local eval loop.
  - [x] Add local prompt/output tracing for private local tuning.
  - [x] Trace accepted Tab and full-visible completions when raw tracing is enabled.
  - [x] Document the local eval metrics to track.
  - [x] Aggregate accept / ignore / reject rates by app and request mode.
  - [x] Add a small trace summarizer.
  - [x] Add a local model latency report for comparing MLX model trials.
  - [x] Add a trace eval checker with app-specific proof gates.
  - [x] Run the trace eval checker self-test from the main smoke script.

- [x] Keep every meaningful behavior covered by tests.
  - [x] Core routing and activation tests.
  - [x] Runtime state tests.
  - [x] Compatibility profile tests.
  - [x] Privacy/redaction tests.
  - [x] Smoke fails if the core test coverage manifest regresses.

## Later

- [ ] Package the app properly.
  - [x] App icon.
  - [x] Validate bundle structure, menu-bar plist, packaged MLX metallib, and signature in smoke.
  - [x] Sign debug bundles with hardened runtime.
  - [x] Add a release packaging and notarization-readiness script.
  - [x] Gate smoke on release packaging prerequisite checks.
  - Signing and notarization submission.
  - [x] Add a direct Accessibility settings link for first-run setup.
  - [x] Cleaner first-run onboarding.

- [ ] Run a tiny private beta.
  - [x] Add one local beta-readiness gate that runs smoke, app proof, and release archive packaging.
  - [x] Add a local private-beta packet with install steps, checksum, and feedback log.
  - 3-5 people for one week.
  - Ask whether it helped, interrupted, or broke trust.
