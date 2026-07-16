# Claude Code Guide

This target builds the menu bar app.

Start map:

- `App/`: app startup, orchestration, settings, and suggestion lifecycle wiring.
- `Mac/`: Accessibility, keyboard capture, insertion, redaction, local reports, and trace storage.
- `Runtime/`: MLX-backed runtime and app-owned model asset installation.
- `UI/`: menu bar, settings, diagnostics, overlay, and suggestion panel controllers.

Rules:

- Keep product behavior policies in `AutocompleteLabCore` when they can be pure Swift.
- Keep native effects small and wrapped.
- Do not let production UX depend on user-started model servers.
- App code may collect diagnostics only through redacted, opt-in paths.
