# Automated Real App Smoke

This is the repeatable check for whether suggestions show up in the right app box without making typing feel bad.

Run the safe automated passes with screenshot tracing:

```bash
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh textedit
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh chrome
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh chrome --fixture contenteditable
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh chrome --fixture editor-like
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh chrome --fixture monaco-like
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh chrome --fixture prosemirror-like
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh chrome --fixture chat-like
```

Run all local Chrome browser/editor fixtures with one build:

```bash
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh chrome --fixture all
```

Run private-content and agent-prompt passes only with a manual gate:

```bash
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-title --manual-gate
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-body --manual-gate
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-checklist --manual-gate
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh obsidian --manual-gate
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh codex --manual-gate
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh claude --manual-gate
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh claude-code --manual-gate
```

What this proves:

- the app can build and relaunch
- a real target app can receive normal typing
- a suggestion is shown with the expected render mode
- Tab and, where the profile allows it, the full-accept key are handled only
  while a suggestion is visible
- insertion is verified in diagnostics and traces
- strict screenshot trace evidence can be required with `--visual` through the
  manual recorder or by setting `AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1`
- Chrome works in plain textareas, contenteditable fields, editor-like nested
  contenteditables, Monaco-like editors, ProseMirror-like editors, and a
  chat-style composer fixture that fails if Tab/full-accept submits the form

Notes, Obsidian, Codex, Claude desktop, and Claude Code checks are manual-gated.
Do not use real notes, vault content, or live prompts for proof. Use disposable
smoke text only, and never press Enter in an agent prompt pass. Codex, Claude
desktop, and Claude Code require one-word no-submit proof before graduation.
Prompt-app full accept stays disabled until separate full-accept no-submit proof
exists.
For Notes, `notes-title`, `notes-body`, and `notes-checklist` are separate
proof targets. A generic `notes` run is only a picker and does not count.

All Chrome fixtures are local and dependency-free. The Monaco-like and
ProseMirror-like fixtures copy the DOM shape and focus behavior those editors
usually expose, but they do not load the real upstream libraries. The chat-like
fixture is not a real Codex or Claude proof; it is a local no-submit guardrail
that must pass before trusting prompt app smoke results.
