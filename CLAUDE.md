# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with
code in this repository. Read it with `AGENTS.md`, which carries the product
stance and working rules.

SteadyType is an open-source macOS menu bar app for quiet, local inline writing
suggestions near the caret. On-device MLX inference, Apple Silicon, macOS 26,
SwiftPM (`swift-tools 6.2`). The app cannot build on Linux; the pure
`AutocompleteLabCore` tests can run anywhere with a Swift toolchain.

## Commands

- Build and run: `./script/build_and_run.sh` (`--verify` builds/validates
  without launching).
- Input method: `./script/build_ime.sh` builds, signs, notarizes, installs,
  and registers InlineGhostIME (`--no-notarize --no-install` for compile
  checks; notarization is mandatory for the keyboard to appear in System
  Settings).
- All tests: `swift test --jobs 1`
- Core (pure) tests: `swift test --jobs 1 --filter AutocompleteLabCoreTests`
- One test: `swift test --jobs 1 --filter AutocompleteLabCoreTests.<Suite>/<test>`
- Pre-merge gate (CI runs exactly this): `./script/proof.sh fast`
- Release gate (macOS, manual): `./script/release_check.sh`

## Architecture

Three parts; the split is load-bearing:

- `Sources/AutocompleteLabCore/` — pure policy: `CompletionRequest`/engine
  protocol, `RawContinuationPrompt` + `ContinuationRegister` (the prompt recipe
  and per-app voice), `CompletionOutputCleaner` (output discipline: persona/echo
  filters, sentinel handling), `VisiblePageContext`.
- `Sources/AutocompleteLabApp/` — the menu-bar brain (~15 files):
  `GhostBrainServerHost` (unix socket the keyboard talks to),
  `LlamaServerProcessHost` + `LlamaCompletionEngine` (app-managed llama.cpp
  child serving Gemma; llama-only — MLX was removed 2026-07-22, see
  docs/ime-tuning-log.md before considering readding anything),
  `GhostScreenContextBridge` + `VisiblePageContextProvider` (event-driven
  screen OCR context), `GhostKeyboardInstallerHost` (installs the keyboard),
  `StatusMenuHost` (minimal menu), login item, single-instance guard.
- `Sources/InlineGhostIME/` — the input method: renders suggestions inside the
  focused app's own text via IMKit marked text; instant dictionary layer for
  words, brain socket for phrases, Apple FoundationModels only when the app is
  down. Its `README.md` records the non-obvious deployment facts (bundle-id
  rule, mandatory notarization, TIS registration).

## Rules

- Privacy first: never log or transmit raw typed text, prompts, model output,
  or screenshots. Redacted-by-default diagnostics only.
- Decisions belong in core with a focused test; the app shell stays thin.
- Prefer merging/deleting policies over adding new gates — independent
  thresholds compound into silence.
- No per-folder guide files; root `AGENTS.md`/`CLAUDE.md` are the only two.
- Dependency patches under `patches/` are temporary and version-pinned;
  re-run runtime tests after changing one.
