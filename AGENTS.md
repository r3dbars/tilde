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

- Keep an `AGENTS.md` + `CLAUDE.md` pair only when a folder has rules that differ from its nearest ownership guide; folders with no additional boundary inherit that guide.
- When adding guide files inside a SwiftPM target folder, update `Package.swift` excludes so the package still loads cleanly.
- Keep the model runtime app-owned. Do not require users to start Ollama, llama.cpp, or any other separate server.
- Mock engines are fine for development and tests, but production UX should feel like one Mac app.
- Add tests with each meaningful behavior change.

## Keeping main green

- Before opening a PR or pushing, run the fast proof gate: `./script/proof.sh fast`
  (the cheap proof tier, target < ~10 min). It is the single entry point CI runs on
  every PR to `main` (`.github/workflows/fast-proof.yml`); wire it to run on push
  with `git config core.hookspath .githooks`.
- The gate is tiered. Blocking checks (coverage manifest, `script/*.py` byte-compile,
  harness self-tests, whitespace, core `swift test`) fail the build. Proof-status
  checks that still need a pending *manual* proof (e.g. `check_proof_manifest.sh`)
  run report-only. Keep proof gates honest: pending proof stays pending — do not
  flip a report lane to blocking until its manual proof actually lands.
- The broad pre-beta gate stays `./script/beta_readiness.sh`.
