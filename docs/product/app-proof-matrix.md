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
evidence exists in the repo.

| Surface | Grade | Screenshot proof | Accept proof | Current read | Evidence gap |
| --- | --- | --- | --- | --- | --- |
| TextEdit | A | [textedit-inline.png](visual-placement-screenshots/textedit-inline.png) | Bounded strict visual smoke at 2026-05-08T04:53:15Z with 2 verified accepts and current proof fingerprints | Strongest native-app proof. Ghost text is readable, on the same line, and Tab/full accept verifies against the configured shortcut. The smoke lane now uses a unique disposable file and dismisses TextEdit's native inline completion before waiting for Autocomplete Lab. | More dark/light document variants. |
| Chrome text fields | A- | [chrome-textarea.png](visual-placement-screenshots/chrome-textarea.png), [chrome-contenteditable.png](visual-placement-screenshots/chrome-contenteditable.png) | 2 verified accepts per fixture in the manual smoke log | Local textarea and contenteditable fixtures are solid. | Still local fixtures, not random production sites. |
| Browser editor fixtures | A- | [chrome-editor-like.png](visual-placement-screenshots/chrome-editor-like.png), [chrome-monaco-like.png](visual-placement-screenshots/chrome-monaco-like.png), [chrome-prosemirror-like.png](visual-placement-screenshots/chrome-prosemirror-like.png), [chrome-monaco-real.png](visual-placement-screenshots/chrome-monaco-real.png), [chrome-prosemirror-real.png](visual-placement-screenshots/chrome-prosemirror-real.png) | 2 verified accepts per fixture in the manual smoke log, including `monaco-real` at 2026-05-08T03:19:38Z and `prosemirror-real` at 2026-05-08T03:17:54Z | Good proof for CodeMirror-like, Monaco-like, ProseMirror-like, real Monaco, and real ProseMirror shapes inside Chrome. Obsidian now has its own real CodeMirror row. | Real Monaco/ProseMirror proof uses isolated Chrome with renderer accessibility forced and still falls back to mirror/element placement. Needs default-Chrome AX exposure and more production editor variants before A. |
| Chrome chat-like composer | A- | [chrome-chat-like.png](visual-placement-screenshots/chrome-chat-like.png) | 2 verified accepts with strict visual trace evidence; local submit counter stayed at zero | The local no-submit fixture is now screenshot-backed and proves Tab/full accept do not submit the disposable composer. Claude desktop now has real prompt no-submit proof too. | Still needs Codex prompt-app no-submit proof and a Claude Code terminal-host adapter before broad enablement. |
| Codex | B- | [codex-inline.png](visual-placement-screenshots/codex-inline.png) | Prior verified accepts exist in the manual smoke log, but the current gate is one-word no-submit proof | Real dogfood screenshot exists, and insertion has passed separately. Full accept is disabled until separate full-accept no-submit proof exists. | Needs one strict visual trace slice that proves screenshot, one-word accept, and no prompt submit together. |
| Obsidian | A- | [obsidian.png](visual-placement-screenshots/obsidian.png) | Bounded strict visual smoke at 2026-05-07T21:15:51Z with 2 verified accepts and current proof fingerprints | Real CodeMirror proof now shows caret-bound synthetic mirror placement, strict screenshot evidence, Tab accept, and configured full accept in a disposable vault note. | More vault themes, panes, and long-note variants. |
| Apple Notes title | A- | [notes-title.png](visual-placement-screenshots/notes-title.png) | Bounded strict visual smoke at 2026-05-07T21:24:14Z with 2 verified accepts and current proof fingerprints | Title proof is now separate from generic Notes evidence. The ghost is inline after the title caret and insertion verifies in the same bounded trace slice. | More title lengths and undo variants. |
| Apple Notes body | A- | [notes-body.png](visual-placement-screenshots/notes-body.png) | Bounded strict visual smoke at 2026-05-07T23:33:48Z with 2 verified accepts and current proof fingerprints | Body proof is now separate from generic Notes evidence. The ghost is inline after the body caret, Option-Tab full accept verifies, and suffix retention no longer misclassifies `dictation` as deleted. | More body lengths and undo variants. |
| Apple Notes checklist | A- | [notes-checklist.png](visual-placement-screenshots/notes-checklist.png) | Bounded strict visual smoke at 2026-05-08T00:21:33Z with 2 verified accepts and current proof fingerprints | Checklist proof is now separate from generic Notes evidence. The screenshot shows a native Notes checklist circle on the same row as the typed smoke text and ghost text. | More checklist lengths, checked items, and undo variants. |
| Claude Code | D | Pending | Pending | Direct bundle support is now diagnostics-only because the installed `com.anthropic.claude-code` app is a background-only CLI helper. A first terminal-host proof policy now blocks unmarked terminal sessions, shell prompts, and multiline buffers. | Needs a live terminal-host adapter that proves one-word Tab accept without submitting shell input or an agent prompt. |
| Claude desktop | A- | [claude-desktop.png](visual-placement-screenshots/claude-desktop.png) | Bounded strict visual smoke at 2026-05-08T03:49:56Z with exactly 1 verified one-word accept and no prompt submit signal | Real Claude desktop now proves same-baseline screenshot-backed synthetic-caret placement, Tab one-word accept, and no submit in one trace slice. The screenshot detector reported `dx=0.2`, `dy=-0.4` after centered-composer tuning. Full accept is still disabled until separate full-accept no-submit proof exists. | Needs more prompt layout variants before A. |

## Required Next Proof

1. Run `AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh codex --manual-gate` with disposable prompt text containing `AUTOCOMPLETE_LAB_CODEX_PROOF`, then keep one trace slice that proves visual placement plus one-word accept without submit.
2. Expand Obsidian coverage across vault themes, panes, and long notes.
3. Build a terminal-host Claude Code proof lane before running any Claude Code prompt pass.
4. Expand Claude desktop same-baseline proof across prompt layouts.
5. Improve real Chrome editor placement from forced-accessibility mirror fallback to default-Chrome AX exposure with caret-quality placement.

## Proof Rules

- Screenshot proof must link to a committed PNG in
  `docs/product/visual-placement-screenshots/`.
- Accept proof must show verified insertion, not just a visible suggestion.
- Prompt apps must prove one-word accept without submit before they can graduate.
- Terminal-hosted Claude Code must first prove the terminal adapter cannot submit shell input.
- Prompt-app full accept needs its own separate full-accept no-submit proof.
- Prompt-app proof must be one trace-level accept only and must not contain
  full-accept or field-send finalization signals.
- Private apps must use disposable text only.
- A pending screenshot means the app is not screenshot-backed, even if insertion
  worked before.
