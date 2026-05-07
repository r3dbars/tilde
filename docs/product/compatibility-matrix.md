# Compatibility Matrix

Current compatibility stance for the lab build.

After changing placement or key handling, treat recorded proof as stale until
the manual smoke status is refreshed from the current build.

For screenshot-backed app-by-app grades and gaps, use
[App Proof Matrix](app-proof-matrix.md).

## Update Map

When code lands, update these surfaces in the same PR:

| Change | Required docs/scripts |
| --- | --- |
| New or changed real-app support | `docs/product/compatibility-matrix.md`, `docs/product/app-proof-matrix.md`, `docs/product/manual-smoke-checklist.md`, and `script/real_app_smoke.sh` if the path is repeatable. |
| New manual proof | append `docs/product/manual-smoke-runs.md`, update scorecard visual rows, then run `script/manual_smoke_status.sh --strict`. |
| Placement screenshot proof | add a PNG under `docs/product/visual-placement-screenshots/`, link it from the scorecard, then run `script/check_visual_placement_evidence.sh`. |
| Anchor ladder behavior | update the anchor-source rows in `manual-smoke-checklist.md` and keep `caret-locked-research-queue.md` checked only for implemented behavior. |
| Compatibility learning or nudges | update `docs/product/eval-and-tracing.md` and `script/compatibility_self_healing_report.py`. |
| Permission or unsupported-app behavior | update `manual-smoke-checklist.md`; use `script/no_accessibility_smoke.sh` for the no-AX case. |

| App | Status | Render | Insert | Proof |
| --- | --- | --- | --- | --- |
| TextEdit | supported | inline, mirror fallback | AX selected text, value fallback | current default, multiline, and wrapped-line strict visual smoke rows |
| Notes | supported | inline, mirror fallback | key events only | requires title, body, and checklist proof labels |
| Obsidian | supported | synthetic caret mirror, no detached fallback | AX then key events, key fallback | prior CodeMirror smoke pass exists but needs fresh screenshot-backed current proof; detached whole-editor anchors stay suppressed |
| Chrome | supported for local text fields and local editor fixtures | synthetic inline, mirror fallback | key events, AX value fallback | repeatable textarea, contenteditable, editor-like, Monaco-like, ProseMirror-like, and chat-like no-submit fixture commands with screenshot-backed proof labels |
| Codex | dogfood target | synthetic inline caret, no detached fallback | AX value replacement, key fallback | prior manual pass is stale for this gate; current one-word no-submit proof pending |
| Claude Code | dogfood target | synthetic inline caret, no detached fallback | key events, AX fallback | pending manual smoke pass |
| Claude desktop | dogfood target | synthetic inline caret, no detached fallback | AX value replacement | prior manual pass is stale for this gate; current one-word no-submit proof pending |
| Mail | diagnostics only | disabled | disabled | blocked until safe compose adapter exists |
| Atlas | diagnostics only | disabled | disabled | focused AX is reliable enough to collect diagnostics; suggestions stay blocked until Atlas has app-specific proof |

Run:

```bash
./script/manual_smoke_status.sh --strict
```

TextEdit, Notes title/body/checklist, Obsidian, and Chrome must have full
accept proof. Codex, Claude Code, and Claude desktop must have one-word
no-submit proof before they can graduate; full accept stays disabled in prompt
apps until separate full-accept no-submit proof exists. Screenshot-backed visual proof is
also enforced by strict mode, so Codex, Obsidian, Notes, Claude Code, and Claude
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

## Anchor Source Proof

| Source | Current support stance | Proof path |
| --- | --- | --- |
| `caret` | Supported when AX caret geometry is trusted. | TextEdit rows; more native app variants still need current proof. |
| `synthetic-caret` | Supported for profiled browser, editor, and prompt surfaces when the synthetic estimate is stable. | Chrome fixtures are strongest; Obsidian, Codex, Claude Code, and Claude desktop still need current real-app proof. |
| `line` | Pending. | Add proof only after line-number or line-bounds capture lands. |
| `field` | Diagnostics or explicit profile fallback only. | Requires a profile that allows field anchors and a trace showing no whole-editor drift. |
| `window` | Diagnostics only. | Do not treat window anchoring as normal typing support. |
| `none`/off | Supported safety fallback. | Unsupported-app, sensitive-field, detached-suppression, and no-Accessibility checks. |
