# Trace Replay CLI Guide

This target is a small executable for replaying redacted traces through core logic.

- Depend only on `AutocompleteLabCore`.
- Keep it CLI-only.
- Do not read raw private text, screenshots, browser history, or clipboard contents.
- Keep output suitable for local proof reports.
- Update `Package.swift` excludes when adding guide files here.
