# Claude Code Guide

App-level orchestration lives here.

Start with:

- `main.swift` and `AppDelegate.swift` for process startup.
- `SuggestionPipelineController.swift` for the focused-text polling driver (first slice carved out of `AppDelegate`; see its file footer for the decomposition follow-ups).
- `SuggestionOrchestrator.swift` for the live suggestion loop.
- `AppSettings.swift` for persisted local settings.
- `PrivacyExportProofCommand.swift` and `ProofOnlyAcceptCommand.swift` for local verification surfaces.

Rules:

- Wire services here, but keep core autocomplete decisions in `AutocompleteLabCore`.
- Keep startup simple and fail visibly when permissions or runtime assets are missing.
- Add or update app tests when changing settings, orchestration, proof commands, or acceptance survival behavior.
