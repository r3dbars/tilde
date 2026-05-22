# SteadyType Known Limitations

This is a lab app, not a broad system-wide promise.

Current proof truth: strict manual smoke still has 35 stale or pending target
app rows, and the proof manifest still has 6 partial surfaces. Stale
screenshots and old insertion rows do not make a beta lane current.

## Supported First

- TextEdit is the green reference target.
- Apple Notes title, body, and checklist are yellow rich-text targets that need
  split proof.
- Obsidian is yellow and only safe in disposable proof lanes when current proof
  is green.
- Chrome is yellow for local/public text fields and included fixtures only.

## Diagnostics Or Proof-Only

- Codex is word-only dogfood. Default no-submit proof exists, but more layouts
  and a separate full-accept no-submit lane are still gaps.
- Claude desktop is word-only. Default no-submit proof exists, but layout
  variants and full accept remain blocked.
- Claude Code is proof-only through an explicit terminal-host lane. The direct
  Claude Code bundle is diagnostics-only.
- Full accept stays off in prompt apps until a separate no-submit full-accept
  proof exists.
- Mail is diagnostics-only until compose insertion is proven safe.
- Terminal apps are blocked except for explicit Claude Code proof-mode host
  lanes.
- Password managers, login fields, payment fields, address fields, search
  fields, URL fields, and secure fields stay off.

## Not Yet Proven

- Fresh install and uninstall on a clean VM.
- Two macOS major versions.
- Intel hardware.
- Real production Monaco and CodeMirror/ProseMirror editors beyond proven
  disposable lanes.
- Host-labeled Claude Code proof for iTerm2 and Ghostty.
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
