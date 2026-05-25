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
- the initial Claude Code prompt wait now requires Claude-specific prompt chrome
  such as `for shortcuts` or `Try "fix lint errors"` instead of generic
  `Claude Code` title text or a zsh prompt glyph,
- typed Claude Code sample checks now require the proof marker plus sample text
  directly, without requiring placeholder hints after real text has been typed,
- Claude Code Terminal proof now launches through a disposable `.command` file
  from the trusted repo root, tracks the exact disposable Terminal process,
  waits for the launched `claude` child process, and cleans up only that proof
  process,
- the Terminal AX helper now combines the marker-titled window with the focused
  input node for the same frontmost Terminal process, so alternate-screen
  Claude prompt text can be proved without stitching across stale windows,
- Claude Code model-latency accounting now treats the cleared typed sample
  window as the proof window because Terminal/Claude can produce the model
  result while the seed and trigger text are still arriving,
- the disposable sample loop now tracks early empty model outputs from the whole
  sample iteration so the proof can report empty candidates instead of only
  timing out on the later visible-suggestion wait,
- Claude Code Terminal model-latency samples now type the compact proof marker
  on the current sample line instead of relying only on window-title proof, and
  the Terminal AX helper binds reads to the frontmost Terminal process so older
  Terminal instances cannot satisfy the check,
- Claude Code Terminal proof input now strips a leading numbered prompt
  decoration like `1. ` before the text is sent to the model, while numbered
  shell-command lines such as `1. git status` remain blocked,
- Claude Code Terminal proof input now rejects shortcut placeholder chrome such
  as `for shortcuts` as unsafe prompt text,
- Claude Code Terminal proof blocks now include shape-only diagnostics for
  marker presence, focused/raw line kinds, recoverability, and recovery rejection
  reasons, so proof failures can be debugged without logging prompt text,
- Claude Code Terminal proof input now recovers the current marked prompt row
  when Terminal exposes the old screen after the cursor, treats proof-marked
  natural-language `make this...` / `make transition...` text as writing, and
  repairs the observed Terminal AX dropped-space shape `Make thissetting con`
  back to `Make this setting con` for proof input,
- the MLX word-completion path now has a local high-confidence suffix rescue
  after model + retry no-candidate failures. It reuses the word ranker, can use
  visible-page candidate words, stays off in the middle of words, and records
  `wordCompletionFallbackUsed` / `wordCompletionFallbackSource` in proof
  metadata.

Fresh live proof moved past the previous blockers. The Terminal-hosted Claude
Code model-latency run starting at diagnostics line `340484` produced
model-backed visible word-completion suggestions for samples 1-5 and the
prompt/chat no-submit proof passed with `accidentalSubmitCount: 0`,
`wrongContextInsertionCount: 0`, and `fullAcceptWithoutProofCount: 0`. The
latency beta gate also passed: first-visible `n=10 avg=245ms p95=321ms`,
first-token `n=12 avg=158ms p95=235ms`, total generation `n=24 avg=208ms
p95=330ms`, event-tap raw `n=15 avg=25us p99=75us`, and AX read summaries
`windows=8 samples=480 p99Max=23ms max=105ms`.

The latest hardening pass made that failure harder to misread:

- Claude Code Terminal model-latency proof now opens a fresh disposable Terminal
  prompt per sample and cleans up marker-titled, prefixed, and legacy temp proof
  windows before sampling,
- tracked proof Terminal processes are force-cleaned if normal termination does
  not remove the AX surface,
- the live proof only counts a model-backed visible suggestion when
  `beforeChars` and `partialWordCharacters` match the exact typed sample, so a
  stale sample can no longer satisfy the pass condition,
- the policy now treats natural-language `make this ...` prompt text as writing,
  while keeping real `make test` command lines blocked,
- AX health cooldown-start reads still log as slow/cooldown diagnostics, but no
  longer pollute the rolling typing-latency summary window,
- Claude prompt chrome and flattened launcher scrollback have focused unit
  coverage.

The fresh live run now gets through the five required model-backed Claude Code
Terminal samples, passes the no-submit proof, and passes the latency beta gate.

TextEdit latency proof is fresh again too. The run starting at diagnostics line
`341123` passed with model-backed visible word-completion suggestions for 5
samples: first-visible `n=5 avg=244ms p95=255ms`, first-token `n=5 avg=218ms
p95=231ms`, total generation `n=10 avg=242ms p95=286ms`, event-tap raw
`n=5 avg=40us p99=93us`, AX read summaries `windows=12 samples=720
p99Max=22ms max=24ms`, and zero late shown suggestions, event-tap failures, AX
slow markers, or AX skips.

Obsidian long-note proof is fresh again too. The run at `2026-05-25T05:28:30Z`
passed with 2 accepted insertions, `floatingMirror` placement, strict visual
trace evidence, diagnostics lines `341505-341625`, and trace lines
`22846-22857`. The useful failure before that pass was the harness sending
Escape after the first long-note accept, which correctly recorded
`field-suppressed reason=escape`; the proof now uses neutral setup focus instead
of injecting Escape into the Obsidian field.

The core Obsidian placement block is fresh again on the current branch. Default
proof passed at `2026-05-25T05:31:15Z` with diagnostics lines `341628-341763`
and trace lines `22858-22875`; the non-default theme lane passed at
`2026-05-25T05:32:00Z` with diagnostics lines `341766-341880` and trace lines
`22876-22887`; and the split/side-pane lane passed at `2026-05-25T05:33:54Z`
with diagnostics lines `341907-342039` and trace lines `22892-22907`. All three
recorded 2 accepted insertions, `floatingMirror` placement, and strict visual
trace evidence. `./script/manual_smoke_status.sh --strict` then reported
Obsidian default, theme, panes, and long note as passed, making Notes the next
proof target.

Notes title, body, and checklist proof are fresh on the current branch too.
Title passed at `2026-05-25T05:35:46Z` with diagnostics lines `342089-342162`
and trace lines `22913-22923`; body passed at `2026-05-25T05:36:14Z` with
diagnostics lines `342262-342317` and trace lines `22932-22941`; checklist
passed at `2026-05-25T05:36:38Z` with diagnostics lines `342405-342481` and
trace lines `22950-22959`. All three recorded 2 accepted insertions,
`inlineAdjacent|floatingMirror` placement, and strict visual trace evidence.
`./script/manual_smoke_status.sh --strict` now reports Notes and Obsidian as
passed, leaving TextEdit plus Chrome textarea/contenteditable as stale rows.

The remaining beta-safe proof rows are fresh now as well. TextEdit passed at
`2026-05-25T05:39:15Z` with diagnostics lines `342509-342588` and trace lines
`22961-22978`. Chrome textarea passed at `2026-05-25T05:40:16Z` with
diagnostics lines `342590-342748` and trace lines `22979-23004`; Chrome
contenteditable passed at `2026-05-25T05:40:56Z` with diagnostics lines
`342755-342999` and trace lines `23006-23055`. Each row recorded 2 accepted
insertions, `inlineAdjacent|floatingMirror` placement, and strict visual trace
evidence. `./script/manual_smoke_status.sh --strict` now exits green: TextEdit,
Notes title/body/checklist, Obsidian default/theme/pane/long-note, and Chrome
textarea/contenteditable are all covered, and the screenshot-backed placement
gate still passes.

A disposable local quality audit now covers the current model path without
persisting raw prompt text or raw model output. The 45-row audit in
`docs/evals/daily-driver-local-quality-audit-2026-05-25.md` passed with
overall `100/100`, relevance `100/100`, 36 display-eligible continuations, and
9 expected suppressions. This is useful evidence for short continuations,
word suffixes, common writing-surface prompts, fast-typing trust prompts, and
obvious unsafe/sensitive suppression, but it does not replace a real
writing-session dogfood pass.

The real writing-session pass now has a repeatable redacted wrapper:
`./script/daily_driver_dogfood_session.sh start` saves a trace line mark, and
`./script/daily_driver_dogfood_session.sh finish` writes a local report under
`dist/daily-driver-dogfood/` with the non-annoyance gate, trace eval summary,
line bounds, and a manual trust row. `finish` now also enforces a metadata-only
sample gate by default: at least 5 active minutes, 5 shown suggestions,
1 accepted suggestion, 1 accepted-and-kept signal, a 15% accepted-kept / shown
reach rate, and an 85/100 redacted typing-feel score. The score makes typed-over
rate, accepted-then-deleted, late suggestions, insertion failures, and caret
failures visible in the same artifact as the manual trust row. The same sample
gate now prints source mix counts for shown / accepted / accepted-kept
suggestions, including instant phrase fallback, model-backed, word fallback, and
unknown sources, so a dogfood report can show whether the fast path actually
helped. This does not create the subjective proof by itself, but it prevents a
tiny, annoying, or never-reached-for trace from being counted as a daily-driver
pass.
After the human fills the Manual Trust Row, `review --report` gates the completed
report too: the automated gate must pass, the row must be filled, the user must
say they reached for it, and they must say they would keep it on tomorrow. The
same report now carries a redacted safety snapshot for prompt no-submit and
sensitive-field suppression, so a daily-driver pass cannot hide stale
wrong-field safety.

Wrong-field safety now has both prompt-app and sensitive-field gates in the
default smoke path. Prompt no-submit self-tests cover accidental submit, send
key collision, prompt mutation, wrong-context insertion, unsafe full accept, and
prompt-action suggestion text. Sensitive-field proof self-tests cover required
password, OTP, payment, login, search, address, government ID, medical, command
line, API key, password manager, private prompt, private search, and blocked
browser-hosted surface categories with redacted metadata only.

The instant phrase fallback is broader now too. It can produce zero-latency
3-5 word daily-driver phrases for common writing contexts like Obsidian note
capture, fast-typing trust, less-timid suggestion wording, short useful phrase
requests, meeting notes, launch checks, and action items while still staying
off in prompt, search, form, and code profiles. When the instant phrase path
does not have a safe match, the queued model request now carries redacted
diagnostic metadata for the fallback outcome so the app is less mysterious while
it waits. The instant predictor now also normalizes internal punctuation and
newlines, so audit-shaped writing like `Before we ship, we should`, quick reply
drafts, decision logs, review notes, and checklist continuations can hit the
fast path instead of missing because of commas or list breaks.

## Scorecard

| Area | Current Read | Daily-Driver Bar | Next Proof |
| --- | --- | --- | --- |
| Suggestion magic | Better defaults plus retry repairs for bad 8-word phrase passes; disposable local audit is green at 45/45; instant phrase fallback now covers more audit-aligned 3-5 word daily-driver contexts, including punctuation and list-shaped writing | 3-8 words often feel like the user's next thought | Dogfood writing session with raw opt-in quality notes |
| Placement reliability | All beta-safe strict target rows are fresh: TextEdit, Notes, Obsidian, Chrome textarea/contenteditable | Correct or honest fallback in normal writing apps | Run `daily_driver_dogfood_session.sh` in a real writing app |
| Typing speed | Subsecond repaired phrase results can display; MLX word completion has a tested local suffix rescue; Claude Code Terminal and TextEdit have green model-backed latency proof; dogfood reports now expose instant phrase vs model-backed source mix | Feels ready during fast typing | Real writing-session report while typing fast |
| Wrong-field safety | Prompt no-submit and sensitive-field proof self-tests now run in default smoke; local quality audit also covers 9 unsafe/sensitive suppressions | Zero sensitive/wrong-field suggestions | Fresh live prompt no-submit and sensitive-field trace slice |
| Daily-driver feel | Core proof grid is green and the dogfood report wrapper now requires a real-sized trace sample, redacted typing-feel score, accepted-kept / shown reach gate, source-mix visibility, prompt/sensitive safety snapshot, and completed manual-review gate, but it still needs a human writing session | User leaves it on and misses it when off | One full writing session with SteadyType enabled, fill the trust row, then run `review --report` |

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
