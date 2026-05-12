# Claude Code Guide

Native UI controllers live here.

Start with:

- `SuggestionPanelController.swift` for the floating suggestion.
- `SettingsWindowController.swift` for user controls.
- `DiagnosticsWindowController.swift` for local diagnostics.
- `MenuBarIcon.swift` and `ControlSurfaceState.swift` for menu state.

Rules:

- Keep UI quiet, native, and work-focused.
- Do not put product policy in views.
- Do not make settings bigger than the MVP needs.
- Suggestions should feel like inline help, not a tooltip or marketing card.
- Add snapshot or state tests when UI state, labels, or visual policy changes.
