# Obsidian Deep Sweep Latest

- Started UTC: 2026-05-13T11:00:12Z
- Iterations: 1
- Lanes: obsidian obsidian-theme obsidian-long-note obsidian-font-zoom obsidian-markdown-bold obsidian-markdown-list obsidian-multiline obsidian-run-on obsidian-pane

| Iteration | Lane | Result | Command |
| ---: | --- | --- | --- |

## Summary

- The one-pass deep sweep started at `2026-05-13T11:00:12Z`, but the wrapper did not produce trustworthy lane rows in this desktop session.
- Separate strict runs on the current branch proved two important lanes:
  - `obsidian-long-note` passed at `2026-05-13T10:55:02Z` with 2 accepted insertions and strict visual trace evidence.
  - `obsidian` default passed at `2026-05-13T11:00:07Z` with 2 accepted insertions and strict visual trace evidence.
- A delayed-run `obsidian-theme` proof passed at `2026-05-13T11:20:27Z` with 2 accepted insertions and strict visual trace evidence, after the harness waited for Obsidian frontmost focus and settled before the second phrase/full accept.
- Earlier `obsidian-theme` reruns failed strict visual proof because accepted words landed but extra post-accept/stale Obsidian suggestions were presented without screenshot-backed trace rows. The 11:20 UTC pass recorded `obsidian-post-acceptance-settle` after full accept.
- `AUTOCOMPLETE_LAB_OBSIDIAN_ESCAPE_BEFORE_TYPING=1` is not a safe workaround yet; it can put the CodeMirror field into `suppressedField` / quiet mode and block the next suggestion.
- The goal is still open. This is not a 150+ attempt reliability sample and not a 100/100 Obsidian result.

## Next Gate

Repeat default/theme/pane/long-note/font-zoom/bold/list/multiline/run-on with strict screenshot traces until the matrix can run cleanly enough to become a real 150+ attempt reliability sample.
