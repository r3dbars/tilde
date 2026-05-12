# Focused Graduation Scorecard

Score: 100/100 for the fail-closed graduation contract.

This does not mean every listed app is supported. It means the current repo
state makes the high-value writing-surface decision set explicit,
machine-checkable, tested, and conservative.

## Rubric

| Area | Points | Requirement |
| --- | ---: | --- |
| Manifest decisions | 30 | `proof-manifest.json` lists exactly the focused surfaces, expected decisions, proof states, bundles, smoke commands, and required proof gates. |
| Compatibility profiles | 20 | Profiles expose `graduationDecision`, prompt apps stay word-only where needed, and unproven collaboration apps route to blocked/no-accept profiles. |
| Smoke guards | 20 | Blocked browser fixtures are accepted labels, print a dry-run plan, and fail before live typing. |
| Product docs | 15 | Compatibility and proof matrices repeat the same focused decisions without claiming unsupported surfaces are ready. |
| Status and tests | 15 | Manual smoke status and unit/self-tests lock the focused decision output. |

Run:

```bash
script/check_graduation_score.sh
```

The script fails below 100. A 100 here is a guardrail score, not a product
readiness score for Google Docs, Notion, Slack, Discord, ChatGPT, Mail, Obsidian
long notes, Monaco, or CodeMirror.
