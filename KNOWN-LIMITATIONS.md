# SteadyType Known Limitations

This is a lab app, not a broad system-wide promise.

Current proof truth: strict manual smoke tracks only the boring beta-safe rows.
Stale screenshots and old insertion rows do not make a beta lane current.

## Supported First

- TextEdit
- Apple Notes title, body, and checklist surfaces with current proof
- Obsidian when current proof is green
- Chrome local textarea/contenteditable fixtures

## Diagnostics Or Proof-Only

- Codex, Claude Code, and Claude desktop are proof-only prompt/terminal targets,
  not beta-safe normal writing apps.
- Full accept stays off in prompt apps until a separate no-submit full-accept
  proof exists.
- Mail is diagnostics-only until compose insertion is proven safe.
- Browser webmail, including Gmail and Outlook in a browser, is blocked until
  disposable compose-body proof exists.
- Terminal apps are blocked.
- Password managers, login fields, payment fields, address fields, search
  fields, URL fields, and secure fields stay off.

## Not Yet Proven

- Fresh install and uninstall on a clean VM.
- Two macOS major versions.
- Intel hardware.
- Real production Monaco and ProseMirror editors beyond local fixtures.
- IME/composition-heavy workflows.
- Remote desktops, VMs, browser profile edge cases, and unusual custom editors.

## Stop The Test If

- text inserts in the wrong place,
- a prompt/chat app submits,
- a secure or private field shows a suggestion,
- typing lags,
- Tab feels surprising,
- the app falls back to mock suggestions,
- diagnostics ask for raw typed text by default.
