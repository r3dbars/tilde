# Autocomplete Lab Agent Guide

This repo is separate from Transcripted on purpose.

## Product stance

- Treat this as an experiment first, not a committed Transcripted feature.
- Keep the app tiny until real people prove it is useful.
- The test is simple: does inline help make writing feel easier, or does it get annoying?
- Privacy is a product requirement. Do not store or send typed text unless the user explicitly turns that on.

## MVP boundary

Start with:

- macOS menu bar app
- Accessibility permission
- active text field / caret detection
- floating suggestion near the cursor
- Tab accepts the next word
- Esc dismisses
- local-first inference
- app allowlist while testing

Avoid early:

- personalization
- broad telemetry
- cloud-only inference
- browser-specific heroics
- Transcripted integration
- true inline ghost text until the floating overlay proves useful

## Technical bias

- Prefer Swift/AppKit for the Mac plumbing.
- Use existing open-source examples as references, but do not copy proprietary Co-Typist code.
- Use public Co-Typist docs and local bundle metadata only as behavior/architecture clues.
- Keep experiments small and easy to throw away.

## Repo structure

- Every source, test, script, or docs folder should have an `AGENTS.md` file that explains what belongs there.
- Keep the model runtime app-owned. Do not require users to start Ollama, llama.cpp, or any other separate server.
- Mock engines are fine for development and tests, but production UX should feel like one Mac app.
- Add tests with each meaningful behavior change.
