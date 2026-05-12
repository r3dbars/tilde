# Claude Code Guide

Native Mac plumbing lives here.

Start with:

- `AccessibilityClient.swift` for focused field and caret reads.
- `KeyboardEventTap.swift` for key capture.
- `InsertionEngine.swift` for accepted text insertion.
- `RedactionLayer.swift`, trace files, and report exporters for privacy-preserving diagnostics.

Rules:

- Suppress secure and sensitive fields.
- Swallow keys only while a suggestion is visible and eligible.
- Keep Accessibility wrappers small and test the pure parts.
- Do not log raw text, clipboard contents, browser history, keystroke streams, or document content.
