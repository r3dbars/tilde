# Claude Code Guide

Trace events, reports, and privacy filters live here.

Start with:

- `AutocompleteTraceEvent.swift`
- `AutocompleteTracePrivacyFilter.swift`
- `AutocompleteTraceAnalyzer.swift`
- `AutocompleteTraceReportGenerator.swift`
- `AutocompleteNonAnnoyanceReport.swift`
- screenshot and proof metadata policy files.

Rules:

- Privacy-filter typed text before it leaves this layer.
- Prefer structured events over string parsing.
- Keep product signals focused on usefulness, interruption, placement confidence, and accepted-then-kept behavior.
- Add tests when trace schema, report summaries, or guardrails change.
