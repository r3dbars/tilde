# Claude Code Guide

App-target tests live here.

Use this folder for:

- settings and control-surface state
- app runtime factory and installer behavior
- proof command runners
- menu bar and native UI state
- visual snapshot tests for app-owned UI

Rules:

- Do not launch the full app from tests unless a test is built for that.
- Avoid Accessibility side effects.
- Keep screenshots limited to app-owned UI and disposable fixtures.
- Prefer focused filters such as `swift test --jobs 1 --filter SettingsWindowControllerStateTests`.
