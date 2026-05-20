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
It only counts manual smoke rows that include the current app binary, current
archive, current commit, or a commit whose app/runtime source still matches the
current checkout.

For the full remaining manual beta proof sequence, run:

```bash
script/manual_proof_refresh.sh --print
script/manual_proof_queue.sh --print
```

Use `script/manual_proof_refresh.sh --run --target textedit` for one focused
refresh at a time. It prints the exact recorder command, runs it, then refuses
the row unless the latest report includes a current app/source proof fingerprint.
This keeps old app binary hashes from making stale source proof look current.

Use `script/manual_proof_queue.sh --run` only when you are ready to walk
through each manual-gated recorder with disposable content. The queue verifies
the current checkout's app bundle once, then reuses that running app for each
manual proof pass.

## Setup

- Launch `dist/SteadyType.app`.
- Prefer `./script/build_and_run.sh --verify` before using `--skip-build`; the
  recorder rejects stale app processes from other checkouts.
- Confirm the menu says `AX ok`.
- Keep test text local and disposable.
- Watch `~/Library/Logs/SteadyType/diagnostics.log` for `suggestion-presented`, `keyboard-action`, `insert`, and `insert-verification`.
- Watch `~/Library/Logs/SteadyType/traces.jsonl` for matching `suggestionPresented`, `suggestionAccepted`, and `insertionVerified` events.
- Prefer a real hardware key press for Tab and the configured full-accept shortcut. Some automation paths can set text or insert a literal tab without going through the app's event tap, which is useful to catch but does not count as an accept pass.
- If a recorder fails, read its layer summary. `suggestion-presented` with `Tab autocomplete action: 0` means rendering worked but key routing did not.
- Recovered insertion fallbacks are allowed when the same suggestion later verifies.
  Unrecovered insertion failures fail the recorder.
- After a typing pass, run `AUTOCOMPLETE_LAB_LOG_START_LINE=<mark> ./script/check_typing_performance_log.sh`. It fails on slow event-tap latency or tap disable/timeout events.
- For the long endurance gate, `script/typing_performance_endurance_soak.sh`
  also samples live CPU/RSS after typing. It fails above 10% average CPU, 25%
  p95 CPU, 6144MB RSS, 512MB RSS growth, or if no live process can be sampled.
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
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh textedit-long-wrap
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh textedit-narrow
```

- Type `Smoke proof feels inst`.
- Confirm a suggestion appears.
- Press Tab and expect `instant`.
- Type ` and stays inst`.
- Press the configured full-accept shortcut and expect another `instant` completion.
- Confirm `insert-verification result=verified`.
- Run the wrapped-line and narrow-window variants before treating TextEdit as fully current.

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

## No Accessibility Permission

This cannot be safely automated because macOS TCC permission changes affect the
developer machine. Use the helper as a manual-gated proof path:

```bash
script/no_accessibility_smoke.sh --print
```

After disabling SteadyType in System Settings and relaunching it, run:

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
- When the recorder asks, type `NO-SUBMIT` only after confirming the prompt was not sent.

## Claude Code

Claude Code uses a proof-only terminal-host lane. The direct
`com.anthropic.claude-code` bundle is still diagnostics-only, but a supported
terminal host may count when explicit proof mode is active and the disposable
marker is present.

Recorder:

```bash
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh claude-code --manual-gate
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh claude-code --host terminal --manual-gate
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh claude-code --host iterm2 --manual-gate
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh claude-code --host ghostty --manual-gate
```

- Use a supported terminal host: Terminal, iTerm2, Warp, Ghostty, kitty, Alacritty, or WezTerm.
- Include `AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF` in the prompt or terminal title.
- Focus a disposable Claude Code prompt without submitting.
- Type a harmless local test fragment like `Can we make this`.
- Confirm a suggestion appears near the prompt or in a stable mirror position.
- Press Tab and expect the next word/suffix to insert without submitting.
- Confirm the text stayed in the composer, no user message bubble appeared, and
  no shell command, user message, or assistant response started.
- Full visible accept is disabled for this profile until separate full-accept no-submit proof exists.
- Do not press Enter as part of the smoke pass.
- When the recorder asks, type `NO-SUBMIT` only after confirming the prompt was not sent.

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
- When the recorder asks, type `NO-SUBMIT` only after confirming the prompt was not sent.

## Hold For Explicit Confirmation

- Mail compose body insertion. Mail is diagnostics-only until a safe adapter is verified.
- Deleting temporary notes, drafts, or files.
- Any field that could contain passwords, payment details, personal data, or real third-party messages.
