# Claude Code Guide

The trace replay executable lives here.

Start with `main.swift`.

Rules:

- Use `AutocompleteLabCore` types for parsing, replay, and report behavior.
- Keep app UI, AppKit, Accessibility, and MLX out of this target.
- Assume trace inputs are already redacted and keep outputs local by default.
- Add or update replay tests in `Tests/AutocompleteLabCoreTests` when replay behavior changes.
