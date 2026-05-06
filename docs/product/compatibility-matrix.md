# Compatibility Matrix

Current compatibility stance for the lab build.

After changing placement or key handling, treat recorded proof as stale until
the manual smoke status is refreshed from the current build.

| App | Status | Render | Insert | Proof |
| --- | --- | --- | --- | --- |
| TextEdit | supported | inline, mirror fallback | AX selected text, value fallback | recorded manual smoke pass |
| Notes | supported | inline, mirror fallback | key events only | requires title, body, and checklist proof labels |
| Obsidian | supported | synthetic caret mirror, no detached fallback | AX then key events, key fallback | recorded CodeMirror smoke pass with two verified accepts; detached whole-editor anchors stay suppressed |
| Chrome | supported for local text fields and local editor fixtures | synthetic inline, mirror fallback | key events, AX value fallback | repeatable textarea, contenteditable, editor-like, Monaco-like, and ProseMirror-like fixture commands with screenshot-backed proof labels |
| Codex | dogfood target | synthetic inline caret, no detached fallback | AX value replacement, key fallback | recorded manual smoke pass |
| Claude Code | dogfood target | synthetic inline caret, no detached fallback | key events, AX fallback | pending manual smoke pass |
| Claude desktop | dogfood target | synthetic inline caret, no detached fallback | AX value replacement | recorded manual smoke pass |
| Mail | diagnostics only | disabled | disabled | blocked until safe compose adapter exists |
| Atlas | unsupported | disabled | disabled | blocked until focused AX element is reliable |

Run:

```bash
./script/manual_smoke_status.sh --strict
```

TextEdit, Notes title/body/checklist, Obsidian, Chrome, Codex, Claude Code, and
Claude desktop must have full accept proof. Chrome proof should include visual
screenshot evidence when placement changes. Real-app screenshot gaps are listed
separately from insertion proof so Codex, Obsidian, Notes, Claude Code, and
Claude desktop do not look finished just because Tab insertion passed. A
detached-suppression Obsidian row is useful safety evidence, but it is not
enough for a green manual smoke status. The status command also prints
remaining sub-10 scorecard gaps so release risk is visible beside the smoke
proof.

Run `./script/check_visual_placement_evidence.sh --require-all` when every row
in the visual placement audit should have screenshot-backed proof.
