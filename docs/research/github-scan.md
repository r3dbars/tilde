# GitHub Scan

Useful public references found while looking for Co-Typist-like projects.

## Closest Mac Plumbing

### laststance/complete

https://github.com/laststance/complete

Swift menu bar app with:

- global hotkey
- Accessibility text extraction
- caret positioning
- floating completion window
- text insertion

It uses `NSSpellChecker`, not an LLM, but it is the closest architecture reference for the Mac side.

## Warning Example

### pirate/macOS-global-autocomplete

https://github.com/pirate/macOS-global-autocomplete

Old system-wide autocomplete proof of concept. Useful mostly as a warning: the naive version becomes a keylogger quickly.

## Input Method Path

### dongyuwei/hallelujahIM

https://github.com/dongyuwei/hallelujahIM

English input method with suggestions and spell checking. The input-method approach can feel native, but it is a much heavier route than a sidecar menu bar app.

## System-Wide Text Insertion

### espanso/espanso

https://github.com/espanso/espanso

System-wide text expansion. Useful as a reliability reference for app-specific behavior and text insertion.

## AI Writing Adjacent

### fujacob/tabby

https://github.com/fujacob/tabby

AGPL-3.0 licensed local-first Mac autocomplete app. Use as a public architecture
and product reference only; do not copy code. See
[`tabby-reference.md`](tabby-reference.md) for SteadyType-specific notes.

### theJayTea/WritingTools

https://github.com/theJayTea/WritingTools

System-wide AI rewrite/proofread app. Relevant for Accessibility permission flow, selection capture, clipboard preservation, local/cloud provider options, and user expectations.

### SuperCmdLabs/SuperCmd

https://github.com/SuperCmdLabs/SuperCmd

Has an AI cursor prompt and native Swift helpers for caret/selection work. Broader Electron app, but useful for implementation clues.

### TypeWhisper/typewhisper-mac

https://github.com/TypeWhisper/typewhisper-mac

Dictation app with system-wide insertion, hotkeys, local models, prompt processing, and per-app rules. Useful reference even though it is speech-first.

### watzon/pindrop

https://github.com/watzon/pindrop

Native Mac dictation app. Useful for menu bar app structure, global hotkeys, local-first positioning, and direct insertion patterns.

## Installed Co-Typist Observations

Local inspection of the installed app showed:

- app bundle: `/Applications/Cotypist.app`
- bundle id: `app.cotypist.Cotypist`
- version: `0.21.1`
- menu bar app via `LSUIElement`
- signed/notarized Developer ID app
- uses Sparkle for updates
- links `libllama`, `ggml`, and `ggml-metal`
- links AppKit, ApplicationServices, ScreenCaptureKit, Vision, Carbon, GRDB, Sentry
- local model file under Application Support: `gemma-4-E4B-UD-Q5_K_XL.gguf`

Inferred architecture:

Accessibility reads the active field and caret, local llama/ggml predicts, a floating or inline UI shows the suggestion, and hotkeys accept or dismiss.
