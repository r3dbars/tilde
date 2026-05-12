# Claude Code Guide

Suggestion value types live here.

Start with:

- `CompletionSuggestion.swift`
- `SuggestionAcceptance.swift`
- `CompletionPrefixTrimmer.swift`

Rules:

- Keep suggestions short.
- Preserve leading spaces when needed for natural insertion.
- Keep trimming and acceptance logic Unicode-safe.
- Add tests for whitespace, partial words, and word-boundary behavior.
