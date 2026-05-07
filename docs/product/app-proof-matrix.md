# App Proof Matrix

Screenshot-backed proof for the current cross-app typing loop.

This is not a support promise. It is the honest proof state for the lab build:
what has a screenshot, what has insertion proof, and what still needs a real
manual pass.

Source docs: `manual-smoke-runs.md`,
`deep-dive-scorecard-2026-05-06.md`, and the committed screenshots in
`visual-placement-screenshots/`.

Grades are evidence grades, not product grades.

| Surface | Grade | Screenshot proof | Accept proof | Current read | Evidence gap |
| --- | --- | --- | --- | --- | --- |
| TextEdit | A | [textedit-inline.png](visual-placement-screenshots/textedit-inline.png) | 2 verified accepts in the manual smoke log | Strongest native-app proof. Ghost text is readable, on the same line, and Tab/full accept verifies. | More dark/light document variants. |
| Chrome text fields | A- | [chrome-textarea.png](visual-placement-screenshots/chrome-textarea.png), [chrome-contenteditable.png](visual-placement-screenshots/chrome-contenteditable.png) | 2 verified accepts per fixture in the manual smoke log | Local textarea and contenteditable fixtures are solid. | Still local fixtures, not random production sites. |
| Browser editor fixtures | B+ | [chrome-editor-like.png](visual-placement-screenshots/chrome-editor-like.png), [chrome-monaco-like.png](visual-placement-screenshots/chrome-monaco-like.png), [chrome-prosemirror-like.png](visual-placement-screenshots/chrome-prosemirror-like.png) | 2 verified accepts per fixture in the manual smoke log | Good proof for CodeMirror-like, Monaco-like, and ProseMirror-like shapes inside Chrome. | Needs real Obsidian/CodeMirror, real Monaco, and real ProseMirror screenshots. |
| Chrome chat-like composer | A- | [chrome-chat-like.png](visual-placement-screenshots/chrome-chat-like.png) | 2 verified accepts with strict visual trace evidence; local submit counter stayed at zero | The local no-submit fixture is now screenshot-backed and proves Tab/full accept do not submit the disposable composer. | Still needs real prompt/chat app no-submit proof before broad enablement. |
| Codex | B- | [codex-inline.png](visual-placement-screenshots/codex-inline.png) | Prior verified accepts exist in the manual smoke log | Real dogfood screenshot exists, and insertion has passed separately. Full accept is disabled until no-submit proof exists. | Needs one strict visual trace slice that proves screenshot, one-word accept, and no prompt submit together. |
| Obsidian | C+ | Pending | 2 verified accepts exist; detached whole-editor anchors are also suppressed | The profile can work, but this is not screenshot-backed on the current renderer. | Needs a disposable vault note screenshot with same-slice accepts. |
| Apple Notes | C | Pending for title, body, and checklist | Older generic Notes proof exists; current surface-specific rows are not complete | Notes is too easy to overclaim because title/body/checklist behave differently. | Needs separate screenshot-backed `notes-title`, `notes-body`, and `notes-checklist` passes. |
| Claude Code | D | Pending | Pending | Profile exists, but there is no safe live prompt proof yet. | Needs a manual-gated pass that proves Tab accepts without submitting. |
| Claude desktop | B- | Pending fresh screenshot | Prior verified accepts exist in the manual smoke log | Prior manual proof passed, but it is not current screenshot-backed proof. Full accept is disabled until no-submit proof exists. | Needs a current screenshot-backed one-word prompt pass without submitting. |

## Required Next Proof

1. Run `AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh codex --manual-gate` and keep one trace slice that proves visual placement plus one-word accept without submit.
2. Run Obsidian against a disposable vault note only.
3. Run Notes as three separate labels: `notes-title`, `notes-body`, and `notes-checklist`.
4. Run Claude Code with a harmless prompt fragment and no Enter key.
5. Refresh Claude desktop with screenshot tracing and one-word accept without submit.
6. Replace browser-editor fixture confidence with at least one real CodeMirror, Monaco, and ProseMirror proof pass.

## Proof Rules

- Screenshot proof must link to a committed PNG in
  `docs/product/visual-placement-screenshots/`.
- Accept proof must show verified insertion, not just a visible suggestion.
- Prompt apps must prove accept without submit.
- Private apps must use disposable text only.
- A pending screenshot means the app is not screenshot-backed, even if insertion
  worked before.
