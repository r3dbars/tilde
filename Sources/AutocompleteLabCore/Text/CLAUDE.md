# Claude Code Guide

Text splitting, replacement, and redaction helpers live here.

Start with:

- `CursorTextSplitter.swift`
- `SelectedTextRangeReplacer.swift`
- `DiagnosticValueRedactor.swift`
- `DiagnosticsMetadataRedactor.swift`

Rules:

- Treat Accessibility offsets as UTF-16 offsets when they come from AX.
- Preserve user text exactly.
- Redaction should happen before diagnostics leave the text layer.
- Add tests for emoji, non-ASCII text, selected ranges, and sensitive metadata.
