# Claude Code Guide

Live suggestion-session behavior lives here.

Start with:

- `SuggestionSession.swift`
- `SuggestionRequestGate.swift`
- `SuggestionPresentationGate.swift`
- `SuggestionAcceptanceGuard.swift`
- keyboard, insertion, polling, cooldown, suppression, and acceptance-survival policies.

Rules:

- Keep behavior deterministic.
- Do not touch AppKit or Accessibility here.
- Favor small policy types with direct tests.
- When changing annoyance, acceptance, visibility, or fallback behavior, update the matching tests and proof docs.
