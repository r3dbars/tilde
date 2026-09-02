# Changelog

All notable changes to Tilde. Versions follow the app's
`CFBundleShortVersionString`; the build number is the commit count at packaging.

## Unreleased

### Added
- Screen Memory master toggle in Privacy & Data; turning it off drops every held
  screen snapshot and the menu names the state instead of calling it a pause.
- One-click "Ignore <App>" in the menu bar.
- Your Tilde leads with keystrokes saved, kept-after-30-seconds, helpful
  streaks, and how often Tilde held back and why.
- A text-free outcome ledger that records every shown ghost and every silent
  model opportunity with a terminal reason and a configuration fingerprint.
- Mid-word model continuation, chained accept, punctuation-boundary requests,
  and the shorter Electron reveal floor, all gated to the 9B preview profile.
- The trained personal model persists across restarts.

### Changed
- Streaming ghosts survive turning on Personal suggestions.
- The sensitive-scene guard covers documents beside the composer.
- The cleaner, echo, and grounding checks prepare their context once per request.
- License: MIT (unchanged); a trademark notice covers the name and logo.

### Fixed
- Register, candidate source, and per-thousand-character denominators in the
  outcome ledger.
- A restore path that would have discarded pre-upgrade personal history.
- A newer keyboard failing every response from an older app.

## 0.1.0 — unreleased beta

First public beta. See README.md for status and requirements.
