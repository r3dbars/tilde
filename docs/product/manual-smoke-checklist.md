# Manual Smoke Checklist

Use this after `./script/smoke_test.sh` when checking real app behavior.

For a repeatable local record, use `script/real_app_smoke.sh <app>` when it is
listed below. It builds/relaunches the app, prints the safe steps, waits while
you test, then validates the new diagnostics and matching JSONL trace coverage.
Successful runs are recorded in `docs/product/manual-smoke-runs.md`.
The recorder temporarily enables only the target app for that proof launch, so
fresh installs can stay default-off without blocking disposable proof runs.
Run `script/manual_smoke_status.sh` to see insertion proof and separate
screenshot-backed placement proof. Use `script/manual_smoke_status.sh --strict`
when missing insertion proof or missing screenshot proof should block
release/beta work. The status command also lists the current scorecard rows
that are still below 10/10. In strict mode it also runs the screenshot evidence
gate, so stale screenshot rows, unreferenced screenshot files, and below-target
visual rows without a clear `Pending` label block the pass.

## Setup

- Launch `dist/AutocompleteLab.app`.
- Confirm the menu says `AX ok`.
- Keep test text local and disposable.
- Watch `~/Library/Logs/AutocompleteLab/diagnostics.log` for `suggestion-presented`, `keyboard-action`, `insert`, and `insert-verification`.
- Watch `~/Library/Logs/AutocompleteLab/traces.jsonl` for matching `suggestionPresented`, `suggestionAccepted`, and `insertionVerified` events.
- Prefer a real hardware key press for Tab and the configured full-accept shortcut. Some automation paths can set text or insert a literal tab without going through the app's event tap, which is useful to catch but does not count as an accept pass.
- If a recorder fails, read its layer summary. `suggestion-presented` with `Tab autocomplete action: 0` means rendering worked but key routing did not.
- Recovered insertion fallbacks are allowed when the same suggestion later verifies.
  Unrecovered insertion failures fail the recorder.
- After a typing pass, run `AUTOCOMPLETE_LAB_LOG_START_LINE=<mark> ./script/check_typing_performance_log.sh`. It fails on slow event-tap latency or tap disable/timeout events.
- After a visual placement pass, update the scorecard screenshot row and run
  `./script/check_visual_placement_evidence.sh --require-all` when every row
  should have screenshot proof. If a visual row is still below target, label it
  `Pending` plainly instead of letting a stale screenshot look finished.

## TextEdit

Recorder:

```bash
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh textedit
```

- Type `Smoke proof feels inst`.
- Confirm a suggestion appears.
- Press Tab and expect `instant`.
- Type ` and stays inst`.
- Press the configured full-accept shortcut and expect another `instant` completion.
- Confirm `insert-verification result=verified`.

## Notes

Recorder:

```bash
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-title --manual-gate
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-body --manual-gate
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-checklist --manual-gate
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-title-undo --manual-gate
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-body-undo --manual-gate
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-checklist-undo --manual-gate
```

- Use the existing autocomplete smoke note.
- Do not let automation create, delete, or search private notes.
- Do not record a generic `notes` pass as proof. Title, body, checklist, and undo are separate proof targets.
- Test title-only text with `Smoke proof feels inst`, then ` and stays inst`.
- Test body text with `Autocomplete smoke` on line one and `Smoke proof feels inst` on line two, then ` and stays inst`.
- Toggle Checklist and test a checklist row with `Smoke proof feels inst`, then ` and stays inst`.
- Confirm one-word and full accepts verify.
- In undo lanes, press Command-Z after the first Tab accept and confirm `accepted-insertion-undone` before the second accept.

## Obsidian

Recorder:

```bash
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh obsidian --manual-gate
```

- Use a disposable vault note only.
- Do not point the proof pass at real vault content.
- Type a partial word like `dicta`.
- Confirm the mirror suggestion is anchored to the caret, not the whole editor.
- Accept one word, then full visible text.
- Confirm insertion verification succeeds. Detached suggestion suppression is useful safety evidence, but it is not a full pass.

## Chrome

Recorder:

```bash
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh chrome --fixture all
```

- Use a local fixture page: textarea, contenteditable, editor-like,
  Monaco-like, or ProseMirror-like.
- Type `Smoke proof feels inst`.
- Confirm the profile is Chrome, render mode is `inlineAdjacent` when synthetic
  caret placement is available and `floatingMirror` only as fallback. Insertion
  uses key events with AX value replacement as fallback.
- Press Tab and expect `instant` without focus leaving the editor.
- Type ` and stays inst`.
- Press the configured full-accept shortcut and expect another `instant` completion.
- Confirm verification succeeds.
- Each fixture records its own proof label.

## Codex

Recorder:

```bash
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh codex --manual-gate
```

- Focus the Codex message box without submitting.
- Type only disposable prompt text that includes `AUTOCOMPLETE_LAB_CODEX_PROOF`,
  then a harmless local test fragment like `Can we make this`.
- Confirm a suggestion appears near the prompt or in a stable mirror position.
- Press Tab and expect the next word/suffix to insert without submitting.
- Confirm the text stayed in the composer, no user message bubble appeared, and
  no assistant response started.
- The recorder will not accept a Codex proof unless the disposable proof marker
  is explicitly confirmed.
- Full visible accept is disabled for this profile until separate full-accept no-submit proof exists.
- Do not press Enter as part of the smoke pass.

## Claude Code

Claude Code uses a proof-only terminal-host lane. The direct
`com.anthropic.claude-code` bundle is still diagnostics-only, but a supported
terminal host may count when explicit proof mode is active and the disposable
marker is present.

Recorder:

```bash
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh claude-code --manual-gate
```

- Use a supported terminal host: Terminal, iTerm2, Warp, Ghostty, kitty, or Alacritty.
- Include `AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF` in the prompt or terminal title.
- Focus a disposable Claude Code prompt without submitting.
- Type a harmless local test fragment like `Can we make this`.
- Confirm a suggestion appears near the prompt or in a stable mirror position.
- Press Tab and expect the next word/suffix to insert without submitting.
- Confirm the text stayed in the composer, no user message bubble appeared, and
  no shell command, user message, or assistant response started.
- Full visible accept is disabled for this profile until separate full-accept no-submit proof exists.
- Do not press Enter as part of the smoke pass.

## Claude Desktop

Recorder:

```bash
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh claude --manual-gate
```

- Focus the Claude prompt without submitting.
- Type a harmless local test fragment like `Can we make this`.
- Confirm a suggestion appears near the prompt or in a stable mirror position.
- Press Tab and expect the next word/suffix to insert without submitting.
- Confirm the text stayed in the composer, no user message bubble appeared, and
  no assistant response started.
- Full visible accept is disabled for this profile until separate full-accept no-submit proof exists.
- Do not press Enter as part of the smoke pass.

## Hold For Explicit Confirmation

- Mail compose body insertion. Mail is diagnostics-only until a safe adapter is verified.
- Deleting temporary notes, drafts, or files.
- Any field that could contain passwords, payment details, personal data, or real third-party messages.
