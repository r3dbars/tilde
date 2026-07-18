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
- All tests: `swift test --jobs 1`
- Core (pure) tests: `swift test --jobs 1 --filter AutocompleteLabCoreTests`
- One test: `swift test --jobs 1 --filter AutocompleteLabCoreTests.<Suite>/<test>`
- MLX patch (after `swift package resolve`, before building the app):
  `./script/patch_mlx_swift_lm.sh` — idempotent.
- Pre-merge gate (CI runs exactly this): `./script/proof.sh fast`
- Release gate (macOS, manual): `./script/release_check.sh`

## Architecture

Two layers; the split is load-bearing:

- `Sources/AutocompleteLabCore/` — pure deterministic policy types. Every
  decision about when to request, show, accept, or suppress a suggestion.
- `Sources/AutocompleteLabApp/` — native shell: `Mac/AccessibilityClient` +
  `SerialFocusedTextAXReader` read the focused field; `App/SuggestionOrchestrator`
  drives the request lifecycle over predictor layers (doc-local n-gram, common
  phrase, word ranking, MLX model via the `CompletionEngine` protocol);
  `UI/SuggestionPanelController` renders ghost text; `Mac/KeyboardEventTap` +
  `Mac/InsertionEngine` handle Tab/Shift-Tab/Esc and insertion.

Supporting executables: `AutocompleteTraceReplay` and `SteadyTypeReplayEval`
(offline replay/eval of redacted traces), `SteadyTypeTextEventHelper`.

## Rules

- Privacy first: never log or transmit raw typed text, prompts, model output,
  or screenshots. Redacted-by-default diagnostics only.
- Decisions belong in core with a focused test; the app shell stays thin.
- Prefer merging/deleting policies over adding new gates — independent
  thresholds compound into silence.
- No per-folder guide files; root `AGENTS.md`/`CLAUDE.md` are the only two.
- Dependency patches under `patches/` are temporary and version-pinned;
  re-run runtime tests after changing one.
