# Claude Code Guide

Swift package sources live here.

Target map:

- `AutocompleteLabCore/`: pure behavior and value types. No AppKit or Accessibility.
- `AutocompleteLabApp/`: executable app shell, native Mac plumbing, UI, and real runtime bindings.
- `AutocompleteTraceReplay/`: CLI executable for redacted trace replay.

Rules:

- Keep core code testable without launching the app.
- Keep AppKit, Accessibility, event taps, screenshots, and MLX bindings out of core.
- If you add guide files inside a target folder, also update `Package.swift` excludes.
- Prefer adding focused tests in `Tests/` with each behavior change.
