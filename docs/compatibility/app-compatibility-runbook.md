# App Compatibility Runbook

This runbook defines what "works" means for the Mac autocomplete lab.

The MVP goal is not broad support. It is a small allowlist that proves the writing loop feels helpful and does not break trust.

## Ground Rules

- Keep the app allowlisted while testing.
- Use the bundle ID, not the visible app name, as the support key.
- Never show suggestions in secure or password-like fields.
- Do not store or send typed text unless the user explicitly turns that on.
- Do not require Ollama, llama.cpp, or another user-managed model server.
- Weird editors should start blocked or detect-only until there is clear evidence they behave well.

## Compatibility Ladder

| Rung | Name | Meaning | Promotion Gate |
| --- | --- | --- | --- |
| 0 | Blocked | The app should not request or show suggestions. | Default for unknown, secure, or unsafe surfaces. |
| 1 | Detect | The lab can identify the frontmost app, focused editable element, nearby text, and caret rectangle. | No raw text leakage in logs, and no suggestions in the wrong app. |
| 2 | Suggest | A local suggestion appears near the caret and dismisses cleanly. | `Esc`, continued typing, and app switch all remove the suggestion. |
| 3 | Accept | The user can accept text without breaking the editor. | `Tab` accepts the next word, backtick/tilde accepts the visible suggestion, and no literal tab is inserted. |
| 4 | Stable Beta | The app survives normal writing in that editor. | 15 minutes of typing with no stuck panel, wrong-field insert, clipboard damage, crash, or focus theft. |
| 5 | Supported Candidate | The editor is safe enough to consider default support. | Two testers pass Rung 4 on separate machines and report that suggestions help more than they annoy. |

TextEdit should reach Rung 4 first. Notes, Obsidian, and Mail should reach Rung 3 before adding more apps.

## Target App Matrix

| Priority | App | Bundle ID | Current Policy | Target Rung | Pass Focus |
| --- | --- | --- | --- | --- | --- |
| P0 | TextEdit | `com.apple.TextEdit` | MVP allowlist | 4 | Baseline plain/rich text writing loop. |
| P0 | Notes | `com.apple.Notes` | MVP allowlist | 3 | Rich text field detection, clean dismiss, safe insertion. |
| P0 | Obsidian | `md.obsidian` | MVP allowlist | 3 | Electron editor caret geometry and key handling. |
| P0 | Mail | `com.apple.mail` | MVP allowlist | 3 | Compose body only; avoid recipient, search, and account fields. |
| P1 | Safari | `com.apple.Safari` | Not allowlisted | 1 | Web editor detection only; do not broaden until MVP apps pass. |
| P1 | Chrome | `com.google.Chrome` | Not allowlisted | 1 | Web editor detection only; expect per-site variation. |
| P2 | VS Code | `com.microsoft.VSCode` | Not allowlisted | 1 | Treat as a weird editor because custom text surfaces and keybindings can fight insertion. |

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
- Backtick/tilde accepts the whole visible suggestion only while a suggestion is visible.
- Clipboard fallback preserves the user's clipboard.
- Switching apps or losing focus clears the suggestion.
- Local logs do not contain raw typed text.

## Fail Criteria

Stop the test and drop the app back one rung if any of these happen:

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
   - Missing focused element, text, or caret rectangle: keep blocked or detect-only.
   - Wrong panel position: geometry issue.
   - `Tab` conflict or literal tab: key routing or insertion issue.
   - Wrong-field insert: privacy and focus issue.
   - Clipboard damage: insertion fallback issue.
   - Browser or Electron mismatch: possible per-app adapter, not broad support.
4. Pick one outcome:
   - Promote if the app passes the target rung cleanly.
   - Keep detect-only if suggestions are useful but insertion is risky.
   - Block if privacy, focus, or secure-field behavior is unsafe.
   - Defer if support needs editor-specific work that would distract from the MVP allowlist.

Do not add special handling for a weird editor until the failing behavior is written down and the MVP allowlist is still healthy.
