# App Compatibility Runbook

This runbook defines what "works" means for the Mac autocomplete lab.

The current experiment is broad support with narrow safety boundaries. Ordinary
writing fields are default-on; proof remains honest and pending until a real
manual pass exists.

## Ground Rules

- Use disposable text for unproven apps and websites.
- Use the bundle ID, not the visible app name, as the support key.
- Never show suggestions in secure or password-like fields.
- Do not store or send typed text unless the user explicitly turns that on.
- Do not require Ollama, llama.cpp, or another user-managed model server.
- Weird editors use degraded floating/key-event fallbacks and automatic per-app demotion; pending proof is not a support claim.
- Three consecutive insertion verification failures demote one app to one-word acceptance. Six pause it for the session; Settings can resume or manually pause that app.
- Personal Capture is a separate local opt-in. Broad suggestions do not broaden capture, and browser capture stays blocked.

## Compatibility Ladder

| Rung | Name | Meaning | Promotion Gate |
| --- | --- | --- | --- |
| 0 | Blocked | The app should not request or show suggestions. | Default for unknown, secure, or unsafe surfaces. |
| 1 | Detect | The lab can identify the frontmost app, focused editable element, nearby text, and caret rectangle. | No raw text leakage in logs, and no suggestions in the wrong app. |
| 2 | Suggest | A local suggestion appears near the caret and dismisses cleanly. | `Esc`, continued typing, and app switch all remove the suggestion. |
| 3 | Accept | The user can accept text without breaking the editor. | `Tab` accepts the next word, `Shift-Tab` accepts the visible suggestion, backtick stays normal typed text, and no literal tab is inserted. |
| 4 | Stable Beta | The app survives normal writing in that editor. | 15 minutes of typing with no stuck panel, wrong-field insert, clipboard damage, crash, or focus theft. |
| 5 | Supported Candidate | The editor is safe enough to consider default support. | Two testers pass Rung 4 on separate machines and report that suggestions help more than they annoy. |

TextEdit, Notes, Obsidian, and Chrome retain the strongest proof. Newly enabled
apps start at experimental Rung 3 behavior with proof still pending.

## Target App Matrix

| Priority | App | Bundle ID | Current Policy | Target Rung | Pass Focus |
| --- | --- | --- | --- | --- | --- |
| P0 | TextEdit | `com.apple.TextEdit` | MVP allowlist | 4 | Baseline plain/rich text writing loop. |
| P0 | Notes | `com.apple.Notes` | MVP allowlist | 3 | Rich text field detection, clean dismiss, safe insertion. |
| P0 | Obsidian | `md.obsidian` | MVP allowlist | 3 | Electron editor caret geometry and key handling. |
| P0 | Mail | `com.apple.mail` | Experimental default-on | 3 | Compose body only; native undo target; avoid recipient, search, and account fields. |
| P1 | Safari | `com.apple.Safari` | Experimental default-on | 3 | Real websites are open; sensitive browser surfaces stay blocked. |
| P1 | Chrome | `com.google.Chrome` | Experimental default-on | 3 | Expect per-site variation and keep automatic demotion enabled. |
| P1 | Slack / Telegram / Discord | app-specific IDs in the profile store | Experimental default-on | 3 | Prove no-send behavior; accepted control characters are blocked. |
| P1 | Notion | `notion.id` | Experimental default-on | 3 | ProseMirror synthetic-caret geometry; degraded undo. |
| P1 | ChatGPT / Atlas | app-specific IDs in the profile store | Experimental default-on | 3 | Full accept plus word-only command filtering; prove no-submit. |
| P2 | VS Code | `com.microsoft.VSCode` | Experimental degraded | 3 | Floating UI and key events; Monaco geometry is a real risk. |
| P2 | Cursor | `com.todesktop.230313mzl4w4u92` | Experimental degraded | 3 | Floating UI and key events; Monaco/AI composer proof is pending. |

Capture any new bundle ID before adding it to the matrix:

```sh
osascript -e 'id of app "TextEdit"'
defaults read /Applications/Obsidian.app/Contents/Info CFBundleIdentifier
```

## Pass Criteria

An app passes its rung only when all criteria below that rung also pass.

- The lab sees the correct frontmost app bundle ID.
- Suggestions only appear after enough typed context.
- Suggestions do not appear in empty, secure, password, recipient, search, or non-writing fields.
- The suggestion appears close to the caret and does not cover the text being typed.
- Warm suggestion latency usually stays under 700ms.
- `Esc` dismisses without inserting text.
- Continued typing refreshes or dismisses without leaving a stale suggestion.
- `Tab` accepts the next word only while a suggestion is visible.
- `Shift-Tab` accepts the whole visible suggestion only while a suggestion is visible.
- Backtick/tilde stays normal typed text, including in Markdown editors.
- Clipboard fallback preserves the user's clipboard.
- Switching apps or losing focus clears the suggestion.
- Local logs do not contain raw typed text.

## Fail Criteria

Stop the test and manually pause the app if any of these happen. The runtime
also demotes and then session-pauses repeated insertion verification failures:

- Text is inserted into the wrong app or wrong field.
- A secure or password-like field shows a suggestion.
- `Tab` is swallowed when no suggestion is visible.
- A literal tab appears when accepting a suggestion.
- The panel stays visible after focus changes.
- The editor crashes, hangs, or loses user text.
- The clipboard is not restored after insertion fallback.
- The bundle ID cannot be reliably captured.

## Weird Editor Escalation

Use this path for editors with custom canvases, web views, terminals, code editors, or strange Accessibility behavior.

1. Reproduce the same prompt in TextEdit. If TextEdit fails too, fix the general loop first.
2. Record app name, app version, bundle ID, macOS version, rung attempted, and the smallest prompt that fails.
3. Classify the failure:
   - Missing focused element, text, or caret rectangle: use floating fallback or pause the app.
   - Wrong panel position: geometry issue.
   - `Tab` conflict or literal tab: key routing or insertion issue.
   - Wrong-field insert: privacy and focus issue.
   - Clipboard damage: insertion fallback issue.
   - Browser or Electron mismatch: possible per-app adapter, not broad support.
4. Pick one outcome:
   - Record proof if the app passes the target rung cleanly.
   - Keep the degraded fallback if suggestions are useful but placement is risky.
   - Pause the app if privacy, focus, or secure-field behavior is unsafe.
   - Defer if support needs editor-specific work that would distract from the MVP allowlist.

Do not add special handling for a weird editor until the failing behavior is written down and the MVP allowlist is still healthy.
