# Compatibility Matrix

Current compatibility stance for the lab build.

After changing placement or key handling, treat recorded proof as stale until
the manual smoke status is refreshed from the current build.

For screenshot-backed app-by-app grades and gaps, use
[App Proof Matrix](app-proof-matrix.md).

| App | Status | Render | Insert | Proof |
| --- | --- | --- | --- | --- |
| TextEdit | supported | inline, mirror fallback | AX selected text, value fallback | recorded manual smoke pass |
| Notes | supported | inline, mirror fallback | verified AX first, delayed read-only recheck, key fallback | title, body, and checklist proof recorded as separate labels |
| Obsidian | supported | synthetic caret mirror, no detached fallback | AX then key events, key fallback | recorded CodeMirror smoke pass with two verified accepts; detached whole-editor anchors stay suppressed |
| Chrome | supported for local text fields and local editor fixtures | synthetic inline, mirror fallback | key events, AX value fallback | repeatable textarea, contenteditable, editor-like, Monaco-like, and ProseMirror-like fixture commands with screenshot-backed proof labels |
| Codex | dogfood target | synthetic inline caret, no detached fallback | AX value replacement, key fallback | prior manual pass is stale for this gate; current one-word no-submit proof pending |
| Claude Code | diagnostics only | disabled | disabled | pending terminal-host adapter; the `com.anthropic.claude-code` bundle is not the live typing surface |
| Claude desktop | dogfood target | synthetic inline caret, no detached fallback | AX value replacement | current same-baseline screenshot-backed one-word no-submit proof recorded; more prompt layouts pending |
| Mail | diagnostics only | disabled | disabled | blocked until safe compose adapter exists |
| Atlas | unsupported | disabled | disabled | blocked until focused AX element is reliable |

Run:

```bash
./script/manual_smoke_status.sh --strict
```

TextEdit, Notes title/body/checklist, Obsidian, and Chrome must have full
accept proof. Codex must have one-word no-submit proof before it can graduate;
Claude Code needs a separate terminal-host adapter before it can even enter
the prompt proof lane. Full accept stays disabled in prompt apps until separate
full-accept no-submit proof exists. Screenshot-backed visual proof is also
enforced by strict mode, so Codex, Obsidian, Notes, Claude Code, and Claude
desktop do not look finished just because insertion passed. A
detached-suppression Obsidian row is useful safety evidence, but it is not
enough for a green manual smoke status. The status command also prints
remaining sub-10 scorecard gaps so release risk is visible beside the smoke
proof. Strict mode also runs the screenshot evidence gate and fails on stale
screenshot rows, unreferenced screenshot files, or below-target visual rows that
are not plainly marked `Pending`.

Run `./script/check_visual_placement_evidence.sh --require-all` when every row
in the visual placement audit should have screenshot-backed proof. Keep any
below-target row explicitly marked `Pending` until the proof is strong enough to
raise it.
