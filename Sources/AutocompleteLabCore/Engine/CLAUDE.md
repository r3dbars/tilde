# Claude Code Guide

Completion engine logic lives here.

Start with:

- `CompletionEngine.swift` for the protocol.
- `CompletionPromptBuilder.swift` for prompt shape.
- `RuntimeBackedCompletionEngine.swift` for runtime integration.
- `CompletionOutputCleaner.swift` and rankers for final suggestion quality.

Rules:

- Return short continuations, not explanations.
- Keep mock engines deterministic.
- Keep prompt builders privacy-aware and context-minimal.
- Add tests for prompt shape, cleanup, ranking, and partial-word behavior.
