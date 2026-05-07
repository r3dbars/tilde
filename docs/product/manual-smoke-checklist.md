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
It only counts manual smoke rows that include the current Git commit or current
release archive checksum in the trace slice.

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

## Anchor Source Rows

These rows keep the fallback ladder honest. A real app pass can close more than
one row only when the diagnostics slice shows that exact anchor source.

| Anchor source | Smoke path | Required signal | Current blocker |
| --- | --- | --- | --- |
| `caret` | TextEdit smoke | `placementAnchorSource=caret`, `placementConfidenceBand=high`, and verified insertion | None for native proof; still needs more native app variants. |
| `synthetic-caret` | Chrome fixtures, Obsidian, Codex, and prompt-app passes | `placementAnchorSource=synthetic-caret`, medium or better confidence, and verified insertion | Real editor/prompt apps still need current screenshot-backed proof. |
| `line` | TextEdit wrapped-line smoke after line metadata lands | `placementAnchorSource=line` with line rect inside field/window | Blocked until `AXInsertionPointLineNumber` or equivalent line bounds are captured. |
| `field` | App-specific diagnostic pass where caret is missing but field bounds are valid | `placementAnchorSource=field`, usable fallback quality, and no detached whole-editor drift | Only valid for profiles that explicitly allow field anchors. |
| `window` | Explicit diagnostics-only invocation | `placementAnchorSource=window` and no automatic Tab capture | Not a normal typing surface; keep as diagnostics only. |
| `off` | Unsupported app, sensitive field, or no-Accessibility smoke | no visible suggestion, no handled accept key, and a blocked decision | Needs the no-Accessibility proof path below for the permission case. |

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

## No Accessibility Permission

This cannot be safely automated because macOS TCC permission changes affect the
developer machine. Use the helper as a manual-gated proof path:

```bash
script/no_accessibility_smoke.sh --print
```

After disabling AutocompleteLab in System Settings and relaunching it, run:

```bash
AUTOCOMPLETE_LAB_LOG_START_LINE=<mark> script/no_accessibility_smoke.sh --check
```

- Expect `launch accessibility=false`.
- Expect a status line with `accessibility=AX missing`.
- Expect `Blocked: Accessibility permission missing`.
- Confirm no `suggestion-presented` line appears in the slice.
- Confirm no accept key is handled in the slice.

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
