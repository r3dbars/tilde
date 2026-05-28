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

- app-owned model phrase length is 8 words / 20 generated tokens,
- user-facing default visible phrase length is 8 words,
- default phrase guidance now aims for 3-8 words instead of allowing 1-word
  phrase nubs at the larger cap,
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

Cycle 2 follow-up keeps instant fallbacks trustworthy while the model refines:

- a visible fast phrase suggestion now survives soft model suppression such as
  low-confidence or below-threshold final results, as long as it is still young,
  in the same field, and not invalidated by user typing,
- risky model suppression still hides the current suggestion instead of
  preserving something unsafe,
- user typing that invalidates the visible suggestion now lets a stronger fresh
  replacement show, so an old phrase does not block the next phrase in the same
  note,
- Notes proof accepts now wait briefly for a fresh keyboard event tap marker
  before sending `Tab` or the full-accept shortcut, which makes proof races
  easier to separate from real insertion failures,
- Notes, TextEdit, and Chrome proof setup now reasserts the target app/caret at
  the fragile accept and undo moments before counting the row.

Validation from the follow-up:

- `swift test --jobs 1 --filter SuggestionReplacementVisibilityPolicyTests`
  passed.
- `swift test --jobs 1 --filter SuggestionOrchestratorTests/replacementDecisionUsesVisibleAgeAndScoreMargin`
  passed.
- `./script/real_app_smoke_self_test.sh` passed.
- `./script/manual_smoke_status.sh --strict` now passes on commit
  `1969992ddcf5`: TextEdit, Notes title/body/checklist, Obsidian
  default/theme/pane/long-note, Chrome textarea, and Chrome contenteditable are
  all current or source-compatible.
- The latest current rows include TextEdit diagnostics lines `952925`-`953019`,
  Notes checklist lines `954328`-`954420`, Obsidian default/theme/pane/long-note
  lines `954425`-`955313`, Chrome textarea lines `953772`-`953982`, and Chrome
  contenteditable lines `953989`-`954228`.
- Each refreshed row records 2 accepted insertions and strict visual trace
  evidence.

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
`833722` passed with model-backed visible word-completion suggestions for 5
samples: first-visible `n=5 avg=253ms p95=258ms`, first-token `n=5 avg=228ms
p95=233ms`, total generation `n=10 avg=252ms p95=293ms`, event-tap raw
`n=5 avg=40us p99=89us`, AX read summaries `windows=10 samples=600
p99Max=25ms max=25ms`, and zero late shown suggestions, event-tap failures, AX
slow markers, or AX skips.

Cold TextEdit phrase proof is fresh too. The run starting at diagnostics line
`352820` passed the default model proof with a current app-owned Qwen3.5 4B
launch: launch-to-ready `2000ms`, cold model load `1699ms`, runtime warm
`1786ms`, phraseContinuation `max tokens: 14`, model total `n=17 avg=498ms
p95=593ms max=599ms`, and shown phrase latency `n=13 avg=547ms p50=541ms
p95=619ms max=650ms`. That run also proved stale visible TextEdit geometry no
longer cancels a fresh current-text phrase request before the model can answer.

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

After the daily-driver app-source changes, the strict beta-safe proof grid was
refreshed again on commit `15a6f895d091`. TextEdit passed at
`2026-05-25T09:59:14Z` with diagnostics lines `347643-347722` and trace lines
`23057-23074`; Notes title/body/checklist passed at `2026-05-25T09:59:37Z`,
`2026-05-25T09:59:58Z`, and `2026-05-25T10:00:21Z`; Obsidian
default/theme/pane/long-note passed at `2026-05-25T10:00:58Z`,
`2026-05-25T10:01:32Z`, `2026-05-25T10:02:18Z`, and
`2026-05-25T10:03:20Z`; Chrome textarea/contenteditable passed at
`2026-05-25T10:03:57Z` and `2026-05-25T10:04:51Z`. Each row recorded 2
accepted insertions and strict visual trace evidence, and
`./script/manual_smoke_status.sh --strict` now passes on the current build.

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
1 phrase suggestion, 1 instant phrase fallback with <=1ms recorded latency,
1 accepted suggestion, 1 accepted-and-kept signal, a 15% accepted-kept / shown
reach rate, and an 85/100 redacted typing-feel score.
Phrase suggestions must carry metadata proving at least 3 visible words, so a
session cannot pass with timid one-word or two-word phrase nubs. The score makes
typed-over rate, accepted-then-deleted, late suggestions, insertion failures,
and caret failures visible in the same artifact as the manual trust row. A
separate trust-killer gate now fails the report on wrong-context suppressions,
failed or duplicate insertions, caret geometry failures, sensitive-field or
unsupported-app displays, detached placement without a caret, focus steals, Tab
conflicts, accepted-then-deleted signals, prompt-submit risk, unsafe full
accepts, and prompt content violations. The same sample gate now prints source
mix counts for shown / accepted / accepted-kept
suggestions, including instant phrase fallback, model-backed, word fallback, and
unknown sources, and fails when the fast phrase path never appears or appears
late, so a dogfood report proves whether instant speculation actually helped.
The same report now summarizes no-show reasons and triggers for
`suggestionSuppressed` events, so a dogfood pass can explain whether SteadyType
stayed quiet because the model returned nothing useful, instant fallback missed,
typing was stale, placement blocked, or another blocker fired. This does not
create the subjective proof by itself, but it prevents a tiny, annoying,
invisible, or never-reached-for trace from being counted as a daily-driver pass.
After the human fills the Manual Trust Row, `review --report` gates the completed
report too: the automated gate must pass, the row must be filled, the user must
say they reached for it, suggestion quality must be scored 4 or 5, and they
must say they would keep it on tomorrow. The manual row must also match the
report's app filter, meet the same active-minute minimum as the trace gate, and
avoid describing placement as wrong, weird, detached, or unstable. The same
report now carries a redacted safety snapshot for prompt no-submit and
sensitive-field suppression, so a daily-driver pass cannot hide stale
wrong-field safety.
The dogfood `start` command now records whether SteadyType was running when the
session began, whether the trace already existed, and a readiness verdict. The
finished report carries the same start-readiness fields, so a session that was
accidentally started while the app was off fails the dogfood gate instead of
looking like valid daily-driver proof. The dogfood `status` command is now a
preflight too: it reports whether the trace exists, whether SteadyType is
running, warns to run `./script/build_and_run.sh --verify` when the app is off,
shows the saved mark, rows since the mark, the redacted app filter, and the
exact next start/finish/review command.
When the session has new trace rows, it also runs the metadata-only sample gate
as a preview, so the tester can see shown suggestions, phrase suggestions,
accepted-kept reach, source mix, and no-show reasons before finishing the
report. It now previews the redacted trust-killer gate too, so insertion
failures, wrong-context suppressions, caret geometry failures, sensitive-field
presentations, prompt submit risks, and other daily-driver trust breaks are
visible before `finish`. The same status preflight now previews the redacted
typing-feel score as well, making slow suggestions, typed-over suggestions,
accepted-then-deleted text, immediate resurfacing, insertion failures, and caret
failures visible while the session is still happening. That makes the remaining
manual proof less likely to fail because of a stale mark, rotated trace,
forgotten finish command, too-small sample, already-bad trust signal, or a
session that feels heavy before it ever reaches the report.

Wrong-field safety now has both prompt-app and sensitive-field gates in the
default smoke path. Prompt no-submit self-tests cover accidental submit, send
key collision, prompt mutation, wrong-context insertion, unsafe full accept, and
prompt-action suggestion text. Prompt full-accept now has its own no-submit
proof mode, and normal prompt proof still fails if full accept appears without
that separate manifest and smoke-row evidence. Sensitive-field proof self-tests
cover required password, OTP, payment, login, search, address, government ID,
medical, command line, API key, password manager, private prompt, private
search, and blocked browser-hosted surface categories with redacted metadata
only.

The instant phrase fallback is broader now too. It can produce zero-latency
3-8 word daily-driver phrases for common writing contexts like Obsidian note
capture, fast-typing trust, less-timid suggestion wording, short useful phrase
requests, meeting notes, launch checks, and action items while still staying
off in prompt, search, form, and code profiles. Obsidian-style daily notes now
also get instant section-label continuations for headings and list rows like
Focus, Today, Waiting on, Blocked, Risks, Done, Idea, and Note to self. When the
instant phrase path does not have a safe match, the queued model request now
carries redacted diagnostic metadata for the fallback outcome so the app is
less mysterious while it waits. The instant predictor now also normalizes
internal punctuation and newlines, so audit-shaped writing like `Before we
ship, we should`, quick reply drafts, decision logs, review notes, and checklist
continuations can hit the fast path instead of missing because of commas or list
breaks.

Fast typing bursts now keep the instant loop alive. Partial-word completions can
still show during the type-accept-type loop, and phrase continuations get one
zero-latency fallback attempt before the heavier model phrase is paused for the
burst. The default detector now catches roughly 70 wpm typing by watching for 6
inserted characters inside a 1.1 second window.

The live status text is less mysterious too. The menu tooltip and Settings
`Why:` row now say whether the shown suggestion is a word, phrase, or sentence,
and whether it came from the instant fallback, fast word fallback, or model path.
When nothing appears after a request, the same line now says whether SteadyType
stayed quiet because there was no useful suggestion, no fast word match, no
cursor position, a repeated miss, stale text, or a model error.

The instant phrase predictor now covers the daily-driver complaint language
directly: "I want this to", "the biggest problem is", "what kills trust most
is", "it should almost always", "when I hit Tab it should", and "the best daily
driver shape is" can all produce 3-6 word zero-latency continuations in writing
profiles while still staying off in prompt, search, form, and code profiles.
It now also covers more finish-my-thought writing: "I think what matters is",
"what I am trying to say is", "this would be better if it", "what makes this
useful is", and "when this feels magical it" can produce 4-word continuations
without waiting for the model path.
It now handles first-person daily-driver trust and feeling shapes too:
"this app feels wrong", "the suggestions fall short", "not quite there",
"use this every day", "make me use this", "keep reaching for it when", and
"as a daily driver" can produce 4-6 word continuations in writing profiles.
Prompt, search, form, and code profiles stay blocked for those patterns.
The same instant path now has a small intent-pattern layer too, so reusable
sentence endings like "what I mean is", "my point is", "the app would be better
if it", "we need to", "next step is", "the goal is", and "can you" can produce
4-word writing continuations without needing an exact canned prior. These
patterns still stay behind the same profile gates, so prompt, search, form, and
code surfaces remain blocked.
It now has a guarded connector-thought layer for daily-driver writing too:
when the surrounding words are about SteadyType, suggestions, typing, writing,
or trust, endings like "because", "so that", "which means", "the reason is",
"the fix is", and "we should prove" can produce 4-word zero-latency
continuations. This makes the instant path less like canned autocomplete and
more able to finish a real thought, while still staying off prompt, search,
form, and code profiles.

The everyday reply layer is broader now too. Email and casual-chat writing
profiles can produce safe short continuations for common reply starts like
`Good call`, `All good`, `Let me know`, `Checking in`, `I'll take`, `I'm on`,
`Appreciate you`, and `Thanks again`, while prompt, search, form, and code
profiles still stay gated out of that fallback path.

For the Obsidian lane, the instant predictor now recognizes markdown note
labels and current-line note shapes. Trusted writing profiles can get
zero-latency continuations for lines like `## Next:`, `TODO:`, `Open
questions:`, `Decisions:`, `What matters today`, `Before I forget`, and
`Follow up on`, while email, prompt, search, form, and code profiles stay out
of that markdown-label path.
The Obsidian daily-driver trigger path now asks for those phrases after short
list and checklist labels too, so `- TODO:`, `- [ ] Next:`, and numbered
checklist labels can reach the instant markdown-label predictor instead of
being treated as word-completion-only list rows.

The instant phrase path now listens to accepted-and-kept learning too. After
enough local evidence that accepted instant phrases are not being kept for the
current app, field kind, request mode, and writing profile, SteadyType skips
that zero-latency canned phrase and queues the model phrase instead. The trace
metadata stays redacted and the live status can say `Quiet: recent rejects`, so
the app is less mysterious when it chooses restraint. The dogfood status and
report now also print `Instant phrase learned restraint`, so a session can show
when SteadyType skipped a canned phrase because local learning said it was not
helping.

The status surface now treats `Quiet:`, `Hidden:`, and paused no-show decisions
as truly quiet in the menu, settings, and diagnostics presentation. This closes
one trust leak where intentional silence could previously look like generic
ready state instead of telling the user why no suggestion appeared.

Field-safety trust language is instant now too. In writing profiles, phrases
like `If the focused field looks risky, it should`, `When the wrong field
should`, and `If placement feels weird, it should` can produce zero-latency
fail-closed continuations, while email, prompt, search, form, and code profiles
stay gated out of that path.

Very-proactive writing surfaces now keep going at sentence boundaries too. When
the user finishes a sentence in TextEdit, Notes, Obsidian, or another non-prompt
writing profile, the activation and trigger policies can queue the next
short-phrase continuation instead of going quiet. Prompt surfaces keep the older
sentence-boundary block, so Codex, Claude, and terminal-host proof lanes do not
get broader phrase behavior from this change.

Ghostty-hosted Claude Code is still an honest host-specific proof gap as of
May 27, 2026. The prior live run exposed the wrong trust shape: SteadyType
showed a suggestion near Ghostty's top/header AX text while the real prompt was
lower in the terminal, then no insertion source verified. Title-scoped Ghostty
proof now rejects stale Claude header text, date/build text, and digit-heavy
header tails unless screen recovery finds the real prompt line. The policy can
now recover a proof marker from Ghostty's terminal header/screen only when the
current AX fragment still matches the recovered prompt row, and it allows
Claude prompt box chrome after that row without treating the chrome as input.
The follow-up code now has a proof-only Ghostty screen-prompt anchor and a
terminal-prompt caret estimator that places from the prompt's distance to the
terminal bottom, not from stale header rows. `swift test --filter
ClaudeCodeTerminalHostProofPolicyTests --jobs 1` passed with 79 tests, `swift
test --filter SyntheticCaretEstimatorTests --jobs 1` passed with 13 tests, and
`swift test --jobs 1` passed with 1,479 tests.

The latest live `AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1
./script/real_app_smoke.sh claude-code-ghostty --manual-gate` run moved the
Ghostty lane one step closer to real support. Diagnostics line `587984` showed a
prompt-row suggestion with `anchorRect=x=130,y=862,w=0,h=22`,
`suggestionPanelRect=x=130,y=862,w=138,h=24`,
`placementAnchorSource=synthetic-caret`, `traceID=07FC7F01`, and
`latencyMilliseconds=456`; a later retry also emitted
`synthetic-caret ... source=terminal-screen-prompt` and `traceID=128BDDCD`.
The smoke then reached Tab acceptance and the verified insertion ladder, but
every Ghostty insertion source stayed unverified, so SteadyType refused the
unsafe insert with `keyboard-action ... handled=false ... reason=insert-failed`.
That is not support yet, but the trust shape is better: prompt-row placement is
real and the next proof target is a verified one-word no-submit Ghostty insertion
source.

The next harness pass made that diagnosis sharper. Ghostty insertion now tries a
terminal-scoped `send key` AppleScript rung before global System Events and CG
key-event fallbacks, with baseline checks that stop if the prompt mutates
without verification. The smoke harness also now scans actual diagnostics line
numbers for prompt-row virtual Claude Code suggestions instead of reporting
`no visible suggestion` after the app already showed one. Fresh live attempts
proved the detector can find the prompt-row suggestion; the remaining live
runner problem is focus ownership between Codex/Atlas and the disposable
Ghostty window before Tab, so the next useful step is a reliable host activation
or in-app Ghostty accept path that reaches the new send-key rung.

The follow-up focus hardening now targets the disposable Ghostty process by PID
inside the terminal AX helper, reactivates that exact process before prompt
clearing, proof typing, prompt-readiness checks, and Tab hot accept, and uses a
fresh HID CGEvent keypress helper so the harness does not intentionally
inherit modifier state. That moved the live proof farther again: current
diagnostics show Ghostty prompt-row suggestions at lines `596949` and `596952`
with `traceID=599076D1`, then later prompt-row suggestions with
`traceID=B2C3B98D`. The run is still not green because the Codex desktop runner
can inject a real Command-Tab before the scripted accept, hiding the visible
suggestion before SteadyType can handle Tab. The next proof needs either a
runner-isolated live pass or an accept driver that cannot be preempted by the
Codex app regaining focus.

The harness now treats those focus steals as disposable-context failures instead
of letting stale Ghostty state poison the next sample. If focus is lost while
clearing, typing, proving prompt readiness, or refreshing a hidden suggestion,
the smoke launches a fresh title-marked Ghostty/Claude Code process before the
next proof text. Fresh process activation failures now fail with a focused
runner error instead of continuing against a dead PID. This still does not make
Ghostty supported, but it narrows the remaining proof gap to runner-isolated
Tab acceptance or an accept driver that SteadyType can observe without Codex
preempting the target window.

The runner-isolated path now has a concrete wrapper:
`./script/claude_code_ghostty_detached_proof.sh start` launches the same
Ghostty one-word no-submit proof through a short-lived LaunchAgent and writes
status/logs under `dist/claude-code-ghostty-detached-proof/`. Use
`./script/claude_code_ghostty_detached_proof.sh wait` to collect the result; the
wait path also unloads the completed LaunchAgent. The first real launchd run
survived Codex shell cleanup and found the Claude CLI, but it failed before
prompt placement because the frontmost disposable Ghostty PID exposed no AX text
nodes or marker window to the prompt helper. This is still proof infrastructure,
not Ghostty support; support only starts after that detached run proves
prompt-row placement and verified one-word insertion without submitting the
prompt.

The detached runner is now Terminal/nohup-based by default, has a `stop` command,
and no longer wedges on Ghostty's native `input text` AppleEvent. The proof
harness now uses HID CGEvent Unicode text for Ghostty setup typing, records the
diagnostics line immediately before the final trigger character, refuses older
prompt-row suggestions from before that trigger, bounds stale cleanup and
fallback Tab paths, rejects low-y/header suggestions unless the app has emitted
`source=terminal-screen-prompt`, and can bridge same-line prompt-prefix
suggestions after the final trigger. The app side also re-verifies
proof-sensitive Claude Code prompt input after Ghostty AX identity wobble and
preserves one-word key capture for virtual Claude Code proof suggestions across
host-profile churn.

Live detached runs are still non-green, but the failure has moved again. The
current branch now uses a title-marked Ghostty focus helper before activation
and fallback Tab, the app-side Ghostty insertion ladder searches the title-marked
proof window before every native insertion attempt, and Ghostty Claude Code proof
now refuses generic `text-area-estimate` top/header carets when
`terminal-screen-prompt` recovery is missing. The newest app-side patch keeps
actively reused prompt-row anchors fresh, prevents hidden suggestions from
satisfying the primary scanner, lets explicit Claude Code terminal-host proof
candidates bypass final-result latency suppression, and preserves a still-valid
pending phrase request when focused-text polling slows down during the proof.
The harness also no longer treats the current SteadyType app bundle as a foreign
proof process during exclusive cleanup. The latest insertion pass adds two
verified hardware-key sources, switches the guarded System Events rung from bulk
keystroke text to paced per-character typing, and adds a native Ghostty
`paste_from_clipboard` action rung with pasteboard restore and unchanged-prompt
baseline proof. `20260527T192644Z-ghostty` found the fresh prompt-row suggestion
at diagnostics line `736550`, but failed before insertion because CGEvent Tab
never produced a `key=tab` diagnostic and the fallback focus helper rejected the
proof window. After relaxing that runner-side focus check to trust the
title-scoped Ghostty scripting target, `20260527T192922Z-ghostty` found a
prompt-row suggestion at line `737484`, captured Tab at line `737815`, and ran
the expanded Ghostty insertion ladder, including the new native paste action at
line `737840`. That is the right next red bar: native Ghostty
action/input/paste, terminal-scoped send key, paced System Events, targeted
hardware keys, global hardware keys, bundled Unicode helpers, direct Unicode
events, and pasteboard insertion all left the prompt unchanged, so SteadyType
failed closed at lines `737883` and `737885`. The next useful proof slice is
still a verified one-word no-submit Ghostty insertion transport, not broader
suggestion or placement work.

The newest Ghostty proof slice rules out one more misleading path. A standalone
external shell probe can type into a fresh Ghostty/Claude prompt with System
Events, but the app-originated direct and shell-launched System Events rungs do
not mutate the proof prompt. `20260527T200755Z-ghostty` found the prompt-row
suggestion, captured Tab, posted direct bulk System Events
(`ghosttySystemEventsBulkKeystrokeShell verified=false`), posted shell-launched
bulk System Events (`ghosttySystemEventsLoginShellBulkKeystroke verified=false`),
then kept failing closed through the rest of the insertion ladder. That keeps
the Ghostty gap narrow and honest: the app can place, show, and accept-route the
candidate, but it still lacks a verified app-owned insertion transport.

The follow-up System Events foregrounding pass removed another ambiguous
failure. `20260527T203149Z-ghostty` found prompt-row suggestions at diagnostics
lines `752131` and `752812`; after the first Tab injection produced no key
diagnostic, the fresh second context captured Tab and ran the insertion ladder.
Direct bulk System Events, shell-launched bulk System Events, and paced
per-character System Events all exited `0` after foregrounding Ghostty, but all
three still verified `false`. The app is no longer confused about focus at that
rung; it still cannot make Ghostty/Claude mutate the proof prompt from an
app-owned insertion transport.

The exact-PID follow-up keeps that failure narrow. `20260527T204323Z-ghostty`
again found a prompt-row suggestion at diagnostics line `756273`, captured Tab,
and ran the native Ghostty/System Events ladder while targeting the proof
Ghostty process by Unix pid. Native action text, native input text, native
paste, send-key, foregrounded System Events, hardware, Unicode, and pasteboard
rungs still left the disposable prompt unchanged, then failed closed with
`ghosttyFastFailClosed` and `keyboard-action handled=false
reason=insert-failed`. Ghostty stays unsupported until the detached proof exits
`0` with verified one-word no-submit insertion.

The follow-up exact-PID event-posting slice made the next failure more legible.
`20260527T210539Z-ghostty` found a prompt-row suggestion at diagnostics line
`763147`, lost the first accept attempt after Tab produced no key diagnostic,
relaunched a fresh context, then found another prompt-row suggestion at line
`764044`. Exact-PID reassertion verified before hardware, bundled-helper, and
pasteboard rungs; the prompt still stayed unchanged through the insertion
ladder. The bundled helper now reports the real mismatch shape:
`frontmost pid mismatch actual=39183 expected=82940`, meaning NSWorkspace can
see Ghostty's root pid while System Events tracks the exact title-marked proof
process. The helper now accepts a System Events exact-PID frontmost proof for
that split, but the next two detached attempts did not reach insertion because
focus moved away before accept / the proof process did not become frontmost.
Ghostty remains a proof gap, not a supported host.

The latest harness pass removed several runner-level false negatives without
calling Ghostty supported. The timed AppleScript wrapper now preserves heredoc
stdin for background `osascript` calls, the Ghostty launcher verifies/retries
the disposable proof command, restamps the proof title with Ghostty's native
`set_surface_title`/`set_tab_title` actions after Claude starts, and uses native
Ghostty text input for the marked setup text before a final CGEvent trigger.
A direct `claude-code-ghostty` smoke now gets past launch and prompt typing, but
diagnostics line `789456` still reports no visible suggestion because placement
requires a terminal-screen prompt anchor. That is the next honest red bar:
Ghostty can now be launched and marked by the harness, but SteadyType still
refuses to place a suggestion without a proven prompt-row screen anchor.

The prompt-row placement blocker is now past the first live gate. The Ghostty
proof policy recovers title/header-scoped prompt anchors, falls back to a
title-scoped direct prompt anchor when stale screen marker text would otherwise
veto a clean current prompt, and the app handoff creates the same fail-closed
direct anchor after proof input repair. The direct `claude-code-ghostty` run at
`2026-05-27T23:01:45Z` found the prompt-row suggestion at diagnostics line
`794714`, recorded `claude-code-terminal-host-proof-direct-prompt-anchor-used`,
and emitted a `source=terminal-screen-prompt` synthetic caret. It then failed
closed at the insertion gate: `ghostty-fast-verified-insertion-failed`,
`keyboard-action handled=false reason=insert-failed`. The next red bar is no
longer placement; it is a verified app-owned Ghostty one-word insertion
transport.

The follow-up prompt-row model now includes Ghostty's visible prompt marker in
the terminal-screen anchor instead of estimating from only the typed text. That
moved the proof click from the middle of the prompt row (`x=747` in the bad
sample) to the real end-of-input neighborhood (`x=989` in the latest sample).
The app now also stops the event tap before a proof-only caret click and tries a
front-window native Ghostty `input text` rung that mirrors the smoke harness.
The direct `claude-code-ghostty` run still failed closed: diagnostics line
`797843` recorded `source=ghosttyFrontWindowInputText verified=false`, the
unchanged-prompt baseline stayed true, and line `797884` failed with
`ghostty-fast-verified-insertion-failed`. Ghostty is still unsupported, but the
remaining problem is now sharper: SteadyType can place and accept-route the
prompt-row candidate, while app-owned Ghostty insertion still does not mutate
the disposable Claude prompt.

The latest insertion transport pass tested the shell-shaped native path too.
SteadyType now tries direct and `/bin/zsh -lc exec /usr/bin/osascript` variants
for both the smoke-equivalent front-window `input text` rung and the safer
marker-scanned `input text` rung. The direct `claude-code-ghostty` run found the
prompt-row suggestion at diagnostics line `799244`, then failed closed after
`ghosttyLoginShellFrontWindowInputText` verified `false` at line `799787` and
`ghosttyAppleScriptLoginShellInputText` verified `false` at line `799795`; both
unchanged-prompt baselines stayed true, and line `799831` recorded
`ghostty-fast-verified-insertion-failed`. That rules out one more likely shape
without widening support: Ghostty still needs a different app-owned insertion
transport.

The next live pass tested SteadyType's own in-process native Ghostty `input
text` rung before the subprocess input variants. The direct
`claude-code-ghostty` run found a prompt-row suggestion at diagnostics line
`800174`, posted `ghosttyInProcessInputText` at line `800768`, proved the
unchanged-prompt baseline at line `800769`, and still failed closed at line
`800816` with `keyboard-action handled=false reason=insert-failed`. That rules
out the app-owned in-process AppleScript identity too; Ghostty remains
unsupported until an insertion transport mutates the disposable prompt and
verifies one-word no-submit acceptance.

The next detached Ghostty pass moved the proof boundary forward. The harness now
resolves Ghostty through the title-focused root app PID, trusts that atomic title
focus before slower frontmost polling, and can refocus the host app after Claude
changes the volatile window title. Run `20260528T015512Z-ghostty` reached a real
prompt-row suggestion, proved the visible next-word acceptance text, clicked the
prompt row, and verified the target before insertion. It still failed closed:
every native Ghostty insertion rung reported `verified=false`, and the
shell-launched System Events bulk rung mutated the prompt in an unverified way
before the bundled/CGEvent helper rungs could run. The fast Ghostty ladder now
tries those helper rungs before that risky shell bulk fallback. Follow-up runs
`20260528T020047Z-ghostty` and `20260528T020259Z-ghostty` then exposed the next
harness reliability gap: stale Ghostty proof state can leave the host in a
no-prompt/no-claude state, so Ghostty remains unsupported until cleanup plus a
verified insertion transport both pass in the detached proof.

The latest detached Ghostty pass fixed that cleanup/retry layer without claiming
support. `20260528T021253Z-ghostty` proved fresh-context retry was active but
kept hitting a poisoned zero-window Ghostty host. The harness now uses Ghostty's
own window API for stale proof cleanup, resets only when Ghostty reports exactly
zero windows, keeps proof-process exit diagnostics, and lets Ghostty's
fail-closed insertion ladder finish. The app now tries Command-V pasteboard
insertion before slower native/key-event Ghostty rungs. `20260528T023640Z-ghostty`
and `20260528T024044Z-ghostty` both reached prompt-row Tab insertion and then
failed closed with `keyboard-action handled=false` after unchanged-prompt
baselines. The remaining Ghostty gap is now insertion transport or async
post-Tab verification, not prompt placement, stale host launch, or harness
timeout.

The next proof pass tested the most likely cheap event-shape fix without
turning Ghostty green. SteadyType now paces app-owned Command-V, hardware, and
Unicode-to-pid key events. The session-tap pasteboard Command-V probe is still
available for isolated repros, but it is opt-in after timeout-shaped evidence
showed it should not run by default. `20260528T025919Z-ghostty` found a
prompt-row suggestion at diagnostics line `818560`, posted
`pasteboardCommandVSession` at line `819222`, continued through the full ladder,
and still failed closed at `819271` / `819273`. The default follow-up
`20260528T030442Z-ghostty` found the prompt-row suggestion at diagnostics line
`821100`, consumed Tab at `821919`, skipped the session probe at `821948`,
recorded the unchanged global paste baseline at `821951`, and failed closed at
`821995` / `821997`. That rules out zero-duration Command-V/session-tap paste as
the missing default Ghostty transport while keeping the probe available for
manual repros.

The bounded fail-closed follow-up keeps that proof lane from turning into a
daily-driver latency trap. `20260528T031735Z-ghostty` reached the same prompt-row
Tab acceptance path, proved the accepted next-word prefix at diagnostics line
`823023`, then tried targeted/global pasteboard, in-process native input, direct
front-window input, and shell-launched front-window input. None mutated the
disposable prompt, so line `823052` logged
`ghostty-fast-insertion-budget-exceeded` before the slower native action-text
rung, and lines `823053` / `823055` failed closed. The full exploratory Ghostty
ladder is still available with `AUTOCOMPLETE_LAB_GHOSTTY_EXTENDED_INSERTION_PROBES=1`,
but the default path now preserves trust by stopping quickly when the known bad
transport family keeps producing unchanged baselines.

The next Ghostty transport idea is guarded as an experiment, not default
behavior: `AUTOCOMPLETE_LAB_GHOSTTY_NATIVE_PREFIX_FINAL_KEY_PROBE=1` sends the
accepted prefix through native Ghostty `input text`, then sends the final
character as a real key event. The first detached opt-in run
`20260528T032817Z-ghostty` never reached that rung because two disposable
contexts produced no visible suggestion, so the run was stopped. The next
opt-in run, `20260528T033921Z-ghostty`, did reach the rung after the detached
runner forwarded the probe env into the relaunched app; it logged
`ghosttyNativePrefixFinalKeyText stage=start` at diagnostics line `825139`, then
`verified=false` and an unchanged-prompt baseline at lines `825141` / `825142`.
The code now verifies that native prefix separately before posting the final
key, so the next insertion-reaching proof can tell a prefix no-op from a final
key miss. `20260528T034406Z-ghostty` then failed earlier with no visible
suggestion after one disposable context. `20260528T040957Z-ghostty` and
`20260528T041228Z-ghostty` both reached prompt-row suggestions; the latest run
found the prompt-row suggestion at diagnostics line `832819`, reasserted and
activated Ghostty before posting input at lines `832453` / `832454`, then proved
`ghosttySendKey`, bulk System Events, pasteboard, native-prefix/final-key,
in-process native text, front-window input text, and action-text still left the
prompt unchanged before the budget fail-closed at lines `832488` / `832489` and
the handled-false Tab result at line `832491`. This keeps the next red bar
honest: rerun until the probe reaches insertion, then either graduate it with
verified no-submit proof or remove it.

The newest Ghostty proof pass keeps the unsupported status but removes another
slow ambiguous failure. `20260528T132403Z-ghostty` reached prompt-row suggestion
diagnostics line `927766`, consumed Tab at line `928636`, and recorded a
title-selected native screen copy with `frontWindowProofMatch=true`,
`targetSelection=frontProofTitle`, `windowCount=1`, and
`nativeNoopClassified=true` at lines `928677`-`928678`. The prompt stayed
unchanged through the in-process native input baseline at lines
`928692`-`928694`, so the app failed closed at lines `928695`-`928697` with
`reason=ghostty-initial-insertion-noop-cluster` instead of spending the full
45s exploratory budget. Ghostty still needs a different insertion architecture
or verifier before it can count as supported. The detached proof runner now
defaults command-open off so recurring proof runs start on the
script-owned/no-restore fallback path that has been reaching prompt-row Tab;
direct command-open remains an explicit opt-in probe. The first rerun after that
default flip, `20260528T132935Z-ghostty`, showed direct command-open can still
dirty the prompt on the final launch attempt, so the fresh-context retry now
grants one extra script-owned fallback attempt. The follow-up
`20260528T133331Z-ghostty` used that default path, reached a prompt-row
suggestion at diagnostics line `929688`, handled Tab at line `930715`, and
failed closed at `ghostty-initial-insertion-noop-cluster` on lines
`930759`-`930760` after the known unchanged-prompt insertion baselines. The
extended `20260528T134007Z-ghostty` probe then disabled fail-fast, enabled the
native prefix/final-key probe, walked the later front-window/native/action/paste,
System Events, hardware, and bundled-helper rungs, and still failed closed at
lines `932456`-`932457` with `reason=ghostty-fast-verified-insertion-failed`.
That rules out another cheap reorder of the current Ghostty transport ladder.

The latest Ghostty diagnostic fix made the failure less ambiguous. Ghostty's
native `write_screen_file:copy,plain` action copies a temporary screen dump file
path, so SteadyType now reads that file before matching proof text and records
`screenCopyTransport=screenFile`. The rerun `20260528T160018Z-ghostty` found a
prompt-row suggestion at diagnostics line `945015`, handled Tab, and the native
screen dump at `16:02:53Z` confirmed `containsOriginal=true` and
`containsExpected=false` on the title-marked proof window. Ghostty still fails
closed at insertion, but the verifier now proves the target prompt is correct
and unchanged instead of mistaking the copied file path for terminal content.

The next transport slice ruled out one more app-owned identity. SteadyType now
bundles a proof-scoped Ghostty `input text` mode in
`SteadyTypeTextEventHelper`: accepted text is passed over stdin, the helper
requires the exact Ghostty PID plus proof title markers, and the app verifies
the unchanged prompt before continuing. The current-head opt-in detached rerun
`20260528T162233Z-ghostty` reached a prompt-row suggestion at diagnostics line
`951482`, reasserted the exact Ghostty PID at line `952563`, ran
`bundledGhosttyInputTextHelper` at line `952565`, verified `false`, proved the
original prompt unchanged at line `952566`, then failed closed at
`ghostty-initial-insertion-noop-cluster` on lines `952578`-`952581`. The helper
is kept behind
`AUTOCOMPLETE_LAB_GHOSTTY_BUNDLED_INPUT_TEXT_HELPER_PROBE=1` so the default
fast path does not pay for a proven no-op. Ghostty remains unsupported, but
separate bundled-helper AppleScript identity is no longer an unknown.

The follow-up fail-fast pass moved Ghostty's native paste action into the
initial no-op cluster before generic Command-V and in-process native-input
fallbacks. `20260528T172019Z-ghostty` first proved that ordering on the patched
build; a later clean rerun, `20260528T172507Z-ghostty`, rebuilt the app, reached
a prompt-row suggestion at diagnostics line `960450`, handled Tab, proved
`ghosttyFocusedActionText` left the exact title-marked prompt unchanged at lines
`961342`-`961344`, then ran `ghosttyPerformActionPasteFromClipboard` at lines
`961346`-`961347` before generic pasteboard probes. The native paste action
verified `false`, its unchanged baseline verified `true`, and the prompt stayed
at 42 chars through `ghosttyInProcessInputText` and `ghosttyFrontWindowInputText`
before fail-closing at `ghostty-initial-insertion-noop-cluster` on lines
`961365`-`961367`. The intervening `20260528T172055Z-ghostty` record exited
during startup with a lock/TERM and is not insertion evidence. Ghostty remains
unsupported until the detached proof exits `0` with verified one-word no-submit
insertion.

The Obsidian daily-driver lane got one current proof refresh too, but with a
useful caveat. `AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh
obsidian --manual-gate` passed on 2026-05-28T13:48:08Z at commit
`707b7c95c614` with 2 accepted insertions, strict visual trace evidence,
diagnostics lines `932538`-`932695`, and trace lines `30739`-`30761`. The first
attempt exposed only Obsidian window chrome through macOS Accessibility; the
proof harness now starts fresh disposable Obsidian proof launches with
`--force-renderer-accessibility` so CodeMirror editor content is visible to the
same AX path SteadyType relies on. This keeps the proof lane moving, but normal
Obsidian daily-driver support should stay caveated until default-launch
renderer accessibility is proven or guided.

TextEdit proof freshness moved forward on the same pass. The first rerun
exposed a proof-harness seed bug where TextEdit's native completion expanded
`Smoke proof feels inst` to `Smoke proof feels instant` before the proof app was
allowed to own the suggestion. The harness now uses the timeout-bounded
selected-text replacement helper instead of a shadowed AX value writer and trims
native completion suffixes during seed normalization. The retry passed on
2026-05-28T13:59:30Z at commit `f81c34d22c2e` with diagnostics lines
`933094`-`933189`, trace lines `30815`-`30837`, 2 accepted insertions, and
strict visual trace evidence.

The visible-word stability fix closed the Obsidian long-note trust break. The
first failing run accepted `calm` after the slower model changed the visible
fallback away from `instant`; the replacement policy now suppresses refinements
that change the first visible word, while still allowing same-first-word
extensions. A current long-note rerun passed on 2026-05-28T14:11:56Z at commit
`26eadc370ba2` with diagnostics lines `933827`-`933959`, trace lines
`30954`-`30973`, 2 accepted insertions, and strict visual trace evidence.
The strict beta-safe proof grid is current again after the latest harness
hardening. `./script/manual_smoke_status.sh --strict` passed on 2026-05-28 at
commit `1969992ddcf5`: TextEdit, Notes title/body/checklist, Obsidian
default/theme/pane/long-note, Chrome textarea, and Chrome contenteditable all
have current or source-compatible rows with 2 accepted insertions and strict
visual trace evidence.
This refresh also fixed two proof-trust issues: TextEdit undo proof now
reasserts the disposable window and runs before screenshot waiting can expire
rollback, and Chrome fixture accepts no longer re-click the editor after a
suggestion appears, which preserves the caret at the accepted phrase.

## Scorecard

Current proof freshness: TextEdit default, Notes title/body/checklist, Chrome
textarea/contenteditable, and Obsidian default/theme/pane/long-note all have
current strict visual proof with two verified accepts.

| Area | Current Read | Daily-Driver Bar | Next Proof |
| --- | --- | --- | --- |
| Suggestion magic | Better defaults plus retry repairs for bad 8-word phrase passes; the user-facing default now shows up to 8 words and model guidance treats that as a 3-8 word daily-driver phrase, not a one-word completion with a bigger cap; old 3-word and 5-word stored defaults migrate forward to the new short-phrase length; disposable local audit is green at 45/45; instant phrase fallback now covers more audit-aligned 3-6 word daily-driver contexts, including punctuation, list-shaped writing, complaint language, finish-my-thought sentence shapes, first-person trust/feeling shapes like feels wrong/falls short/use this every day/reaching for it, reusable writing-intent endings, guarded connector-thought phrases like because/so-that/which-means/the-fix-is, and Obsidian-style markdown labels like Next/TODO/Open questions/Decisions/Focus/Today/Waiting on/Blocked/Risks/Done/Idea/Note to self; Obsidian daily-driver triggers now ask after short list/checklist labels such as `- TODO:` and `- [ ] Next:` instead of waiting for generic list-word completion; very-proactive writing profiles now queue next-sentence phrase continuations after sentence boundaries while prompt surfaces stay quiet there; the same instant path now respects accepted-and-kept restraint before showing again after repeated local rejects; dogfood reports now fail timid phrase suggestions under 3 visible words | 3-8 words often feel like the user's next thought | Dogfood writing session with raw opt-in quality notes |
| Placement reliability | Current strict proof passes after the latest source changes: TextEdit, Notes title/body/checklist, Obsidian default/theme/pane/long-note, Chrome textarea, and Chrome contenteditable all have strict visual trace evidence and two verified accepts. Ghostty detached proof now refuses untrusted top/header synthetic carets, preserves refreshed terminal-screen prompt anchors across proof input repair, bypasses terminal-proof-only final latency suppression, preserves valid in-flight proof requests through focused-text polling throttle, reaches prompt-row suggestion detection through a title-scoped direct prompt anchor when screen-marker text is stale, models the visible Ghostty prompt marker before caret estimation, survives volatile Ghostty window-title focus by trusting a title-focused root PID before host-app refocus, cleans stale proof windows with Ghostty-native APIs, retries fresh context launch failures, keeps failed launch wrappers diagnosable, tries pasteboard before slower insertion rungs, paces synthetic key events, activates Ghostty after title-scoped terminal focus before posting input, keeps the session-tap paste probe opt-in after timeout-shaped evidence, forwards opt-in Ghostty probe env into detached app launches, separately verifies the native-prefix/final-key probe prefix before posting the final key, and now stops the default failing insertion ladder at an explicit budget while keeping the long probes opt-in; `20260528T023102Z-ghostty`, `20260528T023640Z-ghostty`, `20260528T024044Z-ghostty`, `20260528T025919Z-ghostty`, `20260528T030442Z-ghostty`, and `20260528T031735Z-ghostty` reached prompt-row suggestion and Tab acceptance proof, `20260528T033921Z-ghostty` reached the opt-in native prefix/final-key rung and proved the prompt stayed unchanged, `20260528T034406Z-ghostty` failed earlier with no visible suggestion, and `20260528T041228Z-ghostty` reached prompt-row suggestion again but proved the activated ladder still left the prompt unchanged and failed closed on budget, so Ghostty remains unsupported | Correct or honest fallback in normal writing apps | Run a real writing dogfood session, then keep prompt/chat/terminal/production-browser support blocked until exact current proof exists |
| Typing speed | Subsecond repaired phrase results can display; MLX word completion has a tested local suffix rescue; TextEdit, Codex, Claude desktop, and terminal-hosted Claude Code now have current model-backed no-submit latency proof; cold TextEdit phrase continuation now has current default-model proof with 13 shown phrase samples and p95 shown latency 619ms; the fresh Claude Code Terminal run showed 10 model-backed visible samples with prompt-submit safety counters at 0; fast typing bursts now leave word completion and instant phrase fallback available while pausing heavier model continuations; dogfood reports and status preflight now require at least one instant phrase fallback with <=1ms recorded latency, expose instant phrase vs model-backed source mix, and include a live redacted typing-feel score | Feels ready during fast typing | Real writing-session report while typing fast |
| Wrong-field safety | Prompt no-submit and sensitive-field proof self-tests now run in default smoke; dogfood reports now also fail on trust-killer trace signals in the session | Zero sensitive/wrong-field suggestions | Fresh live prompt no-submit and sensitive-field trace slice |
| Daily-driver feel | Core proof grid is green on the current build and the dogfood report wrapper now requires a real-sized trace sample, at least one real 3+ word phrase suggestion, at least one <=1ms instant phrase fallback, redacted typing-feel score, accepted-kept / shown reach gate, source-mix visibility, no-show reason visibility, trust-killer gate, prompt/sensitive safety snapshot, completed manual-review gate with app/filter match, active-minute match, suggestion quality 4-5, and no placement-trust negatives, plus start/status preflights that expose whether SteadyType was running before and during the dogfood session; reports now fail if SteadyType was not confirmed running at the start; the status line also explains common no-show outcomes, including learned instant restraint, instead of leaving stale queued text, but it still needs a human writing session | User leaves it on and misses it when off | One full writing session with SteadyType enabled, fill the trust row, then run `review --report` |

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
