# Co-Typist-Style Todo

This is the working list for making the lab feel like a real Mac autocomplete app.

## Now

- [x] Verify insertion after every accept.
  - Detect whether the target text actually changed.
  - Keep the remaining suggestion only when the accepted text landed.
  - Suppress the field after failed accepts.
  - [x] Try known safe non-clipboard fallback insertion modes before giving up.

- [ ] Finish safe compatibility passes.
  - [x] Encode known primary/fallback paths and a visible debug summary per profile.
  - TextEdit: keep as the green reference app.
  - Notes: title, body line, and checklist/list accepts verified with AX selected text.
  - Obsidian: keep CodeMirror behavior stable across AX element churn.
  - Mail: safe diagnostics pass shows compose body as AXWebArea with empty direct value, no selected range, and no selected-text insertion; profile is diagnostics-only until a safe adapter is verified.
  - Chrome: local textarea passed AX capability checks; live one-word and full accept verified with mirror anchoring and AX value replacement because Chrome's selected-text insert is a no-op.
  - Atlas: keep unsupported until the focused AX element is reliably available.

- [ ] Persist user control.
  - [x] Persist per-app disable across launches.
  - [x] Keep Esc suppression until blur and log the reason.
  - [x] Make the current app state obvious in the menu and diagnostics.

## Local Runtime

- [ ] Replace the mock runtime with a real app-owned local runtime path.
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
  - Never require Ollama, llama.cpp, or any separate user-started server.

- [ ] Keep inference tiny.
  - [x] Prompt from a small current sentence/paragraph context window.
  - [x] Cap retained model text to the visible word window.
  - [x] Generate 2-8 visible words.
  - [x] Keep reasoning off.
  - [x] Cancel stale requests when typing continues.

## UX Polish

- [ ] Make the panel calmer.
  - [x] Reduce flicker while typing quickly.
  - [x] Reposition on caret changes without stealing focus.
  - [x] Use floating mirror mode when inline bounds are unstable.

- [ ] Make failure states understandable.
  - [x] Show local model readiness and mock fallback reason.
  - [x] Log only privacy-safe shape data.
  - [x] Explain blocked suggestions by reason in diagnostics.

## QA

- [ ] Build repeatable smoke checks.
  - [x] Add a manual smoke checklist for TextEdit, Notes, Obsidian, and Chrome.
  - [x] Add a manual smoke recorder that validates per-app diagnostics.
  - [x] Verify launch/runtime/status diagnostics in the smoke script.
  - [x] Wait for Gemma 4 MLX readiness in the smoke script.
  - TextEdit one-word accept and full accept.
  - Notes one-word accept and full accept.
  - Obsidian one-word accept and full accept.
  - Chrome text field one-word and full accept.

- [ ] Keep every meaningful behavior covered by tests.
  - Core routing and activation tests.
  - Runtime state tests.
  - Compatibility profile tests.
  - Privacy/redaction tests.

## Later

- [ ] Package the app properly.
  - App icon.
  - Signing and notarization.
  - Cleaner first-run onboarding.

- [ ] Run a tiny private beta.
  - 3-5 people for one week.
  - Ask whether it helped, interrupted, or broke trust.
