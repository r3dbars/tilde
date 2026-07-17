# Compatibility Matrix

Current compatibility stance for the lab build.

After changing placement or key handling, treat recorded proof as stale until
the manual smoke status is refreshed from the current build.

Current Phase 2 product decision:

- Suggestions are experimentally default-on in ordinary writing fields across known apps and real websites; this is not a support or proof claim.
- Password, payment, login, private-search, address-bar, developer-tool, and other sensitive fields remain blocked before any suggestion request.
- Mail, Safari, Slack, Telegram, Notion, Discord, VS Code, Cursor, ChatGPT, and Atlas now run with per-app fallback plans and a visible kill switch.
- Three consecutive insertion verification failures demote that app to one-word acceptance; six pause it for the session. The user can resume it in Settings.
- Personal writing capture remains local, opt-in, and separately privacy-gated. Enabling suggestions does not enable capture.

For screenshot-backed app-by-app grades and gaps, use
[App Proof Matrix](app-proof-matrix.md).

| App | Status | Render | Insert | Undo/recoverability | Proof |
| --- | --- | --- | --- | --- | --- |
| TextEdit | supported target; needs current-head refresh when strict smoke is red | inline, mirror fallback | AX selected text, value fallback | native single-edit proof lane; app rollback is degraded fallback | recorded manual smoke pass can go stale after app-code changes |
| Notes | supported target; split proof required | inline, mirror fallback | verified AX first, delayed read-only recheck, key fallback | degraded until title/body/checklist undo proof graduates beyond app rollback | title, body, and checklist proof recorded as separate labels |
| Obsidian | supported target when current proof is green | synthetic caret mirror, no detached fallback | AX then key events, key fallback | degraded until CodeMirror undo proof is native single-edit | several lanes are stale or pending; detached whole-editor anchors stay suppressed |
| Chrome | experimental broad browser path | synthetic inline, mirror fallback | key events, AX value fallback | native single-edit target | local fixtures have proof; real-site proof is pending; sensitive browser surfaces stay blocked |
| Browser webmail | experimental ordinary compose path | browser profile render plan | browser profile insertion plan | host-dependent, auto-demoted on failures | real-service no-send proof is pending; personal capture remains blocked |
| Codex | proof-gated prompt target | synthetic inline caret, no detached fallback | AX value replacement, key fallback | yellow for the exact proven default composer | recorded strict visual one-word and full-accept no-submit proof; other prompt layouts stay blocked until separate current proof exists |
| Claude Code | proof-only terminal-host target | synthetic inline caret, no detached fallback | verified AX, hardware key events, Unicode key events, then proof-only verified paste fallback for typeable one-word accepts | unavailable for direct bundle; terminal-host proof needed | recorded current strict visual one-word no-submit Terminal and iTerm2 proof; Ghostty displays and captures Tab, and native screen-file proof now confirms the correct prompt stays unchanged, but insertion still fails closed so it stays unclaimed; direct `com.anthropic.claude-code` bundle remains diagnostics-only because real typing happens in a terminal host |
| Claude desktop | proof-only prompt target | synthetic inline caret, no detached fallback | AX value replacement | degraded one-word only until no-submit undo proof exists | current same-baseline screenshot-backed one-word no-submit proof recorded; normal beta use and more prompt layouts remain blocked |
| Mail | experimental default-on | inline, mirror fallback | AX then key events, AX value fallback | native single-edit target | compose proof pending; secure detection and automatic demotion remain active |
| Safari | experimental default-on | inline, mirror fallback | AX then key events, AX value fallback | native single-edit target | real-site proof pending; sensitive browser fields remain blocked |
| Slack / Telegram / Discord | experimental default-on | inline, mirror fallback | AX then key events, key-event fallback | app rollback | no-send proof pending; accepted control characters are blocked |
| Notion | experimental default-on | synthetic inline | key events | degraded | ProseMirror caret geometry is a known real risk; disposable-page proof pending |
| VS Code / Cursor | experimental default-on, last-resort floating UI | floating mirror | key events | degraded | Monaco geometry is a known real risk; auto-demotion is mandatory |
| ChatGPT / Atlas | experimental default-on | synthetic inline, mirror fallback | AX value replacement | app rollback | full accept is available, but word-only command filtering and control-character blocking remain active; no-submit proof pending |

## Focused Graduation Queue

These rows track proof maturity, not whether the experimental runtime path is
enabled. Pending proof stays visible even when the product decision enables a
surface behind automatic demotion and a per-app kill switch.

| Surface | Decision | Current proof state | Required next proof |
| --- | --- | --- | --- |
| Apple Pages documents | candidate | No exact Pages proof yet; current runtime would use the generic Accessibility path. Pages is installed locally as `com.apple.iWork.Pages`. | Disposable Pages document body proof for same-line placement, one-word Tab, full accept, verified insertion, native undo, and no suggestions in title/sidebar/comment/share fields. |
| LibreOffice Writer documents | candidate | No exact Writer proof yet; current runtime would use the generic Accessibility path. LibreOffice is installed locally as `org.libreoffice.script`. | Disposable Writer document body proof for caret placement, one-word Tab, verified insertion, undo/recovery, and no suggestions in menus, dialogs, find, save, or export fields. |
| Safari local textarea/contenteditable fixtures | enabled, proof pending | Safari uses the WebKit Accessibility plan while sensitive browser surfaces stay blocked. | Mirror the Chrome fixture proof with strict screenshots, safe Tab, verified insertion, and undo/recovery. |
| Focused local writing apps | candidate | No exact app proof yet; good next candidates are Bear, Drafts, iA Writer, Ulysses, Typora, or CotEditor when installed. | Pick one installed local writing app, capture bundle/version, and prove disposable-document placement, one-word Tab, verified insertion, undo/recovery, and no suggestions in library/search/title fields. |
| Google Docs in Chrome | enabled, proof pending | Ordinary hosted writing surfaces are allowed by default. | Disposable real-service document proof for placement, Tab acceptance, insertion verification, undo/recovery, and no sensitive-field leak. |

Guarded later lanes:

| Surface | Decision | Why it stays later |
| --- | --- | --- |
| Notion browser or desktop | enabled, proof pending | ProseMirror geometry remains risky; use disposable text and keep personal capture off. |
| Chrome production text fields | enabled, proof pending | Sensitive surface classification remains the hard safety boundary. |
| Real Monaco and CodeMirror editors | enabled with degraded fallback | Forced/local editor fixtures do not prove production geometry; automatic demotion is mandatory. |
| Codex and Claude desktop layouts | guarded dogfood/proof lanes | Prompt apps need exact one-word no-submit proof for each layout; do not treat dogfood proof as broad writing support. |
| Mail, browser webmail, Slack, Discord | enabled, proof pending | Control-character blocking, sensitive-field suppression, auto-demotion, and the per-app pause switch replace proof gating for this experiment. |

Run:

```bash
./script/manual_smoke_status.sh --strict
```

TextEdit, Notes title/body/checklist, Obsidian default/theme/pane/long-note,
and Chrome local textarea/contenteditable fixtures must have current proof.
Codex, Claude Code, and Claude desktop retain their specialized proof lanes;
newly enabled chat, Mail, and production-browser rows remain proof-pending. Screenshot-backed visual proof is also
enforced by strict mode, so risky rows do not look finished just because
insertion passed. A detached-suppression Obsidian row is useful safety evidence,
but it is not enough for a green manual smoke status.
The status command also prints
remaining sub-10 scorecard gaps so release risk is visible beside the smoke
proof. Strict mode also runs the screenshot evidence gate and fails on stale
screenshot rows, unreferenced screenshot files, or below-target visual rows that
are not plainly marked `Pending`.

Chrome's yellow profile is an experiment, not a blanket support promise. The
runtime now allows ordinary real-site writing fields, while sensitive browser
surfaces remain hard-blocked. Local fixture proof does not count as production
proof, and each newly opened surface stays pending until its own screenshot,
insertion, undo, and no-send/no-submit evidence exists.

Run `./script/check_visual_placement_evidence.sh --require-all` when every row
in the visual placement audit should have screenshot-backed proof. Keep any
below-target row explicitly marked `Pending` until the proof is strong enough to
raise it.
