# Intent Futures v1

Intent Futures is Tilde's first semantic belief state above raw next-token prediction.

## Goal

Before much text exists, infer a few broad directions a reply could take. As the user begins typing, re-rank those directions deterministically and pass only the fixed-vocabulary summary to the existing local completion prompt.

Examples:

- "Are you still coming tonight?" -> answer / accept / decline / clarify
- typing `Ye` -> accept rises to the top
- typing `Which` -> clarify/question rises
- typing `I'll` -> commit rises

## Non-goals

- No second model call.
- No background generation yet.
- No claim that weights are calibrated probabilities.
- No persistent intent history.
- No raw conversation text duplicated into diagnostics or intent metadata.

## Contract

`IntentFuturesPlanner` is pure Core logic over `ScreenScene.Scene` plus the current field text. It returns at most four broad futures. `IntentPromptHint` converts them to fixed enum labels and relative weights for the existing prompt.

The screen conversation itself continues to flow through ScreenScene's existing privacy/redaction path. Intent Futures adds only labels such as `accept:54` or `clarify:31`.

## Next measurements

Once replay can exercise live scenes, measure:

1. top intent direction versus the user's eventual speech act;
2. how quickly the correct future rises as characters arrive;
3. whether intent hints improve Oracle@K / ExactMatch@1;
4. whether incorrect high-confidence futures increase bad ghosts.

Intent Futures should remain simple until those measurements show where richer intent representations are actually useful.
