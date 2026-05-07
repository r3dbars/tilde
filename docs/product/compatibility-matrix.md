# Compatibility Matrix

Current compatibility stance for the lab build.

| App | Status | Render | Anchor source | Insert | Proof |
| --- | --- | --- | --- | --- | --- |
| TextEdit | supported | inline, mirror fallback | caret trusted, line/field fallback | AX selected text, value fallback | recorded manual smoke pass |
| Notes | supported | inline, mirror fallback | caret trusted, line/field fallback | key events, AX selected text fallback | recorded manual smoke pass |
| Obsidian | supported only when caret bounds are available | mirror | caret trusted; detached field/window anchors blocked | AX then key events, key fallback | detached CodeMirror suggestions are suppressed because whole-editor anchors look wrong |
| Chrome | supported for local text fields | mirror | field fallback after browser caret rejection | AX value replacement, key fallback | recorded local textarea pass |
| Codex | dogfood target | synthetic inline caret, no detached fallback | synthetic caret trusted; detached field/window anchors blocked | key events, AX fallback | pending manual smoke pass |
| Mail | diagnostics only | disabled | off | disabled | blocked until safe compose adapter exists |
| Safari | diagnostics only | disabled | off | disabled | browser textarea and rich-editor behavior need separate proof |
| Slack | diagnostics only | disabled | off | disabled | Electron composer needs app-specific proof |
| VS Code | diagnostics only | disabled | off | disabled | Monaco caret and Tab behavior need app-specific proof |
| Cursor | diagnostics only | disabled | off | disabled | Monaco caret and Tab behavior need app-specific proof |
| Atlas | unsupported | disabled | off | disabled | blocked until focused AX element is reliable |
| Terminal / iTerm | unsupported high-risk | disabled | off | disabled | denylisted; command prompts must never get autocomplete during MVP |
| Password managers | unsupported high-risk | disabled | off | disabled | denylisted: Apple Passwords, Keychain Access, 1Password, Bitwarden, Dashlane, LastPass |
| System Settings | unsupported high-risk | disabled | off | disabled | denylisted; settings and permission panes are not writing targets |
| Unknown apps | unsupported by default | disabled | off | disabled | blocked unless an explicit profile and smoke proof are added |

Run:

```bash
./script/manual_smoke_status.sh --require-all
```

TextEdit, Notes, Chrome, and Codex must have full accept proof. Obsidian may
pass as limited proof when CodeMirror does not expose caret bounds and detached
suggestions are suppressed instead of shown. Mail, Safari, Slack, VS Code, and
Cursor must prove diagnostics-only blocking. Atlas, Terminal, and 1Password
must prove unsupported-app blocking.
