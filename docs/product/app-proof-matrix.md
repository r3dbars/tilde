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
| Google Docs in Chrome | blocked | Hosted Docs is blocked by browser-surface policy until a disposable document has screenshot-backed placement, safe Tab, verified insertion, undo/recovery, and no sensitive-field leak. |
| Notion browser or desktop | blocked | Notion pages can contain private workspace text, and neither browser Notion nor `notion.id` has disposable-page ProseMirror proof. |
| Slack browser or desktop | blocked | Message composers need exact no-send proof before suggestions can run. |
| Discord browser or desktop | blocked | Message composers need exact no-send proof before suggestions can run. |
| Mail compose | diagnostics-only | Compose content is sensitive and insertion is unproven; suggestions stay off. |
| Browser webmail | blocked | Email composers can send messages and expose private recipients/subjects; no disposable real-service proof exists. |
| Browser ChatGPT | blocked | Real ChatGPT prompt surfaces need one-word no-submit proof; the local browser-chat harness does not count. |
| Prompt-app full accept | blocked | Full accept needs its own exact prompt-app no-submit screenshot and insertion proof. One-word proof does not count. |
| Chrome production text fields | blocked | Public proof pages and production browser apps do not count as beta-safe local fixture proof. |
| Claude desktop layouts | proof-only | Default one-word no-submit proof exists, but normal beta use, layout variants, and full accept remain blocked. |
| Codex layouts | proof-only | Default one-word no-submit proof refreshed at 2026-05-26T02:06:11Z; normal beta use, broader layouts, and full accept remain gated. |
| Obsidian long notes | supported | Current-head long-note proof now has bounded strict screenshot evidence, viewport-end repair, verified Tab insertion, and accepted-and-kept behavior; broader vault variance still keeps general Obsidian support yellow. |
| Real Monaco and CodeMirror editors | blocked | Forced local fixtures are useful evidence, but official/default Monaco and current CodeMirror proof are not complete. |

| Surface | Grade | Screenshot proof | Accept proof | Current read | Evidence gap |
| --- | --- | --- | --- | --- | --- |
| TextEdit | A | [textedit-inline.png](visual-placement-screenshots/textedit-inline.png) | Bounded strict visual smoke refreshed at 2026-05-12T05:06:55Z with 2 verified accepts and current app fingerprint proof. Native single-edit proof now has a separate `--native-undo-proof` lane. | Strongest native-app proof. Ghost text is readable, on the same line, and Tab/full accept verifies against the configured shortcut. The smoke lane now uses a unique disposable file, targets that exact AX window/title even when old TextEdit windows are restored, and dismisses TextEdit's native inline completion before waiting for Autocomplete Lab. Native proof is only counted when `acceptedInsertionUndone` records `undoMechanism=nativeSingleEdit`; app rollback is recoverable but degraded. | More dark/light document variants and fresh native undo proof rows. |
| Chrome local textarea/contenteditable fixtures | A | [chrome-textarea.png](visual-placement-screenshots/chrome-textarea.png), [chrome-contenteditable.png](visual-placement-screenshots/chrome-contenteditable.png) | 2 verified accepts per local fixture at 2026-05-12T09:12:22Z and 2026-05-12T09:12:38Z. | Only local textarea/contenteditable fixtures count as beta-safe Chrome support. Public pages, production browser apps, chat-like fixtures, editor-like fixtures, hosted docs, Monaco, CodeMirror, and ProseMirror stay proof-only or blocked. | More local boring-text variants would be useful, but public or production pages do not raise the beta-safe scope. |
| Browser editor fixtures | A- | [chrome-editor-like.png](visual-placement-screenshots/chrome-editor-like.png), [chrome-monaco-like.png](visual-placement-screenshots/chrome-monaco-like.png), [chrome-prosemirror-like.png](visual-placement-screenshots/chrome-prosemirror-like.png), [chrome-monaco-real.png](visual-placement-screenshots/chrome-monaco-real.png), [chrome-prosemirror-real.png](visual-placement-screenshots/chrome-prosemirror-real.png) | 2 verified accepts per fixture in the manual smoke log, including recorded `monaco-real` and `prosemirror-real` forced-renderer proof from 2026-05-12T09:13:45Z and 2026-05-12T09:14:02Z, plus normal-Chrome `prosemirror-real-default` proof at 2026-05-12T09:19:46Z. The 2026-05-12 `codemirror-official` attempt now fails closed before Chrome typing when SteadyType is missing macOS Accessibility. | Good recorded proof for CodeMirror-like, Monaco-like, ProseMirror-like, real Monaco, and real ProseMirror under isolated forced-renderer Chrome. Normal Chrome default AX is recorded for real ProseMirror after the same-app focus churn fix. Normal Chrome default Monaco is not claimed. The official-demo harness now checks Accessibility before runtime readiness, allows a longer cold MLX warmup, uses isolated Chrome/DevTools setup where available, and blocks safely when the focused editor cannot be verified. | Monaco default-AX, current-head `codemirror-official`, `monaco-official`, and production editor proof still need verified insertion, not just display. |
| Chrome chat-like composer | A | [chrome-chat-like.png](visual-placement-screenshots/chrome-chat-like.png) | Local chat-like fixture has 2 verified accepts with strict visual trace evidence and submit count zero; bounded HTTP browser-chat harness requires one-word Tab accept with submit, send-key collision, prompt mutation, and wrong-context counters at zero | This is strong proof for the disposable local chat fixture plus the disposable HTTP browser-chat harness only. It is not broad browser chat support and must not be counted as production proof. Browser-hosted ChatGPT, Slack, and Discord stay blocked by surface policy until exact disposable real-service no-submit screenshot and insertion proof exists. | Broad chat apps still need their own exact real-service proof before support. |
| Codex | A- | [codex-inline.png](visual-placement-screenshots/codex-inline.png) | Current bounded strict visual smoke at 2026-05-26T02:06:11Z has exactly 1 verified one-word accept, prompt no-submit confirmation, diagnostics lines 413817-413882, trace lines 28053-28056, app proof `app-sha256:6e1ce0e52d256ec0d038e62c7309a63ef833189758bcf324d458702df5667ac4`, and archive proof `archive-sha256:908f96e7df34df2981ed83fe9c4c45bc8098a340b77dfe203c8f34219445da15`. | Codex has a proof-only prompt lane: screenshot, one-word Tab accept, fast-path focus/accept guard proof, direct marked-composer insertion, insertion verification, and no submit in one trace slice. The helper now prefers a disposable prompt over unrelated focused Codex goal fields and keeps private draft backup/restore for real prompt drafts. It is not beta-safe normal writing support. Full accept remains disabled until a separate no-submit lane exists. | Add more prompt layouts before using this outside proof mode. |
| Obsidian | A | [obsidian.png](visual-placement-screenshots/obsidian.png) | Bounded strict visual smoke is recorded for default, non-default theme, pane, and long-note lanes. Fresh long-note proof at 2026-05-13T02:53:49Z has 2 verified accepts, strict screenshot evidence, CodeMirror viewport-end repair, and current build fingerprint proof. | Real CodeMirror proof shows caret-bound synthetic mirror placement, strict screenshot evidence, Tab accept, and configured full accept in disposable vault notes for the green lanes. The defined default, non-default theme, split/side pane, and long-note lanes start from known disposable proof notes instead of whichever user note happened to be focused. | More vault layouts and hidden-caret edge cases. |
| Apple Notes title | A | [notes-title.png](visual-placement-screenshots/notes-title.png) | Bounded strict visual smoke refreshed at 2026-05-12T05:04:49Z with 2 verified accepts and current app fingerprint proof; same-slice `notes-title-undo` proof was added at 2026-05-12T05:20:17Z; short and long title variant rows were added at 2026-05-12T05:31:38Z and 2026-05-12T05:31:57Z. | Title proof is now separate from generic Notes evidence. The ghost is inline after the title caret, insertion verifies in the same bounded trace slice, Command-Z undo is recorded after the first accept, and the defined short/long title gate is green. | More real-world title layouts would be useful, but the defined Notes title proof gate is green. |
| Apple Notes body | A | [notes-body.png](visual-placement-screenshots/notes-body.png) | Bounded strict visual smoke refreshed at 2026-05-12T05:05:56Z with 2 verified accepts and current app fingerprint proof; same-slice `notes-body-undo` proof was added at 2026-05-12T05:20:38Z; short and long body rows were added at 2026-05-12T05:32:17Z and 2026-05-12T05:33:30Z. | Body proof is now separate from generic Notes evidence. The ghost is inline after the body caret, Option-Tab full accept verifies, suffix retention no longer misclassifies `dictation` as deleted, Command-Z undo is recorded after the first accept, and the defined short/long body gate is green. | More real-world body layouts would be useful, but the defined Notes body proof gate is green. |
| Apple Notes checklist | A | [notes-checklist.png](visual-placement-screenshots/notes-checklist.png) | Bounded strict visual smoke refreshed at 2026-05-12T05:06:15Z with 2 verified accepts and current app fingerprint proof; same-slice `notes-checklist-undo` proof was added at 2026-05-12T05:22:39Z; checked-item and long-row rows were added at 2026-05-12T05:33:50Z and 2026-05-12T05:34:10Z. | Checklist proof is now separate from generic Notes evidence. The screenshot shows a native Notes checklist circle on the same row as the typed smoke text and ghost text. The checklist undo lane records app rollback when available and falls back to native Command-Z only after the disposable checklist text is re-read as restored, and the defined checked-item/long-row gate is green. | More checklist styles would be useful, but the defined Notes checklist proof gate is green. |
| Claude Code | A- | [claude-code-terminal.png](visual-placement-screenshots/claude-code-terminal.png) | Current Terminal proof at 2026-05-25T13:56:48Z has exactly 1 verified one-word Tab accept with diagnostics lines 364600-364662 and trace lines 24701-24709. Current iTerm2 proof at 2026-05-25T15:34:16Z has exactly 1 verified one-word Tab accept with diagnostics lines 372371-372550, trace lines 24920-24930, visual `strict-complete`, prompt no-submit confirmation, app proof `app-sha256:c6811e3591a05730aac82cb2c0b2eaa625c28b2f067de1f7fd187cfc27870731`, and archive proof `archive-sha256:6c241fb4ffdf57cfe825818bd4f52a3871181d409328f7ec6350f667f6700387`. Ghostty reached visible phrase presentation and consumed Tab at 2026-05-25T16:12:56Z, but insertion failed closed on diagnostics lines 375775-375824 after AX, hardware key events, Unicode key events, and verified paste all failed to mutate the prompt. The latest current-head Ghostty run keeps the virtual suggestion through slow-poll churn and reaches the accept/insert ladder at diagnostics lines 406245-406311, but still fails closed because hardware, Unicode, and paste insertion all leave the disposable prompt unchanged. | Direct bundle support is still diagnostics-only because the installed `com.anthropic.claude-code` app is a background-only CLI helper. The proof-only terminal-host adapter maps supported terminal hosts to a virtual Claude Code profile only in explicit proof mode, blocks unmarked terminal sessions, shell prompts, command-shaped prompt lines, active agent output, stale marked scrollback, and multiline command buffers, maps the verified proof prompt back to a compose field for suggestions, carries the virtual bundle ID through traces, rechecks focus and the acceptance snapshot before insertion, preserves the virtual suggestion while the terminal host is still the active owner during slow AX polling, and accepts one word from phrase-mode suggestions through verified AX selected-text insertion, verified hardware key events, verified Unicode key events, or a proof-only verified paste fallback that restores the pasteboard and fails closed. Host-labeled proof commands exist for Terminal, iTerm2, Warp, Ghostty, kitty, Alacritty, and WezTerm, and the Settings current-app panel shows the exact copied command when one of those terminal hosts is focused while keeping normal terminal suggestions blocked. | Keep full accept disabled. Treat Terminal and iTerm2 as the current proven hosts, keep Ghostty unclaimed until it has verified insertion in one disposable no-submit proof, and leave Warp pending because it is not installed here. |
| Claude desktop | A- | [claude-desktop.png](visual-placement-screenshots/claude-desktop.png) | Bounded strict visual smoke at 2026-05-12T11:12:24Z with exactly 1 verified one-word accept, no prompt submit signal, and a current app/archive fingerprint match. | Real Claude desktop has a proof-only lane for same-baseline screenshot-backed synthetic-caret placement, Tab one-word accept, and no submit in one trace slice. Normal beta use remains blocked. The proof lane has separate commands for empty, long, wrapped, narrow, context, light, and dark prompt layouts. Full accept is still disabled. | Needs those layout rows recorded before using outside proof mode; no safe full-accept proof command exists yet. |

## Required Next Proof

1. Expand Claude desktop same-baseline proof across prompt layouts:
   `claude-empty`, `claude-long`, `claude-wrapped`, `claude-narrow`,
   `claude-context`, `claude-light`, and `claude-dark`.
2. Keep Chrome production and editor lanes out of beta-safe scope:
   `codemirror-official` after Accessibility is enabled,
   `monaco-real --chrome-accessibility default`, and `monaco-official`.
   These rows can collect proof, but they do not count as beta-safe support.
   The smoke harness still fails honestly when a verified editor cannot be
   reached.
3. Add real production proof paths for Google Docs, Notion, browser webmail,
   browser ChatGPT, browser Slack, and browser Discord before removing their
   `unsupported-browser-surface` block. Local fixtures, local harnesses, and
   public non-auth editor fixtures do not count for these real-service rows.

## Proof Rules

- Screenshot proof must link to a committed PNG in
  `docs/product/visual-placement-screenshots/`.
- Accept proof must show verified insertion, not just a visible suggestion.
- Prompt apps must prove one-word accept without submit before they can run in proof mode; they do not graduate into beta-safe normal use from that alone.
- Terminal-hosted Claude Code must first prove the terminal adapter cannot submit shell input, and host-labeled proof must not stand in for untested terminal hosts.
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
