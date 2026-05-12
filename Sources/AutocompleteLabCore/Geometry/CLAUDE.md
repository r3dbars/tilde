# Claude Code Guide

Geometry and placement policy live here.

Start with:

- `CaretRectResolver.swift`
- `SuggestionPanelFrameCalculator.swift`
- `AccessibilityCoordinateConverter.swift`
- `ScreenshotPlacementOffsetDetector.swift`
- `VisualPlacementCorrectionPolicy.swift`

Rules:

- Accessibility bounds often use top-left screen origin.
- AppKit windows use bottom-left screen origin.
- Keep conversion logic pure and tested.
- Placement proof should use redacted or disposable screenshots only.
