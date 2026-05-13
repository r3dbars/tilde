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
- Fresh `obsidian-theme` reruns still failed strict visual proof. The accepted words landed and verified, but extra post-accept/stale Obsidian suggestions were presented without screenshot-backed trace rows.
- A patched `obsidian-theme` rerun at 11:12 UTC armed the new post-acceptance settle gate after the first accepted Tab and verified that insertion, but it still did not complete because focus jumped back to Codex before the second accept.
- `AUTOCOMPLETE_LAB_OBSIDIAN_ESCAPE_BEFORE_TYPING=1` is not a safe workaround yet; it can put the CodeMirror field into `suppressedField` / quiet mode and block the next suggestion.
- The goal is still open. This is not a 150+ attempt reliability sample and not a 100/100 Obsidian result.

## Next Gate

Keep Obsidian quiet after accepted text, rerun `obsidian-theme`, then repeat default/theme/pane/long-note/font-zoom/bold/list/multiline/run-on until the matrix can run cleanly with strict screenshot traces.
