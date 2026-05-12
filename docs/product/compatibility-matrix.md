# Compatibility Matrix

Current compatibility stance for the lab build.

After changing placement or key handling, treat recorded proof as stale until
the manual smoke status is refreshed from the current build.

For screenshot-backed app-by-app grades and gaps, use
[App Proof Matrix](app-proof-matrix.md).

| App | Status | Render | Insert | Undo/recoverability | Proof |
| --- | --- | --- | --- | --- | --- |
| TextEdit | supported | inline, mirror fallback | AX selected text, value fallback | native single-edit proof lane; app rollback is degraded fallback | recorded manual smoke pass |
| Notes | supported | inline, mirror fallback | verified AX first, delayed read-only recheck, key fallback | degraded until title/body/checklist undo proof graduates beyond app rollback | title, body, and checklist proof recorded as separate labels |
| Obsidian | supported | synthetic caret mirror, no detached fallback | AX then key events, key fallback | degraded until CodeMirror undo proof is native single-edit | recorded CodeMirror smoke pass with two verified accepts; detached whole-editor anchors stay suppressed |
| Chrome | supported for local text fields and local editor fixtures; hosted Google Docs, Notion, Slack, and Discord are blocked until proof | synthetic inline, mirror fallback | key events, AX value fallback | native single-edit proof lane for local fixtures; hosted surfaces blocked | repeatable textarea, contenteditable, editor-like, Monaco-like, and ProseMirror-like fixture commands with screenshot-backed proof labels |
| Codex | dogfood target | synthetic inline caret, no detached fallback | AX value replacement, key fallback | degraded one-word only until no-submit undo proof exists | recorded strict visual one-word no-submit proof; current-head refresh needed after the latest app-code change; full accept stays disabled until separate full-accept no-submit proof exists |
| Claude Code | proof-only terminal-host target | synthetic inline caret, no detached fallback | terminal host Paste menu through AX | unavailable for direct bundle; terminal-host proof needed | recorded strict visual one-word no-submit proof; current-head refresh needed after the latest app-code change; direct `com.anthropic.claude-code` bundle remains diagnostics-only because real typing happens in a terminal host |
| Claude desktop | dogfood target | synthetic inline caret, no detached fallback | AX value replacement | degraded one-word only until no-submit undo proof exists | current same-baseline screenshot-backed one-word no-submit proof recorded; more prompt layouts pending |
| Mail | diagnostics only | disabled | disabled | unavailable | blocked until safe compose adapter exists |
| Atlas | unsupported | disabled | disabled | unavailable | blocked until focused AX element is reliable |

Run:

```bash
./script/manual_smoke_status.sh --strict
```

TextEdit, Notes title/body/checklist, Obsidian, and Chrome must have full
accept proof. Codex, Claude Code, and Claude desktop require one-word
no-submit proof and keep full accept disabled until separate full-accept
no-submit proof exists. Screenshot-backed visual proof is also enforced by
strict mode, so prompt, editor, and native-app rows do not look finished just
because insertion passed. A
detached-suppression Obsidian row is useful safety evidence, but it is not
enough for a green manual smoke status. The status command also prints
remaining sub-10 scorecard gaps so release risk is visible beside the smoke
proof. Strict mode also runs the screenshot evidence gate and fails on stale
screenshot rows, unreferenced screenshot files, or below-target visual rows that
are not plainly marked `Pending`.

Chrome's yellow profile is not a blanket browser promise. The runtime blocks
hosted Google Docs, Notion, Slack, and Discord from fingerprint/window metadata
with the trace reason `unsupported-browser-surface` until those production
surfaces have their own screenshot and no-submit proof.

Run `./script/check_visual_placement_evidence.sh --require-all` when every row
in the visual placement audit should have screenshot-backed proof. Keep any
below-target row explicitly marked `Pending` until the proof is strong enough to
raise it.
