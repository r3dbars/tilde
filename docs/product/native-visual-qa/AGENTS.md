# Native Visual QA Folder Guide

This folder holds guides for generating local screenshots used to review native macOS appearance.

- Keep screenshots local and limited to app-owned UI; generated PNGs are ignored.
- Do not include user text, private document content, or other app windows.
- Regenerate Settings screenshots with `AUTOCOMPLETE_LAB_NATIVE_VISUAL_QA_OUTPUT_DIR=docs/product/native-visual-qa swift test --filter SettingsNativeAppearanceSnapshotTests`.
- Regenerate Diagnostics screenshots with `AUTOCOMPLETE_LAB_NATIVE_VISUAL_QA_OUTPUT_DIR=docs/product/native-visual-qa swift test --filter DiagnosticsNativeAppearanceSnapshotTests`.
- Regenerate suggestion overlay screenshots with `AUTOCOMPLETE_LAB_NATIVE_VISUAL_QA_OUTPUT_DIR=docs/product/native-visual-qa swift test --filter SuggestionOverlayNativeAppearanceSnapshotTests`.
