# Claude Code Guide

Native UI visual QA screenshots live here.

Rules:

- Commit only app-owned UI screenshots.
- Do not include user text, private documents, or other app windows.
- Regenerate with `AUTOCOMPLETE_LAB_NATIVE_VISUAL_QA_OUTPUT_DIR=docs/product/native-visual-qa swift test --filter SettingsNativeAppearanceSnapshotTests` or the matching diagnostics/overlay snapshot filter.
- Review generated images before committing.
