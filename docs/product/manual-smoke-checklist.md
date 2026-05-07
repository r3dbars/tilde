# Manual Smoke Checklist

Use this after `./script/smoke_test.sh` when checking real app behavior.

For a repeatable local record, run `script/manual_smoke_session.sh <app>` before
each app pass. It prints the steps, waits while you test, then validates the
new diagnostics and matching JSONL trace coverage for suggestion presentation,
acceptance, and insertion verification.
Successful runs are recorded in `docs/product/manual-smoke-runs.md`.
Run `script/manual_smoke_status.sh` to see which target apps still need proof,
or `script/manual_smoke_status.sh --require-all` when compatibility proof should block release/beta work.

## Setup

- Launch `dist/AutocompleteLab.app`.
- Confirm the menu says `AX ok`.
- Keep test text local and disposable.
- Watch `~/Library/Logs/AutocompleteLab/diagnostics.log` for `suggestion-presented`, `keyboard-action`, `insert`, and `insert-verification`.
- Watch `~/Library/Logs/AutocompleteLab/traces.jsonl` for matching `suggestionPresented`, `suggestionAccepted`, and `insertionVerified` events.
- Prefer a real hardware key press for Tab/backtick acceptance. Some automation paths can set text or insert a literal tab without going through the app's event tap, which is useful to catch but does not count as an accept pass.
- If a recorder fails, read its layer summary. `suggestion-presented` with `Tab autocomplete action: 0` means rendering worked but key routing did not.
- Treat these as hard fails: insertion in a different frontmost app, Tab captured without a visible suggestion, Esc not suppressing the current field until blur, any suggestion over a secure/sensitive field, or any detached whole-editor bubble unless the app profile explicitly allows that anchor.

## TextEdit

Recorder: `script/manual_smoke_session.sh textedit`

- Type `Can we`.
- Confirm a suggestion appears.
- Press Tab and expect `Can we make`.
- Press the key above Tab and expect the rest of the visible suggestion.
- Trigger one more suggestion, press Esc, keep typing briefly, and confirm no new suggestion appears in that field.
- Confirm `insert-verification result=verified`.
- Confirm diagnostics include `keyboard-action key=escape action=dismiss handled=true`, `field-suppressed reason=escape`, and `suggestion-blocked reason=suppressedField`.

## Notes

Recorder: `script/manual_smoke_session.sh notes`

- Use the existing autocomplete smoke note.
- Test title-only text with `Can we`.
- Test body text with `Autocomplete smoke` on line one and `Can we` on line two.
- Toggle Checklist and test a checklist row.
- Confirm one-word and full accepts verify.
- Trigger one more suggestion, press Esc, keep typing briefly, and confirm the field stays quiet until blur.
- Confirm diagnostics include Esc dismissal, field suppression, and `reason=suppressedField`.

## Obsidian

Recorder: `script/manual_smoke_session.sh obsidian`

- Use a disposable note.
- Type a partial word like `dicta`.
- If CodeMirror does not expose caret bounds, confirm no detached floating bubble appears.
- If a real caret-bound suggestion appears, accept one word, then full visible text.
- If a real caret-bound suggestion appears, trigger one more suggestion, press Esc, keep typing briefly, and confirm the field stays quiet until blur.
- Confirm either insertion verification succeeds or detached suggestion suppression is logged.

## Chrome

Recorder: `script/manual_smoke_session.sh chrome`

- Use a local `data:` page with a textarea.
- Type `Can we`.
- Confirm the profile is Chrome, render mode is `floatingMirror`, and insertion mode is `axValueReplacement`.
- Press Tab and expect `Can we make` without focus leaving the textarea.
- Trigger one more suggestion, press Esc, keep typing briefly, and confirm no new suggestion appears in that textarea.
- Confirm verification succeeds.

## Codex

Recorder: `script/manual_smoke_session.sh codex`

- Focus the Codex message box without submitting.
- Type a harmless local test fragment like `Can we make this`.
- Confirm a suggestion appears near the prompt or in a stable mirror position.
- Press Tab and expect the next word/suffix to insert without submitting.
- Press the key above Tab for full visible accept.
- Trigger one more suggestion, press Esc, keep typing briefly, and confirm no new suggestion appears in the prompt.
- Do not press Enter as part of the smoke pass.

## Diagnostics-Only Apps

Recorders:

- `script/manual_smoke_session.sh mail`
- `script/manual_smoke_session.sh safari`
- `script/manual_smoke_session.sh slack`
- `script/manual_smoke_session.sh vscode`
- `script/manual_smoke_session.sh cursor`

Use only disposable local drafts, local pages, or local files.

- Type `Can we`.
- Confirm no suggestion appears.
- Confirm Tab is not captured by autocomplete.
- Confirm the key above Tab is not captured by autocomplete.
- Confirm there is no `insert`, `insert-verification`, or accepted trace event for that app.
- Confirm diagnostics show `suggestion-blocked` with `reason=profile-diagnostics-only`.

## Unsupported And High-Risk Apps

Recorders:

- `script/manual_smoke_session.sh atlas`
- `script/manual_smoke_session.sh terminal`
- `script/manual_smoke_session.sh onepassword`

Do not type secrets, commands, payment details, tokens, or real messages.

- Focus only a safe disposable field or prompt.
- Confirm the menu status shows `unsupported`.
- Confirm no suggestion appears.
- Confirm Tab is not captured by autocomplete.
- Confirm no insert or insertion verification is recorded.
- Confirm there is no accepted trace event for the unsupported app.

## Hold For Explicit Confirmation

- Mail compose body insertion. Mail is diagnostics-only until a safe adapter is verified.
- Deleting temporary notes, drafts, or files.
- Any field that could contain passwords, payment details, personal data, or real third-party messages.

## Recorder Hard-Fail Coverage

`script/manual_smoke_session.sh <app> --check` fails the run when it can see:

- `insert` or `insert-verification` for another app in the checked diagnostics slice.
- `keyboard-action key=tab handled=true` without a matching `suggestion-presented` for the app.
- missing Esc calm proof for supported apps: `keyboard-action key=escape action=dismiss handled=true`, `field-suppressed reason=escape`, and `suggestion-blocked reason=suppressedField`.
- `suggestion-presented` over secure/sensitive markers such as `AXSecureTextField`, `secureField`, `sensitiveContent`, password, payment, token, or API-key field hints.
- `suggestion-presented` with `anchorCanPresent=false` or `anchorReason=detachedAnchorDisallowed`.
