# Automated Real App Smoke

This is the repeatable check for whether suggestions show up in the right app box without making typing feel bad.

Run the safe automated passes:

```bash
script/real_app_smoke.sh textedit
script/real_app_smoke.sh chrome
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

The Codex and Claude Code checks are manual-gated because auto-typing into an agent prompt is too risky.
