# Claude Code Guide

Native UI visual QA screenshots are generated here for local review.

Rules:

- Keep generated screenshots local; PNG outputs are ignored.
- Do not include user text, private documents, or other app windows.
- Regenerate with `AUTOCOMPLETE_LAB_NATIVE_VISUAL_QA_OUTPUT_DIR=docs/product/native-visual-qa swift test --filter SettingsNativeAppearanceSnapshotTests` or the matching diagnostics/overlay snapshot filter.
- Review generated images locally.
