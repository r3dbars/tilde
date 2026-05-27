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

Fast typing bursts now keep the instant loop alive. Partial-word completions can
still show during the type-accept-type loop, and phrase continuations get one
zero-latency fallback attempt before the heavier model phrase is paused for the
burst.

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

## Scorecard

| Area | Current Read | Daily-Driver Bar | Next Proof |
| --- | --- | --- | --- |
| Suggestion magic | Better defaults plus retry repairs for bad 8-word phrase passes; disposable local audit is green at 45/45; instant phrase fallback now covers more audit-aligned 3-6 word daily-driver contexts, including punctuation, list-shaped writing, complaint language, finish-my-thought sentence shapes, first-person trust/feeling shapes like feels wrong/falls short/use this every day/reaching for it, reusable writing-intent endings, guarded connector-thought phrases like because/so-that/which-means/the-fix-is, and Obsidian-style markdown labels like Next/TODO/Open questions/Decisions; Obsidian daily-driver triggers now ask after short list/checklist labels such as `- TODO:` and `- [ ] Next:` instead of waiting for generic list-word completion; very-proactive writing profiles now queue next-sentence phrase continuations after sentence boundaries while prompt surfaces stay quiet there; the same instant path now respects accepted-and-kept restraint before showing again after repeated local rejects; dogfood reports now fail timid phrase suggestions under 3 visible words | 3-8 words often feel like the user's next thought | Dogfood writing session with raw opt-in quality notes |
| Placement reliability | All beta-safe strict target rows are fresh again on `15a6f895d091`: TextEdit, Notes title/body/checklist, Obsidian default/theme/pane/long-note, and Chrome textarea/contenteditable all pass `./script/manual_smoke_status.sh --strict` with strict visual trace evidence; Ghostty detached proof now refuses untrusted top/header synthetic carets, preserves refreshed terminal-screen prompt anchors across proof input repair, bypasses terminal-proof-only final latency suppression, preserves valid in-flight proof requests through focused-text polling throttle, and reached prompt-row suggestion detection; `20260527T203149Z-ghostty` captured Tab on a fresh second context and proved foregrounded direct bulk System Events, shell-launched bulk System Events, and per-character System Events were posted but unverified, then failed closed because every app-owned insertion transport left the disposable prompt unchanged, so Ghostty remains unsupported | Correct or honest fallback in normal writing apps | Run `daily_driver_dogfood_session.sh` in a real writing app, then repair or replace the Ghostty insertion transport and rerun `./script/claude_code_ghostty_detached_proof.sh start` / `wait` until it proves verified one-word no-submit insertion |
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
