# Co-Typist-Style Todo

This is the working list for making the lab feel like a real Mac autocomplete app.

## Now

- [x] Verify insertion after every accept.
  - Detect whether the target text actually changed.
  - Keep the remaining suggestion only when the accepted text landed.
  - Suppress the field after failed accepts.

- [ ] Finish safe compatibility passes.
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
  - Never require Ollama, llama.cpp, or any separate user-started server.

- [ ] Keep inference tiny.
  - Prompt from a small context window.
  - Generate 2-8 visible words.
  - Keep reasoning off.
  - Cancel stale requests when typing continues.

## UX Polish

- [ ] Make the panel calmer.
  - Reduce flicker while typing quickly.
  - Reposition on caret changes without stealing focus.
  - Use floating mirror mode when inline bounds are unstable.

- [ ] Make failure states understandable.
  - [x] Show local model readiness and mock fallback reason.
  - Log only privacy-safe shape data.
  - [x] Explain blocked suggestions by reason in diagnostics.

## QA

- [ ] Build repeatable smoke checks.
  - [x] Add a manual smoke checklist for TextEdit, Notes, Obsidian, and Chrome.
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
