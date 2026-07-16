# Sources Folder Guide

Production Swift code lives here.

- Keep app UI separate from core autocomplete behavior.
- Core code should be testable without AppKit.
- Research, proof harnesses, mocks, and replay behavior belong in `AutocompleteLabResearch` and must not be linked by the app.
- AppKit and Accessibility code belongs in the app target.
