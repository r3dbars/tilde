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
| TextEdit | A | [textedit-inline.png](visual-placement-screenshots/textedit-inline.png) | Bounded strict visual smoke at 2026-05-07T21:01:59Z with 2 verified accepts and current proof fingerprints | Strongest native-app proof. Ghost text is readable, on the same line, and Tab/full accept verifies against the configured shortcut. | More dark/light document variants. |
| Chrome text fields | A- | [chrome-textarea.png](visual-placement-screenshots/chrome-textarea.png), [chrome-contenteditable.png](visual-placement-screenshots/chrome-contenteditable.png) | 2 verified accepts per fixture in the manual smoke log | Local textarea and contenteditable fixtures are solid. | Still local fixtures, not random production sites. |
| Browser editor fixtures | B+ | [chrome-editor-like.png](visual-placement-screenshots/chrome-editor-like.png), [chrome-monaco-like.png](visual-placement-screenshots/chrome-monaco-like.png), [chrome-prosemirror-like.png](visual-placement-screenshots/chrome-prosemirror-like.png) | 2 verified accepts per fixture in the manual smoke log | Good proof for CodeMirror-like, Monaco-like, and ProseMirror-like shapes inside Chrome. Obsidian now has its own real CodeMirror row. | Needs real Monaco and real ProseMirror screenshots beyond local fixtures. |
| Chrome chat-like composer | A- | [chrome-chat-like.png](visual-placement-screenshots/chrome-chat-like.png) | 2 verified accepts with strict visual trace evidence; local submit counter stayed at zero | The local no-submit fixture is now screenshot-backed and proves Tab/full accept do not submit the disposable composer. | Still needs real prompt/chat app no-submit proof before broad enablement. |
| Codex | B- | [codex-inline.png](visual-placement-screenshots/codex-inline.png) | Prior verified accepts exist in the manual smoke log, but the current gate is one-word no-submit proof | Real dogfood screenshot exists, and insertion has passed separately. The current profile is mirror-first until same-slice no-submit proof exists, and full accept is disabled until separate full-accept no-submit proof exists. | Needs one strict visual trace slice that proves screenshot, one-word accept, and no prompt submit together. |
| Obsidian | A- | [obsidian.png](visual-placement-screenshots/obsidian.png) | Bounded strict visual smoke at 2026-05-07T21:15:51Z with 2 verified accepts and current proof fingerprints | Disposable-note proof is screenshot-backed. Detached whole-editor anchors are also suppressed. | More vault, theme, and editor-layout variants. |
| Apple Notes title | A- | [notes-title.png](visual-placement-screenshots/notes-title.png) | Bounded strict visual smoke at 2026-05-07T21:24:14Z with 2 verified accepts and current proof fingerprints | Title-field proof is now separate and screenshot-backed. | More note-window sizes and title/body transition variants. |
| Apple Notes body | A- | [notes-body.png](visual-placement-screenshots/notes-body.png) | Bounded strict visual smoke at 2026-05-07T23:33:48Z with 2 verified accepts and current proof fingerprints | Body-field proof is now separate and screenshot-backed. | More multiline and rich-text body variants. |
| Apple Notes checklist | A- | [notes-checklist.png](visual-placement-screenshots/notes-checklist.png) | Bounded strict visual smoke at 2026-05-08T00:21:33Z with 2 verified accepts and current proof fingerprints | Checklist-row proof is now separate and screenshot-backed. | More nested checklist and mixed-format variants. |
| Claude Code | D | Pending | Pending | Profile exists and is mirror-first, but there is no safe live prompt proof yet. | Needs a manual-gated pass that proves Tab accepts without submitting. |
| Claude desktop | B- | Pending fresh screenshot | Prior verified accepts exist in the manual smoke log, but the current gate is one-word no-submit proof | Prior manual proof passed, but it is not current screenshot-backed proof. The current profile is mirror-first, and full accept is disabled until separate full-accept no-submit proof exists. | Needs a current screenshot-backed one-word prompt pass without submitting. |

## Required Next Proof

1. Run `AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh codex --manual-gate` and keep one trace slice that proves visual placement plus one-word accept without submit.
2. Run Claude Code with a harmless prompt fragment and no Enter key.
3. Refresh Claude desktop with screenshot tracing and one-word accept without submit.
4. Replace browser-editor fixture confidence with at least one real CodeMirror, Monaco, and ProseMirror proof pass.
5. Add extra Obsidian and Notes variants beyond the first strict proof rows.
6. Run `script/no_accessibility_smoke.sh --check` after manually disabling
   Accessibility so the off state has a permission-specific proof path.

## Proof Rules

- Screenshot proof must link to a committed PNG in
  `docs/product/visual-placement-screenshots/`.
- Accept proof must show verified insertion, not just a visible suggestion.
- Prompt apps must prove one-word accept without submit before they can graduate.
- Prompt-app full accept needs its own separate full-accept no-submit proof.
- Prompt-app proof must be one trace-level accept only and must not contain
  full-accept or field-send finalization signals.
- Private apps must use disposable text only.
- A pending screenshot means the app is not screenshot-backed, even if insertion
  worked before.
- Compatibility learning can recommend an adapter only after 5 observations,
  0.75 confidence, a trusted visual reason, and current screenshot-backed smoke.
