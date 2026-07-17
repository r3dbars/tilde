# SteadyType Known Limitations

This is a lab app, not a broad system-wide promise.

Current proof truth: strict manual smoke tracks evidence, while the Phase 2
product experiment enables many ordinary writing fields before that evidence is
complete. Stale screenshots and old insertion rows do not make a support claim
current.

## Supported First

- TextEdit
- Apple Notes title, body, and checklist surfaces with current proof
- Obsidian when current proof is green
- Chrome local textarea/contenteditable fixtures

## Dogfood Or Proof-Limited

- Codex, Claude Code, and Claude desktop are guarded dogfood prompt/terminal
  targets, not beta-safe normal writing apps.
- One-word accept is the only normal dogfood path for Claude Code and Claude
  desktop. Codex has a separate current full-accept no-submit proof for its
  default composer only.
- Full accept stays off in prompt apps until a separate no-submit full-accept
  proof exists for that exact app and layout.
- Mail, Safari, Slack, Telegram, Notion, Discord, VS Code, Cursor, ChatGPT,
  Atlas, browser webmail, and ordinary real-site writing fields are
  experimental default-on paths with proof still pending.
- Three consecutive insertion verification failures demote one app to one-word
  acceptance; six pause it for the session. This limits repeated damage but
  does not prove placement or insertion correctness.
- Notion/ProseMirror caret geometry and VS Code/Cursor Monaco geometry are known
  real risks. Their undo guarantee is explicitly degraded.
- Chat composers block newline, Tab, and control characters in accepted text.
  ChatGPT and Atlas also keep word-only command-injection filtering even though
  full acceptance is available.
- Personal writing capture remains local and opt-in. Browser capture stays
  blocked even when browser suggestions are enabled.
- Terminal apps are blocked.
- Password managers, login fields, payment fields, private search, browser
  address bars, developer tools, URL/search fields, and secure fields stay off.

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
