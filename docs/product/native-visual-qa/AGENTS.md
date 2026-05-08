# Native Visual QA Folder Guide

This folder holds generated screenshots used to review native macOS appearance.

- Keep screenshots limited to app-owned UI.
- Do not include user text, private document content, or other app windows.
- Regenerate Settings screenshots with `AUTOCOMPLETE_LAB_NATIVE_VISUAL_QA_OUTPUT_DIR=docs/product/native-visual-qa swift test --filter SettingsNativeAppearanceSnapshotTests`.
- Regenerate Diagnostics screenshots with `AUTOCOMPLETE_LAB_NATIVE_VISUAL_QA_OUTPUT_DIR=docs/product/native-visual-qa swift test --filter DiagnosticsNativeAppearanceSnapshotTests`.
- Regenerate suggestion overlay screenshots with `AUTOCOMPLETE_LAB_NATIVE_VISUAL_QA_OUTPUT_DIR=docs/product/native-visual-qa swift test --filter SuggestionOverlayNativeAppearanceSnapshotTests`.
