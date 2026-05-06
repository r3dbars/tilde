# Compatibility Matrix

Current compatibility stance for the lab build.

After changing placement or key handling, treat recorded proof as stale until
the manual smoke status is refreshed from the current build.

| App | Status | Render | Insert | Proof |
| --- | --- | --- | --- | --- |
| TextEdit | supported | inline, mirror fallback | AX selected text, value fallback | recorded manual smoke pass |
| Notes | supported | inline, mirror fallback | key events, AX selected text fallback | recorded manual smoke pass |
| Obsidian | supported only when caret bounds are available | mirror | AX then key events, key fallback | detached CodeMirror suggestions are suppressed because whole-editor anchors look wrong |
| Chrome | supported for local text fields | mirror | AX value replacement, key fallback | recorded local textarea pass |
| Codex | dogfood target | synthetic inline caret, no detached fallback | key events, AX fallback | pending manual smoke pass |
| Claude Code | dogfood target | synthetic inline caret, no detached fallback | key events, AX fallback | pending manual smoke pass |
| Mail | diagnostics only | disabled | disabled | blocked until safe compose adapter exists |
| Atlas | unsupported | disabled | disabled | blocked until focused AX element is reliable |

Run:

```bash
./script/manual_smoke_status.sh --require-all
```

TextEdit, Notes, Chrome, Codex, and Claude Code must have full accept proof.
Obsidian may pass as limited proof when CodeMirror does not expose caret bounds
and detached suggestions are suppressed instead of shown.
