# Context Placement Scorecard - 2026-05-09

Placement-only scorecard for Autocomplete Lab. This does not grade model
quality, speed, copy quality, onboarding, design polish, or usefulness.

Base commit checked: `e8d8fdc9`. Branch: `codex/context-placement-scorecard-9361`.
Display state on this Mac during the latest pass: `NSScreen.screens` reported
one active display. Secondary-display placement is therefore not counted for
surfaces refreshed after this note unless a later row says a second display was
available.

## Gate Output Snapshot

Commands run in this pass:

```bash
./script/check_score_targets.sh
./script/scorecard_goal_loop.sh --iterations 10
./script/manual_smoke_status.sh --strict
./script/check_visual_placement_evidence.sh --require-all
./script/check_proof_manifest.sh --require-all
./script/check_prompt_app_proof.sh
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh obsidian --manual-gate
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh codex --manual-gate --skip-build
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh textedit-light
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh textedit-dark
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh textedit-long-wrap
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh textedit-narrow
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh textedit-scrolled
```

Results:

- `check_score_targets.sh`: failed with 60 issues. The main blockers were real-app variants, prompt proof, Chrome editor production proof, and strict proof gates.
- `scorecard_goal_loop.sh --iterations 10`: failed after 10 loops. It reported 14 manual smoke proof gaps.
- `manual_smoke_status.sh --strict`: failed. TextEdit, Notes title/body/checklist, Chrome textarea/contenteditable/public/editor/chat lanes passed; Obsidian, Codex, Claude Code, and Claude desktop lanes still need current proof.
- `check_visual_placement_evidence.sh --require-all`: passed with 16 screenshot files.
- `check_proof_manifest.sh --require-all`: failed with 13 manifest/proof gaps after the Chrome public text-field schema fix.
- `check_prompt_app_proof.sh`: failed because the full trace contains 2 Codex `wrongContextInsertionCount` guard events.
- Obsidian default live refresh: failed with `Could not read the focused Obsidian editor.`
- Codex live refresh: failed safely with `Could not find a safe disposable Codex composer.`
- Chrome CodeMirror official live refresh: passed at 2026-05-09T12:02:35Z with 2 verified accepts, strict visual trace evidence, and screenshot `chrome-codemirror-official.png`.
- Chrome Monaco official and ProseMirror official live refreshes: failed closed because this Chrome profile still rejects JavaScript from Apple Events and AX could not find a verified official editor target on those pages.
- TextEdit variant refresh: light, dark, wrapped line, narrow window, and scrolled document all passed with 2 verified accepts each and strict screenshot trace evidence. During this pass, only one display was available.

## Scores

100 means current, real, screenshot-backed, app-specific proof covers correct
caret placement, suppression, exact-field accept, no wrong field/window/pane,
no stale visible suggestion, and no accidental submit.

| Surface | Score | Current evidence | Missing proof or failure reason | Next action |
| --- | ---: | --- | --- | --- |
| TextEdit | 100 | Current strict visual/manual proof covers default, [light](visual-placement-screenshots/textedit-light.png), [dark](visual-placement-screenshots/textedit-dark.png), [wrapped line](visual-placement-screenshots/textedit-long-wrap.png), [narrow/resized window](visual-placement-screenshots/textedit-narrow.png), and [scrolled document](visual-placement-screenshots/textedit-scrolled.png). Each refreshed lane has 2 verified accepts into the exact TextEdit document. The harness targets the disposable AX window title while other TextEdit windows are present, and no secondary display was available in `NSScreen.screens` for this pass. | None for the currently available TextEdit placement cases. | Keep this green; rerun a secondary-display lane if a second display is connected later. |
| Apple Notes title | 90 | Current manual gate passes; screenshot `notes-title.png`; title lane is separate. | More title lengths and same-slice undo/accept recovery proof are missing. | Run `notes-title-undo` and short/long title variants. |
| Apple Notes body | 90 | Current manual gate passes; screenshot `notes-body.png`; body lane is separate. | More body lengths, scroll, and same-slice undo/accept recovery proof are missing. | Run `notes-body-undo` plus long/scrolled body proof. |
| Apple Notes checklist | 88 | Current manual gate passes; screenshot `notes-checklist.png`; checklist lane is separate. | Checked rows, long rows, scroll, and undo proof are missing. | Run `notes-checklist-undo`, checked-row, and long-row variants. |
| Obsidian default editor | 100 | Current strict visual proof at 2026-05-09T11:05:03Z with two verified accepts in a disposable Obsidian proof note. | None for this default editor lane. | Keep this row green while broader Obsidian variants continue. |
| Obsidian theme variant | 100 | Current strict visual proof at 2026-05-09T11:10:05Z with two verified accepts in `ObsidianProofVault` using the Autocomplete Lab Proof theme. | None for this theme lane. | Keep this row green while broader Obsidian variants continue. |
| Obsidian split/side pane | 100 | Current strict visual proof at 2026-05-09T11:18:00Z with two verified accepts in a visible split-pane Obsidian window. | None for this pane lane. | Keep this row green while broader Obsidian variants continue. |
| Obsidian long scrolled note | 55 | The lane now seeds a real long disposable Markdown note, reaches the scrolled editor, repairs stale CodeMirror AX line drift, shows a screenshot-backed scrolled suggestion, and verifies the first Tab insertion. | No passing bounded row yet. The second accept still races Obsidian's virtualized AX/key state: the suggestion is shown, then the key path can pass through as `passthrough-after-typing` or the caret reverts to `middleOfLine`. | Stabilize the second accept path without using queued setup keystrokes, then rerun `obsidian-long-note --manual-gate` to create a passing row. |
| Codex prompt box | 45 | Historical `codex-inline.png`; helper is marker-gated and word-only. | Current refresh failed safely because there was no safe disposable composer; global prompt proof also has 2 wrong-context guard events. | Clear/open a disposable Codex prompt containing `AUTOCOMPLETE_LAB_CODEX_PROOF`, then rerun `codex --manual-gate`. |
| Claude Code terminal-hosted prompt | 45 | Historical Terminal-host screenshot `claude-code-terminal.png`; normal direct bundle stays disabled/proof-only. | Current proof is not refreshed; iTerm2 and Ghostty host rows are missing; Warp is not installed; terminal execution risk stays unproven for variants. | Run host-labeled `claude-code --host terminal`, `--host iterm2`, and `--host ghostty` in disposable prompts. Keep Warp blocked. |
| Claude desktop prompt box | 60 | Historical `claude-desktop.png`; one default no-submit slice exists. | Empty, long, wrapped, narrow, context, light, dark, and full-accept no-submit lanes are missing. | Run each `claude-* --manual-gate` layout lane. Keep full accept disabled. |
| Chrome normal textarea | 95 | Current strict local and public textarea proof passes; screenshot `chrome-textarea.png`. | More public domains, secondary display, multi-window, and resize variants are not complete. | Broaden public textarea and display/window variants. |
| Chrome contenteditable | 95 | Current strict local and public contenteditable proof passes; screenshot `chrome-contenteditable.png`. | More public contenteditable/rich-editor domains and display/window variants are missing. | Add more public rich-editor proof rows. |
| Chrome local chat-like composer | 93 | Current local chat-like fixture passes; screenshot `chrome-chat-like.png`; submit counters stay zero for the fixture. | This does not prove ChatGPT, Slack, Discord, or other real hosted composers. | Keep real browser-chat services blocked until exact no-submit proof exists. |
| Chrome public textarea page | 94 | Current `textarea-public` row passes with strict screenshot-backed trace evidence. | Only one public page is proven. | Add more public textarea pages and secondary-display proof. |
| Chrome public contenteditable page | 94 | Current `contenteditable-public` row passes with strict screenshot-backed trace evidence. | Only one public page is proven. | Add more public contenteditable pages and scroll/resize variants. |
| Chrome CodeMirror | 100 | Current official CodeMirror demo proof passed at 2026-05-09T12:02:35Z with 2 verified accepts, strict screenshot-backed trace evidence, and screenshot [chrome-codemirror-official.png](visual-placement-screenshots/chrome-codemirror-official.png). Local CodeMirror-like fixture and Obsidian CodeMirror-family proof also pass. | None for this CodeMirror lane. | Keep this row green while Monaco and ProseMirror official-demo lanes continue. |
| Chrome Monaco | 85 | Local Monaco-like and real Monaco rows pass in current smoke status. | Production/default Chrome Monaco variance remains open in the manifest. | Run official/default Monaco lanes until manifest can be complete. |
| Chrome ProseMirror | 86 | Local ProseMirror-like and real ProseMirror rows pass in current smoke status. | Production/default Chrome ProseMirror variance remains open in the manifest. | Run official/default ProseMirror lanes until manifest can be complete. |
| Browser editor fixtures aggregate | 88 | Local editor-like, Monaco-like, ProseMirror-like, real Monaco, real ProseMirror, and official CodeMirror have screenshot evidence. | Production Monaco and ProseMirror official-demo requirements remain blocked: normal Chrome rejects JavaScript from Apple Events and AX did not expose a verified official editor target on those pages. | Keep CodeMirror green; close Monaco/ProseMirror only when real official-demo or equivalent production proof passes. |
| Unsupported, secure, URL, search, password, payment, login fields | 72 | Sensitive-field and browser hosted-surface policies exist; blocked profiles are listed in the manifest. | No single current screenshot-backed suppression sweep proves every listed private/secure field class. | Add a real suppression-only proof suite with disposable URL/search/login/password/payment fields. |

## Other Manifest Profiles

These rows are scored for correct hidden/blocked behavior, not support.
They cannot reach 100 without real app-specific no-suggestion proof.

| Surface/profile | Score | Current state | Missing proof or blocker |
| --- | ---: | --- | --- |
| Mail | 65 | Diagnostics-only/blocked. | No current compose suppression and insertion-safety proof. |
| Safari | 55 | Disabled/blocked. | No Safari textarea/contenteditable/no-submit proof. |
| Slack | 50 | Disabled/blocked. | Prompt composer no-submit proof missing. |
| Telegram | 50 | Disabled/blocked. | Send-by-enter and caption proof missing. |
| Notion | 55 | Disabled/blocked. | Real ProseMirror placement and workspace privacy proof missing. |
| Discord | 50 | Disabled/blocked. | Disposable server/channel no-submit proof missing. |
| Discord PTB | 50 | Disabled/blocked. | Same as Discord; no app-specific proof. |
| Discord Canary | 50 | Disabled/blocked. | Same as Discord; no app-specific proof. |
| VS Code | 55 | Diagnostics-only/blocked. | Real app Monaco and command-palette Tab behavior unproven. |
| Cursor | 50 | Diagnostics-only/blocked. | Monaco plus AI composer no-submit proof missing. |
| ChatGPT Atlas | 45 | Disabled/blocked. | Browser/prompt hybrid proof missing. |
| ChatGPT `com.openai.chat` | 45 | Disabled/blocked. | Exact-version prompt no-submit proof missing. |
| ChatGPT `com.openai.ChatGPT` | 45 | Disabled/blocked. | Alternate bundle exact-version proof missing. |

## Stop Condition

This run cannot honestly close the goal at 100/100. The blockers are real:
manual-gated app setup is missing for Obsidian variants, Claude layouts, and
Claude Code host variants; Warp is not installed; the Codex helper refused to
touch a non-disposable composer; and broad secure/private-field suppression does
not yet have screenshot-backed app-specific proof.
