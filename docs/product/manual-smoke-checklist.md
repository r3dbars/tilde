# Manual Smoke Checklist

Use this after `./script/smoke_test.sh` when checking real app behavior.

For a repeatable local record, run `script/manual_smoke_session.sh <app>` before
each app pass. It prints the steps, waits while you test, then validates the
new diagnostics for suggestion presentation, insert, and insertion verification.
Successful runs are recorded in `docs/product/manual-smoke-runs.md`.

## Setup

- Launch `dist/AutocompleteLab.app`.
- Confirm the menu says `AX ok`.
- Keep test text local and disposable.
- Watch `~/Library/Logs/AutocompleteLab/diagnostics.log` for `suggestion-presented`, `insert`, and `insert-verification`.
- Prefer a real hardware key press for Tab/backtick acceptance. Some automation paths can set text or insert a literal tab without going through the app's event tap, which is useful to catch but does not count as an accept pass.

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
- Type `Can we`.
- Confirm mirror rendering stays stable across CodeMirror focus churn.
- Accept one word, then full visible text.
- Confirm verification succeeds or the field suppresses itself after failure.

## Chrome

Recorder: `script/manual_smoke_session.sh chrome`

- Use a local `data:` page with a textarea.
- Type `Can we`.
- Confirm the profile is Chrome, render mode is `floatingMirror`, and insertion mode is `axValueReplacement`.
- Press Tab and expect `Can we make` without focus leaving the textarea.
- Confirm verification succeeds.

## Hold For Explicit Confirmation

- Mail compose body insertion. Mail is diagnostics-only until a safe adapter is verified.
- Deleting temporary notes, drafts, or files.
- Any field that could contain passwords, payment details, personal data, or real third-party messages.
