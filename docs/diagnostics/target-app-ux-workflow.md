# Target App UX Diagnostics

Use this when the autocomplete overlay feels off in a real writing app.

The goal is to capture enough visual and runtime context to debug placement, acceptance, and dismiss behavior without collecting typed text.

## Privacy Rules

- Use throwaway test text only.
- Do not capture real notes, chats, prompts, emails, or drafts.
- The script does not read Accessibility text values, clipboard contents, keystrokes, browser history, or document contents.
- Screenshots can still show visible text, so crop tightly and review the bundle before sharing.

## Target Matrix

| Target | Script profile | What to check |
| --- | --- | --- |
| TextEdit | `textedit` | Baseline native text field behavior, caret alignment, `Tab`, backtick/tilde, `Esc`. |
| Notes | `notes` | Rich text behavior, focus changes, and whether suggestions feel too jumpy. |
| Codex/ChatGPT composer | `composer` | Multiline composer behavior, submit controls nearby, and whether `Tab` conflicts with UI focus. |
| Browsers | `browser` | Textarea/contenteditable behavior in Safari, Chrome, Arc, Firefox, Brave, or Edge. |
| Obsidian-like editors | `obsidian` | Markdown/editor behavior in Obsidian, Logseq, Bear, Cursor, or VS Code. |

## Manual Loop

1. Start AutocompleteLab:

   ```sh
   ./script/build_and_run.sh --verify
   ```

2. Run the diagnostic with a delay:

   ```sh
   ./script/diagnose_target_app.sh --profile textedit --app TextEdit --delay 8
   ```

3. During the delay, switch to the target app and type throwaway text like:

   ```text
   I think this should
   ```

4. Wait for the suggestion to appear, then crop the screenshot tightly around the caret and suggestion.
5. Test `Tab`, backtick/tilde, and `Esc`.
6. Open the generated `notes.md` and record what felt wrong.

## Example Commands

```sh
./script/diagnose_target_app.sh --profile textedit --app TextEdit --delay 8
./script/diagnose_target_app.sh --profile notes --app Notes --delay 8
./script/diagnose_target_app.sh --profile composer --app ChatGPT --delay 10
./script/diagnose_target_app.sh --profile browser --app "Google Chrome" --delay 10
./script/diagnose_target_app.sh --profile obsidian --app Obsidian --delay 10
```

Add `--full-screen` only when the whole layout matters. Use `--no-screenshot` when you only need process/log context.

## Bundle Contents

Each run is saved under `docs/diagnostics/runs/<timestamp>-<label>/`.

- `manifest.txt`: run settings and privacy boundary.
- `frontmost-app.txt`: app name, bundle id, and PID only.
- `process-context.txt`: PID, parent PID, elapsed time, status, and executable path only.
- `system-context.txt`: macOS and machine basics.
- `autocomplete-log.txt`: recent AutocompleteLab logs only.
- `screenshot.png`: selected or full-screen screenshot, if captured.
- `notes.md`: short review template.
