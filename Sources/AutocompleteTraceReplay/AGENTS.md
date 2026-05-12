# AutocompleteTraceReplay Guide

This executable replays trace files through the pure core replay logic.

- Keep it as a thin CLI wrapper.
- Do not add AppKit, Accessibility, or live app state here.
- Keep output privacy-safe by default; prefer summaries over raw trace text.
- Add focused core tests for behavior changes rather than growing CLI logic.
