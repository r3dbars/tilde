# App Proof Matrix

Screenshot-backed proof for the current cross-app typing loop.

This is not a support promise. It is the honest proof state for the lab build:
what has a screenshot, what has insertion proof, and what still needs a real
manual pass.

Source docs: `manual-smoke-runs.md`,
`deep-dive-scorecard-2026-05-06.md`,
`deep-research-autocomplete-scorecard-2026-05-07.md`, and the committed
screenshots in `visual-placement-screenshots/`.

Grades are evidence grades, not product grades.

Phase 2 deliberately removed proof as a runtime prerequisite for ordinary
writing fields. Mail, Safari, Slack, Telegram, Notion, Discord, VS Code,
Cursor, ChatGPT, Atlas, and ordinary hosted websites are experimental
default-on paths even while their evidence stays pending here. Sensitive-field
suppression remains hard-blocking; three consecutive insertion failures demote
an app to one-word acceptance and six pause it for the session. Personal
writing capture remains separately opt-in and browser capture stays blocked.

## Executable Target Gates

The target state is now machine-checked:

```bash
./script/check_score_targets.sh
./script/scorecard_goal_loop.sh --iterations 10
```

Current result: the target gate still fails, and that is correct. The latest
app-code source change makes `./script/manual_smoke_status.sh --strict` report
29 current-head proof gaps. Rows below describe recorded evidence; they should
not be read as current-head support unless the strict gate says so. Every non-A
row below must stay non-A until the required screenshot-backed and accept-proof
evidence exists in the repo. The proof manifest also keeps variant-incomplete
A- rows as `partial`, even when they have a passing live smoke slice.

## Focused Graduation Decisions

| Surface | Decision | Why |
| --- | --- | --- |
| Google Docs in Chrome | enabled, proof pending | Ordinary hosted writing surfaces are open; disposable real-service placement, insertion, undo, and sensitive-field proof is still missing. |
| Notion browser or desktop | enabled, proof pending | The synthetic-caret ProseMirror path is live with degraded undo and automatic demotion; disposable-page proof is missing. |
| Slack browser or desktop | enabled, proof pending | Control-character filtering prevents acceptance from inserting send keys; exact no-send proof is still missing. |
| Discord browser or desktop | enabled, proof pending | Control-character filtering prevents acceptance from inserting send keys; exact no-send proof is still missing. |
| Mail compose | enabled, proof pending | Secure-field suppression remains mandatory and native single-edit undo is the target; compose proof is missing. |
| Browser webmail | enabled, proof pending | Ordinary compose fields are open, personal capture remains blocked, and exact no-send proof is missing. |
| Browser ChatGPT | enabled, proof pending | Full acceptance is available with word-only command filtering and unconditional control-character blocking; exact no-submit proof is missing. |
| Prompt-app full accept | proof-only | Codex default composer has exact separate no-submit screenshot and insertion proof; other prompt/chat full-accept claims remain blocked. |
| Terminal-host Claude Code | proof-only (dogfood) | Default-on word-only dogfood lane: marker-gated, shell-command guarded, verified one-word no-submit accepts on Terminal and iTerm2. Ghostty insertion remains unproven, full accept stays blocked, and no terminal host counts as beta-safe normal writing support. |
| Chrome production text fields | enabled, proof pending | Public proof pages and production browser apps do not count as current proof; sensitive browser surfaces remain blocked. |
| Claude desktop layouts | proof-only | Default one-word no-submit proof exists, but normal beta use, layout variants, and full accept remain blocked. |
| Codex layouts | proof-only | Default one-word and full-accept no-submit proof is recorded for the Codex composer; normal beta use and broader layouts remain gated. |
| Obsidian long notes | supported | Current-head long-note proof now has bounded strict screenshot evidence, viewport-end repair, verified Tab insertion, and accepted-and-kept behavior; broader vault variance still keeps general Obsidian support yellow. |
| Real Monaco and CodeMirror editors | enabled with degraded fallback | Forced local fixtures are useful evidence, but official/default Monaco and current CodeMirror geometry proof are not complete. |

| Surface | Grade | Screenshot proof | Accept proof | Current read | Evidence gap |
| --- | --- | --- | --- | --- | --- |
| TextEdit | A | [textedit-inline.png](visual-placement-screenshots/textedit-inline.png) | Bounded strict visual smoke refreshed at 2026-05-12T05:06:55Z with 2 verified accepts and current app fingerprint proof. Native single-edit proof now has a separate `--native-undo-proof` lane. | Strongest native-app proof. Ghost text is readable, on the same line, and Tab/full accept verifies against the configured shortcut. The smoke lane now uses a unique disposable file, targets that exact AX window/title even when old TextEdit windows are restored, and dismisses TextEdit's native inline completion before waiting for Autocomplete Lab. Native proof is only counted when `acceptedInsertionUndone` records `undoMechanism=nativeSingleEdit`; app rollback is recoverable but degraded. | More dark/light document variants and fresh native undo proof rows. |
| Chrome local textarea/contenteditable fixtures | A | [chrome-textarea.png](visual-placement-screenshots/chrome-textarea.png), [chrome-contenteditable.png](visual-placement-screenshots/chrome-contenteditable.png) | 2 verified accepts per local fixture at 2026-05-12T09:12:22Z and 2026-05-12T09:12:38Z. | Only local textarea/contenteditable fixtures count as beta-safe Chrome support. Public pages, production browser apps, chat-like fixtures, editor-like fixtures, hosted docs, Monaco, CodeMirror, and ProseMirror stay proof-only or blocked. | More local boring-text variants would be useful, but public or production pages do not raise the beta-safe scope. |
| Browser editor fixtures | A- | [chrome-editor-like.png](visual-placement-screenshots/chrome-editor-like.png), [chrome-monaco-like.png](visual-placement-screenshots/chrome-monaco-like.png), [chrome-prosemirror-like.png](visual-placement-screenshots/chrome-prosemirror-like.png), [chrome-monaco-real.png](visual-placement-screenshots/chrome-monaco-real.png), [chrome-prosemirror-real.png](visual-placement-screenshots/chrome-prosemirror-real.png) | 2 verified accepts per fixture in the manual smoke log, including recorded `monaco-real` and `prosemirror-real` forced-renderer proof from 2026-05-12T09:13:45Z and 2026-05-12T09:14:02Z, plus normal-Chrome `prosemirror-real-default` proof at 2026-05-12T09:19:46Z. The 2026-05-12 `codemirror-official` attempt now fails closed before Chrome typing when SteadyType is missing macOS Accessibility. | Good recorded proof for CodeMirror-like, Monaco-like, ProseMirror-like, real Monaco, and real ProseMirror under isolated forced-renderer Chrome. Normal Chrome default AX is recorded for real ProseMirror after the same-app focus churn fix. Normal Chrome default Monaco is not claimed. The official-demo harness now checks Accessibility before runtime readiness, allows a longer cold MLX warmup, uses isolated Chrome/DevTools setup where available, and blocks safely when the focused editor cannot be verified. | Monaco default-AX, current-head `codemirror-official`, `monaco-official`, and production editor proof still need verified insertion, not just display. |
| Chrome chat-like composer | A | [chrome-chat-like.png](visual-placement-screenshots/chrome-chat-like.png) | Local chat-like fixture has 2 verified accepts with strict visual trace evidence and submit count zero; bounded HTTP browser-chat harness requires one-word Tab accept with submit, send-key collision, prompt mutation, and wrong-context counters at zero | This is strong proof for the disposable local chat fixture plus the disposable HTTP browser-chat harness only. Browser-hosted ChatGPT, Slack, and Discord are experimentally enabled but remain production-proof pending. | Broad chat apps still need their own exact real-service proof before a support claim. |
| Codex | A- | [codex-inline.png](visual-placement-screenshots/codex-inline.png) | Current bounded strict visual smoke at 2026-05-26T02:06:11Z has exactly 1 verified one-word accept, prompt no-submit confirmation, diagnostics lines 413817-413882, trace lines 28053-28056, app proof `app-sha256:6e1ce0e52d256ec0d038e62c7309a63ef833189758bcf324d458702df5667ac4`, and archive proof `archive-sha256:908f96e7df34df2981ed83fe9c4c45bc8098a340b77dfe203c8f34219445da15`. | Codex has a proof-only prompt lane: screenshot, one-word Tab accept, fast-path focus/accept guard proof, direct marked-composer insertion, insertion verification, and no submit in one trace slice. The helper now prefers a disposable prompt over unrelated focused Codex goal fields and keeps private draft backup/restore for real prompt drafts. It is not beta-safe normal writing support. Full accept remains disabled until a separate no-submit lane exists. | Add more prompt layouts before using this outside proof mode. |
| Obsidian | A- | [obsidian.png](visual-placement-screenshots/obsidian.png) | Bounded strict visual smoke is recorded for forced-renderer default history plus theme, pane, and long-note lanes. Fresh stock no-flags default proof is now a separate required row and must use `obsidian-stock`. | Real CodeMirror proof shows caret-bound synthetic mirror placement, strict screenshot evidence, Tab accept, and configured full accept in disposable vault notes for the proven lanes. The stock launch row prevents `--force-renderer-accessibility` proof from standing in for normal Obsidian support. | Run `AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh obsidian --manual-gate` and record `obsidian-stock`; then broaden vault layouts and hidden-caret edge cases. |
| Apple Notes title | A | [notes-title.png](visual-placement-screenshots/notes-title.png) | Bounded strict visual smoke refreshed at 2026-05-12T05:04:49Z with 2 verified accepts and current app fingerprint proof; same-slice `notes-title-undo` proof was added at 2026-05-12T05:20:17Z; short and long title variant rows were added at 2026-05-12T05:31:38Z and 2026-05-12T05:31:57Z. | Title proof is now separate from generic Notes evidence. The ghost is inline after the title caret, insertion verifies in the same bounded trace slice, Command-Z undo is recorded after the first accept, and the defined short/long title gate is green. | More real-world title layouts would be useful, but the defined Notes title proof gate is green. |
| Apple Notes body | A | [notes-body.png](visual-placement-screenshots/notes-body.png) | Bounded strict visual smoke refreshed at 2026-05-12T05:05:56Z with 2 verified accepts and current app fingerprint proof; same-slice `notes-body-undo` proof was added at 2026-05-12T05:20:38Z; short and long body rows were added at 2026-05-12T05:32:17Z and 2026-05-12T05:33:30Z. | Body proof is now separate from generic Notes evidence. The ghost is inline after the body caret, Option-Tab full accept verifies, suffix retention no longer misclassifies `dictation` as deleted, Command-Z undo is recorded after the first accept, and the defined short/long body gate is green. | More real-world body layouts would be useful, but the defined Notes body proof gate is green. |
| Apple Notes checklist | A | [notes-checklist.png](visual-placement-screenshots/notes-checklist.png) | Bounded strict visual smoke refreshed at 2026-05-12T05:06:15Z with 2 verified accepts and current app fingerprint proof; same-slice `notes-checklist-undo` proof was added at 2026-05-12T05:22:39Z; checked-item and long-row rows were added at 2026-05-12T05:33:50Z and 2026-05-12T05:34:10Z. | Checklist proof is now separate from generic Notes evidence. The screenshot shows a native Notes checklist circle on the same row as the typed smoke text and ghost text. The checklist undo lane records app rollback when available and falls back to native Command-Z only after the disposable checklist text is re-read as restored, and the defined checked-item/long-row gate is green. | More checklist styles would be useful, but the defined Notes checklist proof gate is green. |
| Claude Code | A- | [claude-code-terminal.png](visual-placement-screenshots/claude-code-terminal.png) | Current Terminal proof at 2026-05-25T13:56:48Z has exactly 1 verified one-word Tab accept with diagnostics lines 364600-364662 and trace lines 24701-24709. Current iTerm2 proof at 2026-05-25T15:34:16Z has exactly 1 verified one-word Tab accept with diagnostics lines 372371-372550, trace lines 24920-24930, visual `strict-complete`, prompt no-submit confirmation, app proof `app-sha256:c6811e3591a05730aac82cb2c0b2eaa625c28b2f067de1f7fd187cfc27870731`, and archive proof `archive-sha256:6c241fb4ffdf57cfe825818bd4f52a3871181d409328f7ec6350f667f6700387`. Ghostty reached visible phrase presentation and consumed Tab at 2026-05-25T16:12:56Z, but insertion failed closed on diagnostics lines 375775-375824 after AX, hardware key events, Unicode key events, and verified paste all failed to mutate the prompt. The latest current-head Ghostty run reaches prompt-row Tab acceptance and now reads Ghostty's copied screen dump file; the title-marked prompt screen confirms original text is still present and expected accepted text is absent, so Ghostty stays a verified fail-closed insertion gap. | Direct bundle support is still diagnostics-only because the installed `com.anthropic.claude-code` app is a background-only CLI helper. The proof-only terminal-host adapter maps supported terminal hosts to a virtual Claude Code profile only in explicit proof mode and blocks unmarked terminal sessions, shell prompts, command-shaped prompt lines, active agent output, stale marked scrollback, and multiline command buffers. Host-labeled proof commands exist, but terminal-host work is parked from beta readiness until core writing apps feel good. | Do not spend normal beta cycles here. Keep full accept disabled, keep Ghostty unclaimed until verified insertion exists, and treat any future terminal work as explicit research rather than product support. |
| Claude desktop | A- | [claude-desktop.png](visual-placement-screenshots/claude-desktop.png) | Bounded strict visual smoke at 2026-05-12T11:12:24Z with exactly 1 verified one-word accept, no prompt submit signal, and a current app/archive fingerprint match. | Real Claude desktop has a proof-only lane for same-baseline screenshot-backed synthetic-caret placement, Tab one-word accept, and no submit in one trace slice. Normal beta use remains blocked. The proof lane has separate commands for empty, long, wrapped, narrow, context, light, and dark prompt layouts. Full accept is still disabled. | Needs those layout rows recorded before using outside proof mode; no safe full-accept proof command exists yet. |

## Required Next Proof

1. Add native/local document proof before more prompt or send surfaces:
   Pages document body first, then LibreOffice Writer document body. Use
   disposable files only, require screenshot-backed placement, verified
   insertion, one-word Tab, full accept where safe, native undo/recovery, and
   no suggestions in title/sidebar/comment/share/dialog fields.
2. Add WebKit fixture proof without broadening browser claims:
   Safari local textarea and contenteditable fixtures should mirror the Chrome
   local fixture proof. Public pages, hosted apps, search/address/payment
   fields, and production browser apps still do not count.
3. Add one focused local writing app when installed:
   Bear, Drafts, iA Writer, Ulysses, Typora, or CotEditor are preferred because
   they are writing-first and non-send surfaces. Capture bundle/version first
   and use a disposable local document.
4. Add exact disposable real-service proof for Google Docs and Notion. Their
   runtime paths are open experimentally, but local fixtures, local harnesses,
   and public non-auth editor fixtures do not count as production proof.
5. Keep browser webmail, browser ChatGPT, Slack, Discord, Mail compose,
   terminal-hosted Claude Code, and prompt-app layout expansion guarded until
   exact no-send/no-submit proof exists for the app, field, and layout.

## Proof Rules

- Screenshot proof must link to a committed PNG in
  `docs/product/visual-placement-screenshots/`.
- Accept proof must show verified insertion, not just a visible suggestion.
- Prompt apps must prove one-word accept without submit before they can run in proof mode; they do not graduate into beta-safe normal use from that alone.
- Terminal-hosted Claude Code stays shell-command guarded so the terminal adapter cannot submit shell input, and host-labeled proof must not stand in for untested terminal hosts.
- Terminal-hosted Claude Code is a word-only dogfood lane, not a beta-safe
  writing surface; Terminal/iTerm2 proof rows and Ghostty placement evidence do
  not count as normal writing-app support, and full accept stays blocked.
- Prompt-app full accept needs its own separate full-accept no-submit proof.
- Real ChatGPT, Slack, Discord, browser webmail, Google Docs, and Notion require
  exact disposable real-service proof with screenshot-backed placement and verified insertion.
  Local fixtures, forced renderer fixtures, and browser-chat harness proof do
  not count for those production rows.
- Claude desktop full accept has no safe proof command yet; keep the product
  profile word-only until that dedicated lane exists and passes.
- Prompt-app proof must be one trace-level accept only and must not contain
  full-accept or field-send finalization signals.
- Local chat-like fixture proof and the bounded browser-chat harness do not
  remove browser-hosted ChatGPT, Slack, or Discord blocks.
- Native undo proof must record `acceptedInsertionUndone` with
  `undoMechanism=nativeSingleEdit`, `sameSliceUndoProof=true`, and
  `restoredOriginalTarget=true`. `accepted-insertion-undone` without that native
  trace event is app rollback proof, not native undo.
- Every compatibility profile must have a `profileCoverage` row in
  `docs/product/proof-manifest.json` with an owner and safety note, including
  diagnostics-only or blocked profiles.
- Every compatibility profile must also have a `hostPolicy` row in
  `docs/product/proof-manifest.json` that matches
  `HostCompatibilityPolicyCatalog`: app version state, safety mode, runtime
  state, proof state, kill switch, and proof artifacts.
- Private apps must use disposable text only.
- A pending screenshot means the app is not screenshot-backed, even if insertion
  worked before.
