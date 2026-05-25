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

Cycle 2 makes Obsidian default/theme/pane proof more repeatable and makes
phrase mode less fragile when the first model pass is bad:

- daily-driver phrase retry now repairs too-short, weak, and missing phrase
  candidates for 8-word mode,
- retry prompts explicitly tell the runtime not to restart or repeat the text
  before the cursor,
- phrase ranking penalizes current-line restarts like repeating `Smoke proof`,
  while still allowing typo-fragment recovery from earlier lines,
- yellow-profile daily-driver phrases can display inside a subsecond repair
  budget instead of being hidden as too slow,
- Obsidian proof setup now seeds the note before launching SteadyType, preserves
  marker spacing, avoids pre-accept AX reads that move the CodeMirror caret, and
  verifies the accepted text after each keypress,
- split-pane CodeMirror AX reads now repair hidden document-spacer coordinate
  drift before treating short visual-line tails as real after-cursor text,
- the pane proof harness explicitly moves the visual caret to the line end after
  AX setup so key-event insertion happens in the intended pane,
- strict trace evaluation now treats repeated rows for the same suggestion ID as
  one visual proof group so streaming/final rows share the same screenshot
  evidence.

Validation from the cycle so far:

- `swift test --jobs 1` passed with 1339 tests.
- `./script/check_quality_eval.sh` passed.
- `./script/check_trace_eval_self_test.sh` passed.
- Obsidian default, theme, and pane smokes passed with two verified insertions
  and strict visual trace evidence.
- `./script/manual_smoke_status.sh --strict` reports Obsidian default/theme/pane
  current for the app build, with TextEdit, Notes, Obsidian long note, and Chrome
  fixture rows still stale.

Cycle 3 keeps prompt proof honest while the faster typing lanes are hardened:

- Claude Code Terminal model-latency proof now scopes its AX readiness check to
  the marker-titled disposable Terminal window instead of mixing marker text
  from one Terminal window with prompt text from another,
- the initial Claude Code prompt wait now requires prompt chrome such as
  `for shortcuts` or `>` instead of generic `Claude Code` title text,
- the disposable sample loop now tracks early empty model outputs from the whole
  sample iteration so the proof can report empty candidates instead of only
  timing out on the later visible-suggestion wait,
- Claude Code Terminal proof input now strips a leading numbered prompt
  decoration like `1. ` before the text is sent to the model, while numbered
  shell-command lines such as `1. git status` remain blocked.

Fresh live proof is still not green: the current Terminal-hosted Claude Code
model-latency run now reaches the MLX word-completion path with the numbered
decoration removed, but the word-completion output still cleans to zero
candidates for the sanitized prompt. Subsequent Terminal AX reads then include
scrollback and hit the multiline-command blocker. That remains a proof blocker,
not a support claim.

## Scorecard

| Area | Current Read | Daily-Driver Bar | Next Proof |
| --- | --- | --- | --- |
| Suggestion magic | Better defaults plus retry repairs for bad 8-word phrase passes | 3-8 words often feel like the user's next thought | Dogfood writing session with raw opt-in quality notes |
| Placement reliability | Obsidian default/theme/pane have fresh strict visual proof; TextEdit, Notes, long-note, and Chrome rows remain stale | Correct or honest fallback in Obsidian first | Refresh Obsidian long-note, then TextEdit/Notes |
| Typing speed | Subsecond repaired phrase results can display; Claude Code Terminal latency proof reaches MLX with sanitized prompt text but still cleans empty | Feels ready during fast typing | Fix Claude Code word-completion no-candidate path, then refresh Obsidian/TextEdit latency proof |
| Wrong-field safety | Unit and eval gates pass | Zero sensitive/wrong-field suggestions | Fresh prompt no-submit and sensitive-field proof |
| Daily-driver feel | User gut baseline: about 60%; Obsidian default is less flaky but not enough | User leaves it on and misses it when off | One full writing session with SteadyType enabled |

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
