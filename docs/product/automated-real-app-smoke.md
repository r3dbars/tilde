# Automated Real App Smoke

This is the repeatable check for whether suggestions show up in the right app box without making typing feel bad.

Run the safe automated passes:

```bash
script/real_app_smoke.sh textedit
script/real_app_smoke.sh chrome
script/real_app_smoke.sh chrome --fixture contenteditable
script/real_app_smoke.sh chrome --fixture editor-like
script/real_app_smoke.sh chrome --fixture monaco-like
script/real_app_smoke.sh chrome --fixture prosemirror-like
```

Run all local Chrome browser/editor fixtures with one build:

```bash
script/real_app_smoke.sh chrome --fixture all
```

Run agent prompt passes only with a manual gate:

```bash
script/real_app_smoke.sh codex --manual-gate
script/real_app_smoke.sh claude-code --manual-gate
```

What this proves:

- the app can build and relaunch
- a real target app can receive normal typing
- a suggestion is shown with the expected render mode
- Tab and the full-accept key are handled only while a suggestion is visible
- insertion is verified in diagnostics and traces
- Chrome works in plain textareas, contenteditable fields, editor-like nested
  contenteditables, Monaco-like editors, and ProseMirror-like editors

The Codex and Claude Code checks are manual-gated because auto-typing into an agent prompt is too risky.

All Chrome fixtures are local and dependency-free. The Monaco-like and
ProseMirror-like fixtures copy the DOM shape and focus behavior those editors
usually expose, but they do not load the real upstream libraries.
