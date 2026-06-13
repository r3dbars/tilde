# Daily Driver Phrase Mode Saga

Archived on 2026-06-12 when the current living spec was shortened.

Use this page as historical implementation and proof context. The current
product stance lives in
[Daily Driver Phrase Mode](../daily-driver-phrase-mode.md).

---

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
It also prints redacted instant phrase match-family counts, so the report can
show whether zero-latency suggestions came from writing bridges, markdown note
labels, reply phrases, sentence-boundary guesses, daily-driver trust language,
or generic priors without exposing the typed text.
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
accepted-kept reach, source mix, instant match families, and no-show reasons
before finishing the report. It now previews the redacted trust-killer gate too,
so insertion
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
The everyday writing bridge is broader now too. Notes, Obsidian, docs prose,
and bullet contexts can produce zero-latency 3-7 word continuations for common
half-thoughts like "the problem is", "what I need is", "I'm trying to figure
out", "I want to be able to", "the right move is", "it would be useful if",
"this should help me", and "the reason this matters is". Email and casual-chat
profiles still stay out of this path so those broader writing guesses do not
turn into reply noise.

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

Terminal-host proof lanes are parked as of June 12, 2026. The work below is
useful evidence, but it is not beta readiness and should not pull energy away
from the core writing-app loop. Terminal, iTerm2, Ghostty, and Claude Code stay
proof-only or blocked unless a future task explicitly reopens terminal-host
research. The current product path is TextEdit, Notes, Obsidian, and other
boring writing fields.

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
status/logs plus preserved proof artifacts under
`dist/claude-code-ghostty-detached-proof/`. Use
`./script/claude_code_ghostty_detached_proof.sh wait` to collect the result; the
wait path also unloads the completed LaunchAgent. The first real launchd run
survived Codex shell cleanup and found the Claude CLI, but it failed before
prompt placement because the frontmost disposable Ghostty PID exposed no AX text
nodes or marker window to the prompt helper. This is still proof infrastructure,
not Ghostty support; support only starts after that detached run proves
prompt-row placement and verified one-word insertion without submitting the
prompt.

The detached runner has a `stop` command and no longer wedges on Ghostty's
native `input text` AppleEvent. It defaults to the LaunchAgent runner again,
with Terminal/nohup kept as explicit fallback launchers, because a live nohup
probe can inherit the caller process group and receive SIGTERM mid-proof. The proof
harness now uses HID CGEvent Unicode text for Ghostty setup typing, records the
diagnostics line immediately before the final trigger character, refuses older
prompt-row suggestions from before that trigger, bounds stale cleanup and
fallback Tab paths, persists each detached run's disposable Claude/Ghostty
artifacts under `proof-artifacts/` so `claude.pid`, `claude.exit`, and
`ghostty-launch.log` survive smoke temp cleanup, rejects low-y/header
suggestions unless the app has emitted
`source=terminal-screen-prompt`, and can bridge same-line prompt-prefix
suggestions after the final trigger. The app side also re-verifies
proof-sensitive Claude Code prompt input after Ghostty AX identity wobble and
preserves one-word key capture for virtual Claude Code proof suggestions across
host-profile churn.

The latest comparator attempt, `20260528T194141Z-ghostty`, proved the durable
artifact path by keeping both disposable `ghostty-launch.log` files after
cleanup. Each reached `configured-window-created`, `script-wrote-pidfile`,
`script-starting-claude`, and `shell-delay-finished`, then still failed before
Tab with `textNodes=0`, `markerWindows=0`, and no marker, so the next Ghostty
lane is prompt AX readiness after shell-started Claude, before another
insertion-ladder change. The patched follow-up `20260528T194828Z-ghostty`
proved the configured-window command-owned launch path is now clean: both
attempts reached `terminal-ready`, recorded an empty working directory only as
diagnostic state, marked the window title, and logged
`configured-window-command-owned-launch` without a duplicate `launch-action-start`.
It still failed before Tab with `textNodes=0`, `titles=0`, `markerWindows=0`,
and `marker=false`, so the next Ghostty lane stays prompt AX discovery after
clean configured-window command launch.

The latest detached launchd runs moved past that AX discovery blocker without
calling Ghostty supported. `20260528T200606Z-ghostty` and
`20260528T201412Z-ghostty` both accepted native Ghostty
`write_screen_file:copy,plain` readiness after the AX helper reported
`textNodes=0`, proved exact typed prompt readiness with the same title-scoped
screen-copy fallback, and verified that native Ghostty input can mutate and
restore the proof prompt before SteadyType insertion. Both runs then found a
prompt-row suggestion, but CGEvent Tab produced no `key=tab` diagnostic, the
System Events fallback also failed to produce an immediate Tab diagnostic, and
the visible suggestion disappeared before the app-owned insertion ladder could
run. The third run received SIGTERM during the second native pre-accept probe,
so the harness now records the active Claude Code prompt/Tab/insertion phase on
SIGTERM. The next red bar is no longer configured-window launch or AX prompt
discovery; it is an accept driver that SteadyType can observe in Ghostty without
losing the visible prompt-row suggestion.

Post-commit proof `20260528T202618Z-ghostty` tightened that red bar. With
`AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_MAX_ATTEMPTS=1`, the detached launchd
run exited cleanly with status `1` instead of SIGTERM. It again passed
screen-copy prompt readiness, exact typed prompt readiness, and native
pre-accept mutation/restore. It found a prompt-row suggestion, then session
CGEvent Tab, HID CGEvent Tab, and System Events Tab all produced no
`key=tab` diagnostic. The run failed with the precise reason
`Tab delivery did not reach key capture`, so the next experiment should skip
more launch/readiness work and focus on a Ghostty-specific accept path that the
SteadyType event tap can observe.

The next bounded launchd proof, `20260528T203530Z-ghostty`, added a
non-mutating key-capture sentinel before Tab. The run reached the same
prompt-row state, found the current suggestion at diagnostics line `1029172`,
and SteadyType had started key capture at diagnostics line `1029158`. The
session CGEvent Shift probe and the HID CGEvent Shift retry both produced no
`keyboard-event-tap-latency key=other` diagnostic, so the harness failed before
pressing Tab with `key capture probe did not reach event tap`. That moves the
next red bar below Tab itself: the detached Ghostty runner needs a key source
that can reach SteadyType's event tap at all before Tab delivery can be judged.

The follow-up key-source pass keeps that boundary honest. The CGEvent helper now
accepts an explicit source state, so the non-mutating Shift sentinel can try
session HID-state events, HID-tap HID-state events, and session-tap
combined-session events before Tab. The System Events Shift probe remains
available behind
`AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_KEY_CAPTURE_SYSTEM_EVENTS_PROBE=1`, but
the detached proof skips it by default because it can trigger macOS permission
UI and steal focus from the disposable prompt. The detached wrapper also
forwards and reports the key-capture probe knobs. A launcher
comparison run, `20260528T204242Z-ghostty`, used `nohup` instead of launchd and
failed earlier: it reached prompt typing, verified a pre-accept native Ghostty
mutation, but could not restore the original prompt, so it never reached
suggestion/key-capture proof. Ghostty remains unsupported; launchd still reaches
prompt-row suggestions but cannot yet deliver an observable key, while `nohup`
is not a safer default because it can leave the disposable prompt mutated.
Post-patch launchd run `20260528T204741Z-ghostty` did forward the new
key-capture probe env into detached status, but it was SIGTERMed during startup
before build or prompt setup, so it is not key-source support evidence.
Follow-up run `20260528T204810Z-ghostty` reached native screen-copy prompt
readiness again and restored the pre-accept native Ghostty mutation, then showed
the pre-accept System Events comparator did not mutate the prompt before the run
was stopped. That stop exposed a cleanup bug: the wrapper killed the proof
runner but left the proof-owned Ghostty/Claude context alive. The detached
runner stop path now cleans proof context pids from `claude.pid` and the
proof-owned Ghostty pid recorded in `proof.log`, so stopped or wedged proof runs
do not contaminate the next compatibility sample. The follow-up harness patch
also wraps the Ghostty pre-accept comparator's quiet prompt-readiness checks in
an outer timeout guard, so a no-op System Events probe cannot wedge the detached
run while it is checking whether the prompt stayed unchanged.
The next launchd pass, `20260528T210138Z-ghostty`, stayed bounded and sharpened
the red bar: native Ghostty text could mutate and restore the proof prompt,
System Events still could not, a prompt-row suggestion appeared, and every
non-mutating key-capture sentinel missed SteadyType's event tap. Diagnostics
also showed macOS Accessibility/System Settings taking focus during that key
probe window. The harness now classifies that permission-UI focus steal
explicitly when it happens, with a short post-probe flush wait added after
`20260528T210954Z-ghostty` showed the System Settings focus-change line can land
just after the generic key-capture miss is printed. `20260528T211636Z-ghostty`
confirmed the same bounded path and late focus-change timing, so the final
post-suggestion failure aggregator now also waits briefly and rewrites the final
reason when permission UI is the real focus thief.
The next default proof pass kept that lane permission-safe:
`20260528T213048Z-ghostty` reached a prompt-row suggestion, tried session HID,
HID-tap, and combined-session CGEvent Shift probes, skipped System Events Shift
with `AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_KEY_CAPTURE_SYSTEM_EVENTS_PROBE=0`,
and failed cleanly with `key capture probe did not reach event tap`.
The next harness slice adds a PID-targeted CGEvent Shift probe against the exact
frontmost title-marked Ghostty proof process before the System Events opt-in
path, giving Ghostty one more permission-safe key source to prove or rule out.
Live run `20260528T214421Z-ghostty` ruled it out twice: attempts 1 and 2 reached
prompt-row suggestions, targeted Ghostty pids `57277` and `91391`, missed the
event tap, and skipped System Events with
`AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_KEY_CAPTURE_SYSTEM_EVENTS_PROBE=0`. The
run was stopped after it continued into extra disposable contexts, and the
detached wrapper now defaults `AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_MAX_ATTEMPTS=1`
so future key-source proofs stay bounded unless explicitly overridden.
The next app-side diagnostic slice adds `eventSourcePID` and `eventTargetPID`
to `keyboard-event-tap-latency` rows when macOS exposes those fields. That does
not change Ghostty support status because the current synthetic Ghostty key
sources still miss the event tap, but it gives the next successful key-capture
sample enough process context to separate helper-origin, target-process, and
real-user key paths without recording typed text.
The follow-up harness slice now tries private-state CGEvent Shift and Tab rungs
after the session/HID/combined/PID attempts and before the System Events opt-in
path. That keeps the default run permission-safe while ruling out one more
synthetic key source for Ghostty before asking for a real permission-risk
System Events experiment.
Live run `20260528T221035Z-ghostty` did not reach that new key-source ladder.
It passed native screen-copy prompt readiness, exact typed-prompt readiness, and
native pre-accept mutation/restore, then received SIGTERM while waiting for the
attempt-1 suggestion. Cleanup stopped the proof Ghostty process and proof
command process. The detached wrapper now prints periodic wait progress, and
the key-capture refocus path has a timeout knob so the next long run exposes its
phase instead of looking idle.
The optional nohup launcher is also less entangled with Codex now: it starts the
runner in a new session through Python's `start_new_session=True`, so nohup
comparison runs should not inherit the app-server process group. That is not
Ghostty support, but it makes future nohup-vs-launchd red evidence cleaner.
The native pre-accept mutability probe now restores the entire proof prompt via
Ghostty-native clear-and-input rather than a single System Events backspace,
which keeps native mutation evidence from becoming a cleanup failure before the
suggestion/key-capture step.
Fresh Ghostty proof contexts also skip the initial prompt clear by default now.
Typed-prompt readiness still rejects dirty prompt state, but the harness avoids
one more focus-sensitive key path before typing the real proof text.
Typed Ghostty prompt readiness now allows the native screen-copy fallback after
an AX miss when an exact typed proof prompt is expected. That makes the fallback
useful beyond `textNodes=0` failures without relaxing the dirty-prompt guard.
The detached Ghostty proof runner also launches `real_app_smoke.sh` as the
direct child process instead of wrapping it in an extra job-control child shell.
`20260528T222807Z-ghostty` still used the old wrapper and reached typed-prompt
readiness before TERM after native, bulk System Events, and paced System Events
prompt typing were incomplete. `20260528T223417Z-ghostty` used the direct-child
path and removed the smoke-child-shell ambiguity; the real smoke process now
receives SIGTERM during `claude-code Ghostty open fresh disposable context`,
after the stale-only host check and before prompt readiness. That keeps Ghostty
unsupported, but it gives the next iteration a much narrower failure to chase:
the disposable open lifecycle or the external TERM source.
The TERM diagnostic path now reports smoke self/parent/process-group/session
ids, guard pids, tracked proof pids, lock owner, process-group members, and
nearby proof-related processes before cleanup. The next failed Ghostty run
should identify whether TERM is coming from proof cleanup, wrapper/session
teardown, or an outside watcher.
`20260528T223728Z-ghostty` got past fresh launch and native screen-copy prompt
readiness, then failed native and bulk System Events proof typing before TERM
during paced System Events typing. The overlapping `20260528T223936Z-ghostty`
startup failure proved the new signal diagnostics can name the smoke lock owner,
and it exposed that `start --force` only considered the latest run. The wrapper
now stops every active detached Ghostty proof under the proof root before
starting a forced replacement.
`20260528T224532Z-ghostty` proved that guard by stopping
`20260528T224425Z-ghostty` first, then starting a clean nohup run. It still
failed during `build/relaunch current SteadyType`, and the new signal snapshot
showed a separate Codex-owned `claude_code_ghostty_detached_proof.sh stop`
process targeting that same run directory. Treat that run as external stop
interference rather than a Ghostty support verdict.
The detached wrapper now refuses plain `stop --run-dir` during the early
evidence window unless `--force-stop` is passed, so automatic cleanup has a
harder time invalidating the next build/prompt sample.

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
during startup with a lock/TERM, and the later no-defer/extended follow-ups
`20260528T172842Z-ghostty` and `20260528T172932Z-ghostty` also terminated during
startup before prompt-row insertion. Those `143` records are not insertion
evidence. Ghostty remains unsupported until the detached proof exits `0` with
verified one-word no-submit insertion.

The next Ghostty instrumentation pass preserves Ghostty's AppleScript
`perform action` boolean instead of forcing native actions to look posted.
`20260528T173408Z-ghostty` still reached a prompt-row suggestion at diagnostics
line `962043`, handled Tab, proved the native prefix/final-key probe did not
mutate the prompt at lines `962959`-`962962`, and failed closed at lines
`962970`-`962972`. The immediate rerun `20260528T174209Z-ghostty` then confirmed
the new metadata: prompt-row suggestion line `963531`, `actionPerformed=true`
on focused native action text at lines `964428`-`964430`, native paste at lines
`964432`-`964433`, front-window input plus native screen-copy no-op at lines
`964449`-`964451`, and fail-closed insert lines `964452`-`964454`. Ghostty is
now a better-instrumented no-op, not supported; it still needs a detached proof
that exits `0` with verified one-word no-submit insertion.

The next no-op trust pass made the default Ghostty fail-fast stricter: focused
native action, native paste action, and front-window native input must now carry
Ghostty-native screen-copy no-op classification before the initial cluster can
fail closed. `20260528T175216Z-ghostty` reached prompt-row suggestion line
`965236`, retried Tab through System Events after CGEvent Tab produced no key
diagnostic, then recorded `nativeNoopClassified=true` for focused native action
at lines `966289`-`966291`, paste action screen-copy at lines
`966293`-`966295`, and front-window input screen-copy at lines
`966311`-`966313`. The stricter gate failed closed at lines `966314`-`966316`,
and the proof log's post-fail external native insertion probe still did not
verify prompt mutation. Ghostty remains unsupported, but the no-op classification
is now based on multiple Ghostty-native screen reads instead of one AX baseline.

The post-fail comparator now checks both external native Ghostty input and
external System Events typing after app-owned insertion has failed closed. The
fresh rerun `20260528T180004Z-ghostty` reached prompt-row suggestion line
`967039`, then repeated the stricter native no-op proof: focused action at lines
`967919`-`967921`, paste action plus screen-copy at lines `967923`-`967925`,
front-window input plus screen-copy at lines `967941`-`967943`, and fail-closed
insert at lines `967944`-`967946`. The proof log then typed one native suffix and
one System Events suffix without Enter; neither verified prompt mutation. That
means the current failed context is not merely an app-owned transport mismatch;
after SteadyType fails closed, the harness can no longer prove external Ghostty
input mutates that same disposable prompt either.

The follow-up comparator removed the last obvious focus excuse from that result
and proved the before/after split. `20260528T181801Z-ghostty` first typed one
external native Ghostty suffix and one external System Events suffix before Tab;
both mutated the prompt and restored the original text. The same run then found
a prompt-row suggestion at diagnostics line `975159`, failed closed after Tab,
typed one external native suffix without Enter, clicked the latest
terminal-screen prompt caret at `x=633 y=723`, and typed one external System
Events suffix without Enter. Neither post-fail external path verified prompt
mutation after the prompt-row refocus. Ghostty remains unsupported; the next
useful slice is a different insertion architecture or a pre-fail path that
avoids this no-op state entirely.

The next Ghostty transport pass tested the closest app-owned version of the
working external System Events shape before the exact-PID focused rung.
The detached proof lane now opts into a frontmost-bundle raw System Events
keystroke before the focused rung, then verifies the unchanged baseline before
continuing. `20260528T183440Z-ghostty` made two fresh attempts: the first found
a prompt-row suggestion at diagnostics line `984282` but lost the visible
suggestion during Tab injection, while the second consumed Tab at line `989460`,
clicked the prompt-row caret at line `989486`, then posted
`ghosttyBundleSystemEventsRawKeystroke` at line `989490`.
The new rung exited cleanly but verified `false`; its unchanged-prompt baseline
verified `true` at line `989491`. Focused System Events and send-key then
repeated the same unchanged result at lines `989493`-`989497`, the ladder failed
closed at lines `989529`-`989532`, and the post-fail external native/System
Events probes again could not mutate the prompt after caret refocus. Ghostty
remains unsupported; raw bundle System Events is now ruled out as a proof-lane
default insertion fix.

The follow-up pre-focus comparator ruled out the prompt-click theory too.
`20260528T185553Z-ghostty` enabled
`AUTOCOMPLETE_LAB_GHOSTTY_PRE_PROMPT_FOCUS_RAW_SYSTEM_EVENTS_INSERTION_PROBE=1`
and reached the deferred Tab-accept path on attempt 2. Before any prompt-row
click, SteadyType reasserted the Ghostty proof pid, stopped the keyboard tap for
`ghostty-pre-prompt-focus-bundle-system-events-raw-insertion`, then posted
`ghosttyPrePromptFocusBundleSystemEventsRawKeystroke` at diagnostics line
`999928`. It exited `0` but verified `false`; the original-prompt baseline
verified `true` at line `999929`. The later prompt-click, raw bundle System
Events, focused System Events, send-key, pasteboard, and native Ghostty paths all
kept the same unchanged prompt and the proof failed closed at lines
`999973`-`999976`. Ghostty remains unsupported; the next transport idea needs to
avoid the app-owned post-accept event/input-text no-op state rather than merely
changing focus timing.

The latest Ghostty proof slice removes the stale-event-tap ambiguity from that
result. A non-deferred run, `20260528T185115Z-ghostty`, reached prompt-row Tab
accept with `AUTOCOMPLETE_LAB_GHOSTTY_DEFERRED_INSERTION_PROBE=0` and still
failed the same unchanged-prompt ladder, so the 120ms deferred accept delay is
not the cause. The clean follow-up, `20260528T191017Z-ghostty`, rebuilt the app
with the corrected pre-prompt raw System Events probe and reached prompt-row
suggestion diagnostics line `1002533`. Tab was consumed at `19:14:13Z`, deferred
insert started at `19:14:14Z`, and
`ghosttyPrePromptFocusBundleSystemEventsRawKeystroke` posted at `19:14:16Z`
with `keyboardTapStopped=false`; it still verified `false` while the
original-prompt baseline verified `true`. The normal focus-click and raw/focused
System Events/send-key rungs then repeated the unchanged result before
`ghosttyInitialNoopClusterBaseline verified=true` and fail-closed insert at
`19:14:43Z`. Ghostty remains unsupported; the current ladder is now ruled out
on timing, prompt click, and event-tap stop shape.

The next proof hook is now narrower than another insertion-ladder reorder.
`AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_POST_TAB_PRE_INSERT_EXTERNAL_MUTATION_PROBE=1`
lets the Ghostty smoke wait for SteadyType to schedule deferred insertion after
Tab, then try one external native/System Events character and restore the
original prompt before the delayed app-owned insert fires. The matching app-side
delay clamp now allows an explicitly configured 3s proof window. That should
separate "Tab poisoned the prompt before insertion" from "only SteadyType-owned
insertion transports are no-ops" on the next detached run.

The first launchd comparator attempt, `20260528T193340Z-ghostty`, stayed clean
at the wrapper layer but did not reach that question. Both disposable Ghostty
attempts failed before prompt readiness with `textNodes=0`, `markerWindows=0`,
and no marker. The comparator remains the right next proof, but only after the
no-restore Ghostty launch path reliably reaches a Claude prompt row.

The next Ghostty prompt-readiness pass moved that blocker forward without
turning Ghostty green. The harness now falls back to Ghostty's native
`write_screen_file:copy,plain` screen copy when AX reports `textNodes=0`,
restores the pasteboard, rejects launcher-command scrollback, and requires the
expected prompt text or a title-scoped prompt screen. It also launches Claude in
`--permission-mode plan`, avoids the old unbounded System Events clear path, and
times out optional raw System Events typing probes. `20260528T201412Z-ghostty`
proved screen-copy readiness for both the empty prompt and the typed prompt,
then verified a pre-accept native Ghostty mutation and restore. The run still
lost the visible suggestion during Tab injection: CGEvent Tab produced no
`key=tab` diagnostic, System Events Tab also produced no immediate `key=tab`,
and the run relaunched a fresh disposable context before being stopped after
capturing that evidence. Ghostty remains unsupported; the next red bar is Tab
delivery / visible-suggestion retention under the launchd detached lane, not
prompt AX readiness.

The follow-up key-capture guard keeps that red lane less disruptive. After
session, HID, combined-session, and PID-targeted CGEvent Shift probes miss
SteadyType's event tap, the harness now skips the System Events Shift probe by
default because it can trigger macOS permission UI and steal focus from the
disposable prompt. The System Events key-capture probe is still available behind
`AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_KEY_CAPTURE_SYSTEM_EVENTS_PROBE=1`, but
default Ghostty runs now fail closed and refresh the prompt instead of inviting a
permission dialog into the proof loop.
The detached wrapper now forwards the same key-capture focus-steal wait and
session/HID/fallback Tab timing knobs used by the foreground smoke path, so the
next Ghostty proof run can tune key-delivery windows without patching the
runner. It also defaults detached Ghostty to one disposable context, keeping
current key-source proof runs from spending minutes repeating the same miss.
The latest typed-prompt hardening keeps that lane from regressing into a false
prompt-readiness miss. If Ghostty AX cannot certify the typed prompt, the
harness can now accept SteadyType's privacy-safe terminal prompt-anchor
diagnostic when it appears after the typing trigger and reports the exact proof
text length. A later rerun showed a stale nohup `start --force` can interrupt a
launchd proof, so cross-launcher force-starts now refuse by default unless the
operator explicitly opts in; plain stop also refuses during the early evidence
window unless the operator passes `stop --run-dir ... --force-stop`.
The clean launchd rerun after that guard, `20260528T225106Z-ghostty`, got to the
next honest red bar. It survived past the old external-stop point, accepted
screen-copy and exact typed-prompt readiness, restored a native Ghostty prompt
mutation, and found a prompt-row suggestion at diagnostics line `1068495`.
Then every default-safe key-capture probe missed SteadyType's event tap:
session/HID/combined CGEvent Shift, PID-targeted Shift for Ghostty pid `56810`,
and private-source session/HID Shift. System Events Shift stayed opt-in because
it can trigger the macOS permission UI. Ghostty is still unsupported, but the
next blocker is now clear: find a key source or accept driver the event tap can
actually observe in Ghostty.
The follow-up HID-tap experiment made that red bar sharper without changing the
support claim. SteadyType now records the tap location at startup and can be
launched with `AUTOCOMPLETE_LAB_KEYBOARD_EVENT_TAP_LOCATION=hid` for proof
runs, while normal launches still default to the session tap. Live proof
`20260528T230217Z-ghostty` reached prompt-row suggestion line `1071450` with
the HID proof env active, but the same default-safe key-capture probes missed
the event tap. The next Ghostty attempt should not be another tap-location
shuffle; it should test an actually observable key source or the separate
proof-only accept-command path.

The proof-only accept-command path now separates accept routing from Ghostty
insertion. `20260528T230747Z-ghostty` reached the prompt-row suggestion but
posted the command only after the full key-probe ladder; by then the visible
suggestion was gone, so SteadyType refused it. The patched rerun,
`20260528T231520Z-ghostty`, bypassed the probe ladder when the proof-only driver
is enabled and posted `--proof-only-accept-next-word` immediately. SteadyType
logged `proof-only-accept-command-received` with `hasVisibleSuggestion=true`,
accepted the next-word prefix, scheduled deferred insertion, and logged
`proof-only-accept-command-result ... handled=true` at diagnostics line
`1080242`. The run still failed because the post-Tab/pre-insert native mutation
probe could not restore the prompt and the first app-owned insertion rung timed
out. Ghostty remains unsupported, but the next red bar is now verified app-owned
insertion after a handled accept, not Tab routing.
The wrapper rerun `20260528T232204Z-ghostty` added one harness guardrail: when
the proof-only driver also ran the slow pre-accept System Events comparator, the
suggestion hid before the command arrived and SteadyType refused it. Detached
proof-only runs now default that comparator off unless explicitly opted in.
The latest bounded proof-only run, `20260528T234152Z-ghostty`, proves the
accept side is no longer the blocker: the app showed a prompt-row 5-word
suggestion at diagnostics line `1086203`, received the proof-only accept command
with `hasVisibleSuggestion=true` at line `1087077`, logged
`keyboard-action ... handled=true` at line `1087092`, and scheduled deferred
insertion. The new timeout-bounded Ghostty focus reassertion then failed closed
instead of hanging: lines `1087138`-`1087143` record the 1s focus timeout,
`insert ... success=false`, and `stage=insert-failed`. Ghostty remains
unsupported, but this is a cleaner red bar: app-owned Ghostty insertion cannot
reassert/focus the disposable prompt reliably after a handled accept. The
post-fail external comparator is now skipped by default for proof-only accept
runs unless explicitly opted in, so future proof output should stay focused on
the app-owned insertion failure.
The follow-up run, `20260528T234656Z-ghostty`, found another prompt-row
suggestion but did not reach insertion: the proof-only command arrived after the
visible suggestion had already cleared, and the app refused it with
`hasVisibleSuggestion=false` at diagnostics line `1088565`. That makes the next
Ghostty red bar the proof-only accept timing race, not another insertion result.
The source follow-up keeps that race bounded to the proof-only lane instead of
loosening normal app behavior. SteadyType now caches the latest visible
proof-only Claude Code/Ghostty suggestion and can restore it for an accept
command only when proof-only mode is enabled, the current profile and cached
suggestion both match the virtual Claude Code bundle, the proof field
classification still matches, the text snapshot has not changed, no user keydown
invalidated the suggestion, and the cache age is inside the short recent window.
`swift test --filter ProofOnlyAcceptCommandTests` covers the allow/block cases.
The live rerun, `20260528T235902Z-ghostty`, reached a prompt-row suggestion at
diagnostics line `1089041` and received the proof-only command while the
suggestion was still visible at line `1089860`, so it did not exercise the
restore path. It did prove the current app handled accept and scheduled deferred
insertion at lines `1089860`-`1089876`, then failed waiting for an app-owned
insertion result after the Ghostty insertion transports timed out. Ghostty stays
red; the next red bar is verified insertion/result reporting after a handled
accept, with the recent-suggestion restore path source/test covered but still
needing live race evidence.
The next source pass made that result path fast and observable. Proof-only
detached Ghostty runs now default to an 8s insertion budget and skip the two raw
System Events insertion probes unless explicitly opted in, while the app records
`source-start` before each Ghostty insertion rung. Live run
`20260529T001406Z-ghostty` used those fast values, found a prompt-row suggestion
at diagnostics line `1092299`, handled the proof-only accept at
`1093178`-`1093194`, then tried focused System Events, send-key, bulk System
Events, and focused action text with source-start breadcrumbs at
`1093207`/`1093210`/`1093213`/`1093217`. It hit the 8s budget before
`ghosttyPasteAction`, logged `ghostty-fast-insertion-budget-exceeded` at
`1093220`-`1093221`, emitted `insert ... success=false` at `1093222`, and
recorded deferred `stage=insert-failed` at `1093224`. Ghostty remains red, but
the failure is now a crisp fail-closed insertion budget result instead of a
proof timeout.

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
The helper now also prints a redacted AX snapshot when it cannot resolve the
focused editor: window count, text-entry count, visited-node count, and role
counts only. That turns "could not read editor" into an actionable renderer
accessibility miss without leaking note text.

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
| Suggestion magic | Better defaults plus retry repairs for bad 8-word phrase passes; the user-facing default now shows up to 8 words and model guidance treats that as a 3-8 word daily-driver phrase, not a one-word completion with a bigger cap; old 3-word and 5-word stored defaults migrate forward to the new short-phrase length; disposable local audit is green at 45/45; instant phrase fallback now covers more audit-aligned 3-6 word daily-driver contexts, including punctuation, list-shaped writing, complaint language, finish-my-thought sentence shapes, first-person trust/feeling shapes like feels wrong/falls short/use this every day/reaching for it, reusable writing-intent endings, guarded connector-thought phrases like because/so-that/which-means/the-fix-is, everyday writing bridges like the problem is/what I need is/I'm trying to figure out/the right move is, and Obsidian-style markdown labels like Next/TODO/Open questions/Decisions/Focus/Today/Waiting on/Blocked/Risks/Done/Idea/Note to self plus project-note labels like Summary/Context/Next action/Evidence/Follow-up/Open loops; Obsidian daily-driver triggers now ask after short list/checklist labels such as `- TODO:` and `- [ ] Next:`, plus one-word note labels such as `Context:`, instead of waiting for generic list-word completion; very-proactive writing profiles now queue next-sentence phrase continuations after sentence boundaries while prompt surfaces stay quiet there; the same instant path now respects accepted-and-kept restraint before showing again after repeated local rejects; dogfood reports now fail timid phrase suggestions under 3 visible words | 3-8 words often feel like the user's next thought | Dogfood writing session with raw opt-in quality notes |
| Placement reliability | Current strict proof passes after the latest source changes: TextEdit, Notes title/body/checklist, Obsidian default/theme/pane/long-note, Chrome textarea, and Chrome contenteditable all have strict visual trace evidence and two verified accepts. Ghostty detached proof now refuses untrusted top/header synthetic carets, preserves refreshed terminal-screen prompt anchors across proof input repair, bypasses terminal-proof-only final latency suppression, preserves valid in-flight proof requests through focused-text polling throttle, reaches prompt-row suggestion detection through a title-scoped direct prompt anchor when screen-marker text is stale, models the visible Ghostty prompt marker before caret estimation, survives volatile Ghostty window-title focus by trusting a title-focused root PID before host-app refocus, cleans stale proof windows with Ghostty-native APIs, retries fresh context launch failures, keeps failed launch wrappers diagnosable, tries pasteboard before slower insertion rungs, paces synthetic key events, activates Ghostty after title-scoped terminal focus before posting input, keeps the session-tap paste probe opt-in after timeout-shaped evidence, forwards opt-in Ghostty probe env into detached app launches, separately verifies the native-prefix/final-key probe prefix before posting the final key, and now stops the default failing insertion ladder at an explicit budget while keeping the long probes opt-in; `20260528T023102Z-ghostty`, `20260528T023640Z-ghostty`, `20260528T024044Z-ghostty`, `20260528T025919Z-ghostty`, `20260528T030442Z-ghostty`, and `20260528T031735Z-ghostty` reached prompt-row suggestion and Tab acceptance proof, `20260528T033921Z-ghostty` reached the opt-in native prefix/final-key rung and proved the prompt stayed unchanged, `20260528T034406Z-ghostty` failed earlier with no visible suggestion, `20260528T041228Z-ghostty` reached prompt-row suggestion again but proved the activated ladder still left the prompt unchanged and failed closed on budget, and `20260528T194828Z-ghostty` proved configured-window command launch no longer double-types the launcher before failing earlier at prompt AX discovery, so Ghostty remains unsupported | Correct or honest fallback in normal writing apps | Run a real writing dogfood session, then keep prompt/chat/terminal/production-browser support blocked until exact current proof exists |
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
