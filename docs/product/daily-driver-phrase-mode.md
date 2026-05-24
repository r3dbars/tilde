# Daily Driver Phrase Mode

SteadyType should feel like a typing accelerator, not a cautious word
completer.

The daily-driver target is short-phrase autocomplete:

- predict 3-8 useful next words in writing fields,
- show up quickly while someone is typing fast,
- let `Tab` accept the next word or chunk,
- let the full-accept shortcut accept the visible phrase only where proven safe,
- stay out of sensitive, wrong, unsupported, and submit-like fields,
- explain why it stayed quiet when it does not show a suggestion.

## Product Bar

The app gets closer to daily-driver quality only when all three improve:

- **Suggestion magic:** the suggestion feels like what the user was about to
  type, not a dictionary suffix.
- **Placement reliability:** the suggestion appears at the right text location
  or uses an honest fallback.
- **Typing speed:** the suggestion feels ready before the user thinks about it.

Literal sub-millisecond model inference is not the target. The target is
instant-feeling behavior: warm runtime, speculative requests, cached candidates,
fast cancellation, and immediate accept.

## Current Cycle

Cycle 1 moves the default behavior toward daily-driver phrase mode:

- default visible phrase length is 8 words / 20 generated tokens,
- default tuning is Very Proactive,
- phrase help starts after 2 words,
- response speed defaults to Instant,
- confidence defaults to Loose,
- learned restraint defaults to Low,
- medium-confidence phrase candidates can pass through display scoring,
- green writing contexts can prefer phrase continuations over word-tail
  completions when there is enough context.

This is not enough by itself. It changes the default posture from timid to
useful, but it still needs real Obsidian/TextEdit/Notes/browser proof.

Validation from the cycle:

- `swift test --jobs 1` passed with 1330 tests.
- `./script/check_quality_eval.sh` passed.
- `./script/check_test_coverage_manifest.sh` passed.
- `git diff --check` passed.
- `./script/manual_smoke_status.sh --strict` still reports stale app/source
  proof for the current UI targets. That is the next blocker, not a product
  claim.

## Scorecard

| Area | Current Read | Daily-Driver Bar | Next Proof |
| --- | --- | --- | --- |
| Suggestion magic | Better defaults, still unproven live | 3-8 words often feel like the user's next thought | Run local quality eval and dogfood writing session |
| Placement reliability | Existing proof gates are still the truth | Correct or honest fallback in Obsidian first | Fresh Obsidian visual/manual smoke proof |
| Typing speed | Defaults request sooner, full tests pass, live latency still stale | Feels ready during fast typing | Fresh latency proof with phrase mode |
| Wrong-field safety | Unit and eval gates pass | Zero sensitive/wrong-field suggestions | Fresh prompt no-submit and sensitive-field proof |
| Daily-driver feel | User gut baseline: about 60% there | User leaves it on and misses it when off | One full writing session with SteadyType enabled |

## Long-Running Loop

Each improvement cycle should:

1. Re-score this page honestly.
2. Pick the highest daily-driver blocker.
3. Make one meaningful code or proof change.
4. Add/update tests.
5. Run focused validation.
6. Commit and push.
7. Continue unless blocked by real manual proof or user direction.

Do not broaden support claims before proof. Obsidian should feel meaningfully
better before Slack, iMessage, prompt apps, or terminal hosts are treated as
normal writing surfaces.
