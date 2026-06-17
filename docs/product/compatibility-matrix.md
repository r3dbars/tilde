# Compatibility Matrix

Current compatibility stance for the lab build.

After changing placement or key handling, treat recorded proof as stale until
the manual smoke status is refreshed from the current build.

Simple current truth:

- Supported means current proof is green, not that the app works everywhere.
- Partial means the lane may be useful for proof, but not broad tester use.
- Blocked means suggestions and insertion stay off until named proof exists.
- Prompt apps are word-only unless separate no-submit full-accept proof exists.

For screenshot-backed app-by-app grades and gaps, use
[App Proof Matrix](app-proof-matrix.md).

| App | Status | Render | Insert | Undo/recoverability | Proof |
| --- | --- | --- | --- | --- | --- |
| TextEdit | supported target; needs current-head refresh when strict smoke is red | inline, mirror fallback | AX selected text, value fallback | native single-edit proof lane; app rollback is degraded fallback | recorded manual smoke pass can go stale after app-code changes |
| Notes | supported target; split proof required | inline, mirror fallback | verified AX first, delayed read-only recheck, key fallback | degraded until title/body/checklist undo proof graduates beyond app rollback | title, body, and checklist proof recorded as separate labels |
| Obsidian | supported target when current proof is green | synthetic caret mirror, no detached fallback | AX then key events, key fallback | degraded until CodeMirror undo proof is native single-edit | several lanes are stale or pending; detached whole-editor anchors stay suppressed |
| Chrome | supported target for local textarea/contenteditable fixtures only; public pages and production browser apps are blocked until proof | synthetic inline, mirror fallback | key events, AX value fallback | native single-edit proof lane for local fixtures; hosted surfaces blocked | local textarea/contenteditable fixture commands have screenshot-backed labels; public/editor/chat/browser rows remain proof-only or blocked |
| Browser webmail | blocked; needs explicit proof | disabled | disabled | unavailable | Gmail, Outlook, Fastmail, iCloud, Yahoo, and other browser email compose surfaces are production browser surfaces; local fixtures do not count |
| Codex | proof-gated prompt target | synthetic inline caret, no detached fallback | AX value replacement, key fallback | yellow for the exact proven default composer | recorded strict visual one-word and full-accept no-submit proof; other prompt layouts stay blocked until separate current proof exists |
| Claude Code | proof-only terminal-host target | synthetic inline caret, no detached fallback | verified AX, hardware key events, Unicode key events, then proof-only verified paste fallback for typeable one-word accepts | unavailable for direct bundle; terminal-host proof needed | recorded current strict visual one-word no-submit Terminal and iTerm2 proof; Ghostty displays and captures Tab, and native screen-file proof now confirms the correct prompt stays unchanged, but insertion still fails closed so it stays unclaimed; direct `com.anthropic.claude-code` bundle remains diagnostics-only because real typing happens in a terminal host |
| Claude desktop | proof-only prompt target | synthetic inline caret, no detached fallback | AX value replacement | degraded one-word only until no-submit undo proof exists | current same-baseline screenshot-backed one-word no-submit proof recorded; normal beta use and more prompt layouts remain blocked |
| Mail | diagnostics only | disabled | disabled | unavailable | blocked until safe compose adapter exists |
| Atlas | unsupported | disabled | disabled | unavailable | blocked until focused AX element is reliable |

## Focused Graduation Queue

These are the next compatibility lanes after the current
TextEdit/Notes/Obsidian/Chrome fixture proof. The decision is intentionally
conservative: no surface moves up without current-head screenshot evidence,
safe Tab behavior, sensitive-field suppression, verified insertion, and
undo/recovery proof. Hosted, sendable, prompt, terminal, and private fields stay
guarded until their exact proof exists.

| Surface | Decision | Current proof state | Required next proof |
| --- | --- | --- | --- |
| Apple Pages documents | candidate | No exact Pages proof yet; current runtime would use the generic Accessibility path. Pages is installed locally as `com.apple.iWork.Pages`. | Disposable Pages document body proof for same-line placement, one-word Tab, full accept, verified insertion, native undo, and no suggestions in title/sidebar/comment/share fields. |
| LibreOffice Writer documents | candidate | No exact Writer proof yet; current runtime would use the generic Accessibility path. LibreOffice is installed locally as `org.libreoffice.script`. | Disposable Writer document body proof for caret placement, one-word Tab, verified insertion, undo/recovery, and no suggestions in menus, dialogs, find, save, or export fields. |
| Safari local textarea/contenteditable fixtures | blocked | Safari stays disabled until WebKit local fixture proof exists. | Mirror the Chrome local textarea/contenteditable proof in Safari with strict screenshots, safe Tab, verified insertion, undo/recovery, and sensitive-field suppression. No public pages or hosted apps. |
| Focused local writing apps | candidate | No exact app proof yet; good next candidates are Bear, Drafts, iA Writer, Ulysses, Typora, or CotEditor when installed. | Pick one installed local writing app, capture bundle/version, and prove disposable-document placement, one-word Tab, verified insertion, undo/recovery, and no suggestions in library/search/title fields. |
| Google Docs in Chrome | blocked | Browser policy suppresses `docs.google.com` as `unsupported-browser-surface`. | Disposable real-service document proof for placement, one-word Tab, insertion verification, undo/recovery, and no sensitive-field leak. Local fixtures do not count. |

Guarded later lanes:

| Surface | Decision | Why it stays later |
| --- | --- | --- |
| Notion browser or desktop | blocked | Useful, but workspace text is private and local ProseMirror-like fixtures do not count. Needs disposable-page proof. |
| Chrome production text fields | blocked | Public pages and production browser apps no longer count as beta-safe. Needs disposable production-page proof and must avoid search, address, payment, and send fields. |
| Real Monaco and CodeMirror editors | blocked | Forced/local editor fixtures do not graduate production editors. Command palettes, terminals, and AI composers stay blocked. |
| Codex and Claude desktop layouts | guarded dogfood/proof lanes | Prompt apps need exact one-word no-submit proof for each layout; do not treat dogfood proof as broad writing support. |
| Mail, browser webmail, Messages, Slack, Discord, terminals | blocked, diagnostics-only, or proof-only | Sendable/private/terminal surfaces stay off unless exact no-send/no-submit proof exists for the app, field, and layout. |

Run:

```bash
./script/manual_smoke_status.sh --strict
```

TextEdit, Notes title/body/checklist, Obsidian default/theme/pane/long-note,
and Chrome local textarea/contenteditable fixtures must have current proof.
Codex, Claude Code, Claude desktop, chat apps, Mail, terminals, production
browser apps, and public browser pages stay proof-only or blocked. Screenshot-backed visual proof is also
enforced by strict mode, so risky rows do not look finished just because
insertion passed. A detached-suppression Obsidian row is useful safety evidence,
but it is not enough for a green manual smoke status.
The status command also prints
remaining sub-10 scorecard gaps so release risk is visible beside the smoke
proof. Strict mode also runs the screenshot evidence gate and fails on stale
screenshot rows, unreferenced screenshot files, or below-target visual rows that
are not plainly marked `Pending`.

Chrome's yellow profile is not a blanket browser promise. The runtime only
allows local textarea/contenteditable fixtures. Hosted Google Docs, Notion,
browser webmail, Slack, Discord, ChatGPT, public pages, production browser apps,
and developer editors stay blocked with the trace reason `unsupported-browser-surface` until
those surfaces have their own screenshot and no-submit proof.

Run `./script/check_visual_placement_evidence.sh --require-all` when every row
in the visual placement audit should have screenshot-backed proof. Keep any
below-target row explicitly marked `Pending` until the proof is strong enough to
raise it.
