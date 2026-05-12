# Claude Code Guide

App-level orchestration lives here.

Start with:

- `main.swift` and `AppDelegate.swift` for process startup.
- `SuggestionOrchestrator.swift` for the live suggestion loop.
- `AppSettings.swift` for persisted local settings.
- `AppProofCommandRunner.swift` and proof command files for local verification surfaces.

Rules:

- Wire services here, but keep core autocomplete decisions in `AutocompleteLabCore`.
- Keep startup simple and fail visibly when permissions or runtime assets are missing.
- Add or update app tests when changing settings, orchestration, proof commands, or acceptance survival behavior.
