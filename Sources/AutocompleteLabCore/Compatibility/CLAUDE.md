# Claude Code Guide

Compatibility routing lives here.

Start with:

- `AppCompatibilityProfile.swift`
- `CompatibilityRouter.swift`
- `InlineGhostPlacementResolver.swift`
- `InlineGhostPlacementDecision.swift`

Rules:

- Keep this layer pure Swift.
- Model weird app/editor behavior as explicit profiles or decisions.
- Do not store or log raw typed text.
- New app support needs tests and proof docs before broad claims change.
