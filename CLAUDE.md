# Claude Code Guide

Read this with `AGENTS.md`. This repo is a standalone macOS autocomplete lab, not the main Transcripted app.

Start map:

- `Sources/AutocompleteLabCore/`: pure Swift autocomplete policy, text, geometry, tracing, compatibility, and runtime value types.
- `Sources/AutocompleteLabApp/`: AppKit, Accessibility, keyboard capture, native UI, MLX runtime wiring, and app orchestration.
- `Sources/AutocompleteTraceReplay/`: small CLI for replaying redacted traces through core logic.
- `Tests/`: Swift tests split by app and core target.
- `script/`: local build, smoke, beta-readiness, privacy, proof, and report checks.
- `docs/product/proof-manifest.json`: current proof truth for app support claims.

Rules:

- Preserve privacy first: no raw typed text, prompts, screenshots, URLs, or document names unless the user explicitly opts in.
- Keep the model runtime app-owned. Do not require Ollama, llama.cpp, or a separate server for product UX.
- Keep broad support claims strict. If a proof gate is missing, say it is missing.
- When adding a folder, add both `AGENTS.md` and `CLAUDE.md`.
- When adding guide files under SwiftPM target folders, update `Package.swift` excludes.

Useful validation:

- Docs or package-shape changes: `swift package describe`.
- Core behavior: `swift test --jobs 1 --filter AutocompleteLabCoreTests`.
- App behavior: `swift test --jobs 1 --filter AutocompleteLabAppTests`.
- Beta/proof work: `./script/beta_readiness.sh` plus the specific `check_*` script for the changed proof surface.
