# Manual Smoke Checklist

Use this after `./script/smoke_test.sh` when checking real app behavior.

For a repeatable local record, use `script/real_app_smoke.sh <app>` when it is
listed below. It builds/relaunches the app, prints the safe steps, waits while
you test, then validates the new diagnostics and matching JSONL trace coverage.
Successful runs are recorded in `docs/product/manual-smoke-runs.md`.
Run `script/manual_smoke_status.sh` to see insertion proof and separate
screenshot-backed placement proof. Use `script/manual_smoke_status.sh --strict`
when missing insertion proof or missing screenshot proof should block
release/beta work. The status command also lists the current scorecard rows
that are still below 10/10. In strict mode it also runs the screenshot evidence
gate, so stale screenshot rows, unreferenced screenshot files, and below-target
visual rows without a clear `Pending` label block the pass.

For the full remaining manual beta proof sequence, run:

```bash
script/manual_proof_queue.sh --print
```

Use `script/manual_proof_queue.sh --run` only when you are ready to walk
through each manual-gated recorder with disposable content. The queue verifies
the current checkout's app bundle once, then reuses that running app for each
manual proof pass.

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
- After a visual placement pass, update the scorecard screenshot row and run
  `./script/check_visual_placement_evidence.sh --require-all` when every row
  should have screenshot proof. If a visual row is still below target, label it
  `Pending` plainly instead of letting a stale screenshot look finished.

## TextEdit

Recorder:

```bash
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh textedit
```

- Type `Can we`.
- Confirm a suggestion appears.
- Press Tab and expect `Can we make`.
- Press the key above Tab and expect the rest of the visible suggestion.
- Confirm `insert-verification result=verified`.

## Notes

Recorder:

```bash
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-title --manual-gate
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-body --manual-gate
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-checklist --manual-gate
```

- Use the existing autocomplete smoke note.
- Do not let automation create, delete, or search private notes.
- Do not record a generic `notes` pass as proof. Title, body, and checklist are separate proof targets.
- Test title-only text with `Can we`.
- Test body text with `Autocomplete smoke` on line one and `Can we` on line two.
- Toggle Checklist and test a checklist row.
- Confirm one-word and full accepts verify.

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
- Type `Can we`.
- Confirm the profile is Chrome, render mode is `inlineAdjacent` when synthetic
  caret placement is available and `floatingMirror` only as fallback. Insertion
  uses key events with AX value replacement as fallback.
- Press Tab and expect `Can we make` without focus leaving the editor.
- Confirm verification succeeds.
- Each fixture records its own proof label.

## Codex

Recorder:

```bash
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh codex --manual-gate
```

- Focus the Codex message box without submitting.
- Type a harmless local test fragment like `Can we make this`.
- Confirm a suggestion appears near the prompt or in a stable mirror position.
- Press Tab and expect the next word/suffix to insert without submitting.
- Full visible accept is disabled for this profile until separate full-accept no-submit proof exists.
- Do not press Enter as part of the smoke pass.

## Claude Code

Recorder:

```bash
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh claude-code --manual-gate
```

- Focus the Claude Code prompt without submitting.
- Type a harmless local test fragment like `Can we make this`.
- Confirm a suggestion appears near the prompt or in a stable mirror position.
- Press Tab and expect the next word/suffix to insert without submitting.
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
- Full visible accept is disabled for this profile until separate full-accept no-submit proof exists.
- Do not press Enter as part of the smoke pass.

## Hold For Explicit Confirmation

- Mail compose body insertion. Mail is diagnostics-only until a safe adapter is verified.
- Deleting temporary notes, drafts, or files.
- Any field that could contain passwords, payment details, personal data, or real third-party messages.
