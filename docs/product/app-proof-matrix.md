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

Current result: the target gate still fails, and that is correct. Every non-A
row below must stay non-A until the required screenshot-backed and accept-proof
evidence exists in the repo. The proof manifest also keeps variant-incomplete
A- rows as `partial`, even when they have a passing live smoke slice.

| Surface | Grade | Screenshot proof | Accept proof | Current read | Evidence gap |
| --- | --- | --- | --- | --- | --- |
| TextEdit | A | [textedit-inline.png](visual-placement-screenshots/textedit-inline.png), [textedit-light.png](visual-placement-screenshots/textedit-light.png), [textedit-dark.png](visual-placement-screenshots/textedit-dark.png), [textedit-long-wrap.png](visual-placement-screenshots/textedit-long-wrap.png), [textedit-narrow.png](visual-placement-screenshots/textedit-narrow.png), [textedit-scrolled.png](visual-placement-screenshots/textedit-scrolled.png) | Current strict visual smokes on 2026-05-09 cover light, dark, wrapped line, narrow/resized window, and scrolled document, each with 2 verified accepts. Native single-edit proof still has a separate `--native-undo-proof` lane. | Strongest native-app proof. Ghost text is readable, on the same line, and Tab/full accept verifies against the configured shortcut. The smoke lane uses a unique disposable file, targets that exact AX window/title while other TextEdit windows exist, and dismisses TextEdit's native inline completion before waiting for Autocomplete Lab. During the latest pass `NSScreen.screens` reported one active display, so secondary-display proof was not available. | Keep fresh; rerun secondary-display proof when a second display is connected. |
| Chrome text fields | A | [chrome-textarea.png](visual-placement-screenshots/chrome-textarea.png), [chrome-contenteditable.png](visual-placement-screenshots/chrome-contenteditable.png) | 2 verified accepts per local fixture, plus fresh `textarea-public` and `contenteditable-public` public-page proof rows with strict screenshot-backed traces. | Local textarea/contenteditable fixtures and bounded public top-level demos are solid. The public lanes use disposable EditPad and MediumEditor pages, isolated Chrome DevTools only for setup, and real Autocomplete Lab accept verification. Search, login, payment, and known hosted risky surfaces stay suppressed. | More public domains would be useful, but the defined production text-field gate is green. |
| Browser editor fixtures | A- | [chrome-editor-like.png](visual-placement-screenshots/chrome-editor-like.png), [chrome-codemirror-official.png](visual-placement-screenshots/chrome-codemirror-official.png), [chrome-monaco-like.png](visual-placement-screenshots/chrome-monaco-like.png), [chrome-prosemirror-like.png](visual-placement-screenshots/chrome-prosemirror-like.png), [chrome-monaco-real.png](visual-placement-screenshots/chrome-monaco-real.png), [chrome-prosemirror-real.png](visual-placement-screenshots/chrome-prosemirror-real.png) | 2 verified accepts per fixture in the manual smoke log, including current official CodeMirror proof at 2026-05-09T12:02:35Z and current stable-build `monaco-real` / `prosemirror-real` forced-renderer proof. | Good proof for CodeMirror-like, official CodeMirror, Monaco-like, ProseMirror-like, real Monaco, and real ProseMirror. The official CodeMirror lane now uses AX focus and a narrow Chrome CodeMirror trailing-character repair. | Official Monaco and ProseMirror demos are still blocked: normal Chrome rejects JavaScript from Apple Events and AX did not expose a verified editor target on those pages. |
| Chrome chat-like composer | A | [chrome-chat-like.png](visual-placement-screenshots/chrome-chat-like.png) | Local chat-like fixture has 2 verified accepts with strict visual trace evidence and submit count zero; bounded HTTP browser-chat harness requires one-word Tab accept with submit, send-key collision, prompt mutation, and wrong-context counters at zero | This is now strong proof for the disposable local chat fixture plus the disposable HTTP browser-chat harness. It is not broad browser chat support. Browser-hosted ChatGPT, Slack, and Discord stay blocked by surface policy until exact real-service no-submit proof exists. | Broad chat apps still need their own exact proof before support. |
| Codex | A | [codex-inline.png](visual-placement-screenshots/codex-inline.png) | Bounded strict visual smoke at 2026-05-09T03:06:50Z with exactly 1 verified one-word accept and prompt no-submit confirmation | Codex now proves screenshot, one-word Tab accept, direct marked-composer insertion, insertion verification, and no submit in one trace slice. The profile stays word-only; full accept remains disabled until a separate no-submit lane exists. | More Codex prompt layouts would be useful, but the same-slice no-submit gate is green. |
| Obsidian | A- | [obsidian.png](visual-placement-screenshots/obsidian.png) | Current bounded strict visual smokes on 2026-05-09 cover default, non-default theme, and split-pane lanes with 2 verified accepts each. | Real CodeMirror proof now shows caret-bound synthetic mirror placement, strict screenshot evidence, Tab accept, and configured full accept in disposable vault notes across default, theme, and pane variants. The long-note harness reaches the scrolled note and verifies the first accept, then blocks instead of guessing when CodeMirror AX reports the caret 21 characters before the file end. | Still partial until `obsidian-long-note` has a bounded strict screenshot-backed trace row with two verified accepts. |
| Apple Notes title | A- | [notes-title.png](visual-placement-screenshots/notes-title.png) | Bounded strict visual smoke at 2026-05-07T21:24:14Z with 2 verified accepts and current proof fingerprints | Title proof is now separate from generic Notes evidence. The ghost is inline after the title caret and insertion verifies in the same bounded trace slice. Undo remains degraded until `notes-title-undo` records same-slice proof. | More title lengths; run `notes-title-undo` for same-slice undo proof. |
| Apple Notes body | A- | [notes-body.png](visual-placement-screenshots/notes-body.png) | Bounded strict visual smoke at 2026-05-07T23:33:48Z with 2 verified accepts and current proof fingerprints | Body proof is now separate from generic Notes evidence. The ghost is inline after the body caret, Option-Tab full accept verifies, and suffix retention no longer misclassifies `dictation` as deleted. Undo remains degraded until `notes-body-undo` records same-slice proof. | More body lengths; run `notes-body-undo` for same-slice undo proof. |
| Apple Notes checklist | A- | [notes-checklist.png](visual-placement-screenshots/notes-checklist.png) | Bounded strict visual smoke at 2026-05-08T00:21:33Z with 2 verified accepts and current proof fingerprints | Checklist proof is now separate from generic Notes evidence. The screenshot shows a native Notes checklist circle on the same row as the typed smoke text and ghost text. Undo remains degraded until `notes-checklist-undo` records same-slice proof. | More checklist lengths, checked items, and `notes-checklist-undo` proof. |
| Claude Code | A- | [claude-code-terminal.png](visual-placement-screenshots/claude-code-terminal.png) | Bounded strict visual smoke at 2026-05-08T17:04:17Z with exactly 1 verified Terminal-hosted one-word accept and no shell or agent submit signal | Direct bundle support is still diagnostics-only because the installed `com.anthropic.claude-code` app is a background-only CLI helper. The proof-only terminal-host adapter now maps supported terminal hosts to a virtual Claude Code profile only in explicit proof mode, blocks unmarked terminal sessions, shell prompts, command-shaped prompt lines, active agent output, stale marked scrollback, and multiline command buffers, extracts the current input line from terminal scrollback, and inserts one-word accepted text through the terminal host's own Paste menu via AX after rechecking focus and the acceptance snapshot. Host-labeled proof commands now exist for Terminal, iTerm2, Warp, Ghostty, kitty, Alacritty, and WezTerm. | Keep full accept disabled. Record host-labeled proof for iTerm2 and Ghostty on this Mac; Warp is not installed here, so it remains an honest gap. |
| Claude desktop | A- | [claude-desktop.png](visual-placement-screenshots/claude-desktop.png) | Bounded strict visual smoke at 2026-05-08T03:49:56Z with exactly 1 verified one-word accept and no prompt submit signal | Real Claude desktop proves same-baseline screenshot-backed synthetic-caret placement, Tab one-word accept, and no submit in one trace slice. The proof lane now has separate commands for empty, long, wrapped, narrow, context, light, and dark prompt layouts. Full accept is still disabled. | Needs those layout rows recorded before A; no safe full-accept proof command exists yet. |

## Required Next Proof

1. Run `AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh codex --manual-gate` with disposable prompt text containing `AUTOCOMPLETE_LAB_CODEX_PROOF`, then keep one trace slice that proves visual placement plus one-word accept without submit.
2. Close the remaining Obsidian long scrolled-note lane:
   `AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh obsidian-long-note --manual-gate`.
3. Expand Claude desktop same-baseline proof across prompt layouts:
   `claude-empty`, `claude-long`, `claude-wrapped`, `claude-narrow`,
   `claude-context`, `claude-light`, and `claude-dark`.
4. Run `AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh chrome --fixture production-text-fields` and keep strict rows for `textarea-public` and `contenteditable-public`.
5. Refresh default-Chrome real-editor proof only after normal Chrome exposes the
   editor AX tree, or replace it with another bounded safe production proof path.
6. Keep `codemirror-official` green. Run the guarded official Chrome
   `monaco-official` and `prosemirror-official` lanes only when Chrome can
   expose a verified editor through AX or JavaScript from Apple Events. The
   smoke harness now refuses concurrent runs, checks the active Chrome URL,
   requires a focused editable web AX target, and verifies Chrome setup text
   against the focused editor value before proceeding.
7. Add real production proof paths for Google Docs, Notion, browser ChatGPT,
   browser Slack, and browser Discord before removing their
   `unsupported-browser-surface` block.

## Proof Rules

- Screenshot proof must link to a committed PNG in
  `docs/product/visual-placement-screenshots/`.
- Accept proof must show verified insertion, not just a visible suggestion.
- Prompt apps must prove one-word accept without submit before they can graduate.
- Terminal-hosted Claude Code must first prove the terminal adapter cannot submit shell input, and host-labeled proof must not stand in for untested terminal hosts.
- Prompt-app full accept needs its own separate full-accept no-submit proof.
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
