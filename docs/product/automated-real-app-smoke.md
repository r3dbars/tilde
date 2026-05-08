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
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh chrome --fixture monaco-real
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh chrome --fixture prosemirror-real
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh chrome --fixture chat-like
```

Automated smoke launches temporarily enable only the target bundle ID for that
proof pass. This keeps fresh installs default-off while still letting the
disposable TextEdit and Chrome checks run unattended.

The Settings app-proof button can run the safe unattended lanes for TextEdit
and Chrome. Chrome runs the full local fixture set with `--fixture all` and
`--skip-build`; prompt apps and private-content apps stay manual-gated.

Run all local Chrome browser/editor fixtures with one build:

```bash
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh chrome --fixture all
```

Run private-content and agent-prompt passes only with a manual gate:

```bash
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-title --manual-gate
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-body --manual-gate
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-checklist --manual-gate
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-title-undo --manual-gate
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-body-undo --manual-gate
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-checklist-undo --manual-gate
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh obsidian --manual-gate
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh codex --manual-gate
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh claude-code --manual-gate
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh claude --manual-gate
```

Claude Code uses a proof-only terminal-host lane. The direct
`com.anthropic.claude-code` bundle is a background-only CLI helper, but a
supported terminal host can be used when explicit proof mode and the disposable
marker are active.

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
  contenteditables, Monaco-like editors, ProseMirror-like editors, pinned
  upstream Monaco/ProseMirror fixtures, and a chat-style composer fixture that
  fails if Tab/full-accept submits the form. Local Chrome fixtures run in an
  isolated temp-profile Chrome with renderer accessibility forced by default.

Notes, Obsidian, Codex, Claude Code, and Claude desktop checks are
manual-gated. Do not use real notes, vault content, terminal commands, or live
prompts for proof. Use disposable smoke text only, and never press Enter in an
agent prompt pass. Codex, Claude Code, and Claude desktop require one-word
no-submit proof before graduation.
Prompt-app full accept stays disabled until separate full-accept no-submit proof
exists.
For Notes, `notes-title`, `notes-body`, `notes-checklist`, and the matching
`notes-*-undo` lanes are separate proof targets. A generic `notes` run is only
a picker and does not count. Undo lanes require `accepted-insertion-undone` in
the bounded diagnostics slice.

The default Chrome fixtures are local and dependency-free. They run in an
isolated temp-profile Chrome process with `--force-renderer-accessibility` so
the unattended proof lane is not blocked by normal Chrome's current AX exposure.
The Monaco-like and
ProseMirror-like fixtures copy the DOM shape and focus behavior those editors
usually expose, but they do not load the real upstream libraries. The
`monaco-real` and `prosemirror-real` fixtures install pinned npm packages into a
temporary folder during the run and never commit `node_modules`. They are the
right proof lane for real editor engines. The script kills only the captured
isolated Chrome process during cleanup. That proves Autocomplete Lab works when
Chrome exposes real editor AX, but it is still weaker than default-Chrome
production-site proof. The Settings Chrome proof runner now calls
`--fixture all --include-default-real-editor-proof`, so the same one-click proof
also reruns real Monaco and real ProseMirror under normal Chrome AX exposure.
The `--chrome-accessibility default` lane records distinct `*-default` proof
rows when normal Chrome exposes enough editor AX for strict screenshot-backed
acceptance and proof-gated inline synthetic-caret placement. The remaining
Chrome editor gap is production editor variants. The chat-like fixture is not a
real Codex or Claude
proof; it is a local no-submit guardrail that must pass before trusting prompt
app smoke results.

The script also has guarded public-demo lanes for `codemirror-official`,
`monaco-official`, and `prosemirror-official`. Those lanes are for production
editor proof only after they pass with bounded screenshot-backed traces. They
fail closed before typing unless Chrome is frontmost and the expected official
demo URL is the active tab. Official demo lanes also fail fast if Chrome's
View > Developer > Allow JavaScript from Apple Events setting is off, because
the script cannot safely focus or verify those public editors without it. The
Chrome setup text path also requires a focused editable web text target through
Accessibility, sends setup text to the Chrome process rather than as global
setup keystrokes, and verifies that the focused editor value changed before
continuing. Real-app smoke runs take a single-run lock and scan for other
active smoke scripts so two proof processes cannot type at the same time, even
if an older worktree process did not share the current lock state.

Run the score target loop when working toward the product scorecards:

```bash
./script/check_score_targets.sh
./script/scorecard_goal_loop.sh --iterations 10
```

The loop should keep failing until the deep dive scorecard is all 10/10, the
Apple-native checklist is all 100/100, the app proof matrix is all A, and the
strict proof manifest has bounded current-fingerprint trace slices for every
claimed surface.

Prompt-app proof is intentionally stricter than normal app proof. The recorder
requires exactly one trace-level accept for Codex and Claude desktop, rejects
full-accept or field-send finalization signals, and still depends on the human
visual check that the prompt stayed unsent. Claude Code uses that same bar
through its explicit terminal-host proof lane.

Run the long typing endurance command when working the "typing must feel
untouched" score:

```bash
script/typing_performance_endurance_soak.sh
```

The default target is 10 minutes in a disposable TextEdit file. Use
`--dry-run` for a fast command/config check.
