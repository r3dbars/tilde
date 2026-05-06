# Manual Smoke Checklist

Use this after `./script/smoke_test.sh` when checking real app behavior.

For a repeatable local record, run `script/manual_smoke_session.sh <app>` before
each app pass. It prints the steps, waits while you test, then validates the
new diagnostics and matching JSONL trace coverage for suggestion presentation,
acceptance, and insertion verification.
Successful runs are recorded in `docs/product/manual-smoke-runs.md`.
Run `script/manual_smoke_status.sh` to see which target apps still need proof,
or `script/manual_smoke_status.sh --strict` when compatibility proof should
block release/beta work. The status command also lists the current scorecard
rows that are still below 10/10.

## Setup

- Launch `dist/AutocompleteLab.app`.
- Confirm the menu says `AX ok`.
- Keep test text local and disposable.
- Watch `~/Library/Logs/AutocompleteLab/diagnostics.log` for `suggestion-presented`, `keyboard-action`, `insert`, and `insert-verification`.
- Watch `~/Library/Logs/AutocompleteLab/traces.jsonl` for matching `suggestionPresented`, `suggestionAccepted`, and `insertionVerified` events.
- Prefer a real hardware key press for Tab/backtick acceptance. Some automation paths can set text or insert a literal tab without going through the app's event tap, which is useful to catch but does not count as an accept pass.
- If a recorder fails, read its layer summary. `suggestion-presented` with `Tab autocomplete action: 0` means rendering worked but key routing did not.
- Recovered insertion fallbacks are allowed when the same suggestion later verifies.
  Unrecovered insertion failures fail the recorder.
- After a typing pass, run `AUTOCOMPLETE_LAB_LOG_START_LINE=<mark> ./script/check_typing_performance_log.sh`. It fails on slow event-tap latency or tap disable/timeout events.

## TextEdit

Recorder: `script/manual_smoke_session.sh textedit`

- Type `Can we`.
- Confirm a suggestion appears.
- Press Tab and expect `Can we make`.
- Press the key above Tab and expect the rest of the visible suggestion.
- Confirm `insert-verification result=verified`.

## Notes

Recorder: `script/manual_smoke_session.sh notes`

- Use the existing autocomplete smoke note.
- Test title-only text with `Can we`.
- Test body text with `Autocomplete smoke` on line one and `Can we` on line two.
- Toggle Checklist and test a checklist row.
- Confirm one-word and full accepts verify.

## Obsidian

Recorder: `script/manual_smoke_session.sh obsidian`

- Use a disposable note.
- Type a partial word like `dicta`.
- If CodeMirror does not expose caret bounds, confirm no detached floating bubble appears.
- If a real caret-bound suggestion appears, accept one word, then full visible text.
- Confirm either insertion verification succeeds or detached suggestion suppression is logged.

## Chrome

Recorder: `script/manual_smoke_session.sh chrome`

- Use a local fixture page: textarea, contenteditable, editor-like,
  Monaco-like, or ProseMirror-like.
- Type `Can we`.
- Confirm the profile is Chrome, render mode is `floatingMirror`, and insertion
  uses key events with AX value replacement as fallback.
- Press Tab and expect `Can we make` without focus leaving the editor.
- Confirm verification succeeds.
- For proof rows, run `script/real_app_smoke.sh chrome --fixture all`; each
  fixture records its own proof label.

## Codex

Recorder: `script/manual_smoke_session.sh codex`

- Focus the Codex message box without submitting.
- Type a harmless local test fragment like `Can we make this`.
- Confirm a suggestion appears near the prompt or in a stable mirror position.
- Press Tab and expect the next word/suffix to insert without submitting.
- Press the key above Tab for full visible accept.
- Do not press Enter as part of the smoke pass.

## Claude Code

Recorder: `script/manual_smoke_session.sh claude-code`

- Focus the Claude Code prompt without submitting.
- Type a harmless local test fragment like `Can we make this`.
- Confirm a suggestion appears near the prompt or in a stable mirror position.
- Press Tab and expect the next word/suffix to insert without submitting.
- Press the key above Tab for full visible accept.
- Do not press Enter as part of the smoke pass.

## Hold For Explicit Confirmation

- Mail compose body insertion. Mail is diagnostics-only until a safe adapter is verified.
- Deleting temporary notes, drafts, or files.
- Any field that could contain passwords, payment details, personal data, or real third-party messages.
