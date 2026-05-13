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
| Browser ChatGPT | blocked | Real ChatGPT prompt surfaces need one-word no-submit proof; the local browser-chat harness does not count. |
| Prompt-app full accept | blocked | Full accept needs its own exact prompt-app no-submit screenshot and insertion proof. One-word proof does not count. |
| Claude desktop layouts | word-only | Default one-word no-submit proof exists, but layout variants are pending and full accept remains disabled. |
| Codex layouts | word-only | Default one-word no-submit proof exists; broader layouts and full accept remain gated. |
| Obsidian long notes | word-only | Current-head long-note proof now has bounded strict screenshot evidence, viewport-end repair, verified Tab insertion, and accepted-and-kept behavior; broader vault variance still keeps general Obsidian support yellow. |
| Real Monaco and CodeMirror editors | blocked | Forced local fixtures are useful evidence, but official/default Monaco and current CodeMirror proof are not complete. |

| Surface | Grade | Screenshot proof | Accept proof | Current read | Evidence gap |
| --- | --- | --- | --- | --- | --- |
| TextEdit | A | [textedit-inline.png](visual-placement-screenshots/textedit-inline.png) | Bounded strict visual smoke refreshed at 2026-05-12T05:06:55Z with 2 verified accepts and current app fingerprint proof. Native single-edit proof now has a separate `--native-undo-proof` lane. | Strongest native-app proof. Ghost text is readable, on the same line, and Tab/full accept verifies against the configured shortcut. The smoke lane now uses a unique disposable file, targets that exact AX window/title even when old TextEdit windows are restored, and dismisses TextEdit's native inline completion before waiting for Autocomplete Lab. Native proof is only counted when `acceptedInsertionUndone` records `undoMechanism=nativeSingleEdit`; app rollback is recoverable but degraded. | More dark/light document variants and fresh native undo proof rows. |
| Chrome text fields | A | [chrome-textarea.png](visual-placement-screenshots/chrome-textarea.png), [chrome-contenteditable.png](visual-placement-screenshots/chrome-contenteditable.png) | 2 verified accepts per local fixture at 2026-05-12T09:12:22Z and 2026-05-12T09:12:38Z, plus fresh `textarea-public` proof at 2026-05-12T09:15:03Z and `contenteditable-public` proof at 2026-05-12T09:30:53Z. | Local textarea/contenteditable fixtures, the public EditPad textarea lane, and the public MediumEditor-style contenteditable lane are solid. The public lanes use disposable text, guarded focus, and real Autocomplete Lab accept verification. Search, login, payment, and known hosted risky surfaces stay suppressed. | More public rich-text/editor variants would be useful, but the defined Chrome text-field proof gate is green. |
| Browser editor fixtures | A- | [chrome-editor-like.png](visual-placement-screenshots/chrome-editor-like.png), [chrome-monaco-like.png](visual-placement-screenshots/chrome-monaco-like.png), [chrome-prosemirror-like.png](visual-placement-screenshots/chrome-prosemirror-like.png), [chrome-monaco-real.png](visual-placement-screenshots/chrome-monaco-real.png), [chrome-prosemirror-real.png](visual-placement-screenshots/chrome-prosemirror-real.png) | 2 verified accepts per fixture in the manual smoke log, including recorded `monaco-real` and `prosemirror-real` forced-renderer proof from 2026-05-12T09:13:45Z and 2026-05-12T09:14:02Z, plus normal-Chrome `prosemirror-real-default` proof at 2026-05-12T09:19:46Z. The 2026-05-12 `codemirror-official` attempt now fails closed before Chrome typing when SteadyType is missing macOS Accessibility. | Good recorded proof for CodeMirror-like, Monaco-like, ProseMirror-like, real Monaco, and real ProseMirror under isolated forced-renderer Chrome. Normal Chrome default AX is recorded for real ProseMirror after the same-app focus churn fix. Normal Chrome default Monaco is not claimed. The official-demo harness now checks Accessibility before runtime readiness, allows a longer cold MLX warmup, uses isolated Chrome/DevTools setup where available, and blocks safely when the focused editor cannot be verified. | Monaco default-AX, current-head `codemirror-official`, `monaco-official`, and production editor proof still need verified insertion, not just display. |
| Chrome chat-like composer | A | [chrome-chat-like.png](visual-placement-screenshots/chrome-chat-like.png) | Local chat-like fixture has 2 verified accepts with strict visual trace evidence and submit count zero; bounded HTTP browser-chat harness requires one-word Tab accept with submit, send-key collision, prompt mutation, and wrong-context counters at zero | This is strong proof for the disposable local chat fixture plus the disposable HTTP browser-chat harness only. It is not broad browser chat support and must not be counted as production proof. Browser-hosted ChatGPT, Slack, and Discord stay blocked by surface policy until exact disposable real-service no-submit screenshot and insertion proof exists. | Broad chat apps still need their own exact real-service proof before support. |
| Codex | A- | [codex-inline.png](visual-placement-screenshots/codex-inline.png) | Current bounded strict visual smoke at 2026-05-12T05:59:26Z has exactly 1 verified one-word accept, prompt no-submit confirmation, draft backup/restore, and app proof `app-sha256:7f750b673ba91258f43c54333fb1d0ccd29a2bc917d3f8736690aaf958678a6f`. | Codex now has a current prompt-safe lane: screenshot, one-word Tab accept, fast-path focus/accept guard proof, direct marked-composer insertion, insertion verification, no submit, and private draft restoration in one trace slice. The profile stays word-only; full accept remains disabled until a separate no-submit lane exists. | Add more prompt layouts before raising this above A-. |
| Obsidian | A | [obsidian.png](visual-placement-screenshots/obsidian.png) | Bounded strict visual smoke is recorded for default, non-default theme, pane, and long-note lanes. Fresh long-note proof at 2026-05-13T02:53:49Z has 2 verified accepts, strict screenshot evidence, CodeMirror viewport-end repair, and current build fingerprint proof. | Real CodeMirror proof shows caret-bound synthetic mirror placement, strict screenshot evidence, Tab accept, and configured full accept in disposable vault notes for the green lanes. The defined default, non-default theme, split/side pane, and long-note lanes start from known disposable proof notes instead of whichever user note happened to be focused. | More vault layouts and hidden-caret edge cases. |
| Apple Notes title | A | [notes-title.png](visual-placement-screenshots/notes-title.png) | Bounded strict visual smoke refreshed at 2026-05-12T05:04:49Z with 2 verified accepts and current app fingerprint proof; same-slice `notes-title-undo` proof was added at 2026-05-12T05:20:17Z; short and long title variant rows were added at 2026-05-12T05:31:38Z and 2026-05-12T05:31:57Z. | Title proof is now separate from generic Notes evidence. The ghost is inline after the title caret, insertion verifies in the same bounded trace slice, Command-Z undo is recorded after the first accept, and the defined short/long title gate is green. | More real-world title layouts would be useful, but the defined Notes title proof gate is green. |
| Apple Notes body | A | [notes-body.png](visual-placement-screenshots/notes-body.png) | Bounded strict visual smoke refreshed at 2026-05-12T05:05:56Z with 2 verified accepts and current app fingerprint proof; same-slice `notes-body-undo` proof was added at 2026-05-12T05:20:38Z; short and long body rows were added at 2026-05-12T05:32:17Z and 2026-05-12T05:33:30Z. | Body proof is now separate from generic Notes evidence. The ghost is inline after the body caret, Option-Tab full accept verifies, suffix retention no longer misclassifies `dictation` as deleted, Command-Z undo is recorded after the first accept, and the defined short/long body gate is green. | More real-world body layouts would be useful, but the defined Notes body proof gate is green. |
| Apple Notes checklist | A | [notes-checklist.png](visual-placement-screenshots/notes-checklist.png) | Bounded strict visual smoke refreshed at 2026-05-12T05:06:15Z with 2 verified accepts and current app fingerprint proof; same-slice `notes-checklist-undo` proof was added at 2026-05-12T05:22:39Z; checked-item and long-row rows were added at 2026-05-12T05:33:50Z and 2026-05-12T05:34:10Z. | Checklist proof is now separate from generic Notes evidence. The screenshot shows a native Notes checklist circle on the same row as the typed smoke text and ghost text. The checklist undo lane records app rollback when available and falls back to native Command-Z only after the disposable checklist text is re-read as restored, and the defined checked-item/long-row gate is green. | More checklist styles would be useful, but the defined Notes checklist proof gate is green. |
| Claude Code | A- | [claude-code-terminal.png](visual-placement-screenshots/claude-code-terminal.png) | Current no-submit smoke at 2026-05-12T06:41:56Z has exactly 1 verified Terminal-hosted one-word accept on `ca41cdc33e5e` with no shell or agent submit signal. It intentionally does not claim strict screenshot evidence because the fresh signed test app hit a macOS screen/audio permission prompt that I did not grant. | Direct bundle support is still diagnostics-only because the installed `com.anthropic.claude-code` app is a background-only CLI helper. The proof-only terminal-host adapter maps supported terminal hosts to a virtual Claude Code profile only in explicit proof mode, blocks unmarked terminal sessions, shell prompts, command-shaped prompt lines, active agent output, stale marked scrollback, and multiline command buffers, now trusts a marked current prompt line over unrelated Terminal scrollback, and inserts one-word accepted text through the terminal host's own Paste menu via AX after rechecking focus and the acceptance snapshot. Host-labeled proof commands exist for Terminal, iTerm2, Warp, Ghostty, kitty, Alacritty, and WezTerm. | Refresh Terminal proof with strict screenshot evidence after user-granted Screen Recording, keep full accept disabled, then record host-labeled proof for iTerm2 and Ghostty. Warp is not installed here, so it remains an honest gap. |
| Claude desktop | A- | [claude-desktop.png](visual-placement-screenshots/claude-desktop.png) | Bounded strict visual smoke at 2026-05-12T11:12:24Z with exactly 1 verified one-word accept, no prompt submit signal, and a current app/archive fingerprint match. | Real Claude desktop proves same-baseline screenshot-backed synthetic-caret placement, Tab one-word accept, and no submit in one trace slice. The app now uses direct prompt-bound AX value replacement for Claude desktop after generic AX insertion failed live. The proof lane has separate commands for empty, long, wrapped, narrow, context, light, and dark prompt layouts. Full accept is still disabled. | Needs those layout rows recorded before A; no safe full-accept proof command exists yet. |

## Required Next Proof

1. Expand Claude desktop same-baseline proof across prompt layouts:
   `claude-empty`, `claude-long`, `claude-wrapped`, `claude-narrow`,
   `claude-context`, `claude-light`, and `claude-dark`.
2. Finish the remaining guarded Chrome editor lanes:
   `codemirror-official` after Accessibility is enabled,
   `monaco-real --chrome-accessibility default`, and `monaco-official`.
   Keep browser editor fixtures non-A until those lanes have bounded
   screenshot-backed accept evidence. The smoke harness now refuses concurrent
   runs, checks Accessibility before runtime readiness, checks the active Chrome
   URL, uses isolated Chrome plus localhost DevTools for official-page setup
   when available, requires a focused editable web AX target, allows a longer
   cold MLX warmup, and still fails honestly when a verified editor cannot be
   reached.
3. Add real production proof paths for Google Docs, Notion, browser ChatGPT,
   browser Slack, and browser Discord before removing their
   `unsupported-browser-surface` block. Local fixtures, local harnesses, and
   public non-auth editor fixtures do not count for these real-service rows.

## Proof Rules

- Screenshot proof must link to a committed PNG in
  `docs/product/visual-placement-screenshots/`.
- Accept proof must show verified insertion, not just a visible suggestion.
- Prompt apps must prove one-word accept without submit before they can graduate.
- Terminal-hosted Claude Code must first prove the terminal adapter cannot submit shell input, and host-labeled proof must not stand in for untested terminal hosts.
- Prompt-app full accept needs its own separate full-accept no-submit proof.
- Real ChatGPT, Slack, Discord, Google Docs, and Notion require exact disposable
  real-service proof with screenshot-backed placement and verified insertion.
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
