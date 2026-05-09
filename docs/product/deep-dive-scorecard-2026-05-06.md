# Deep Dive Scorecard - 2026-05-06

This is the live scorecard for the autocomplete lab build after the latest
placement, privacy, selected-text safety, screenshot-tracing, Chrome fixture,
typing-performance, prompt-app safety, AX-health, and native-control pass.
The current pass also adds a Chrome hosted-surface block for Google Docs,
Notion, Slack, and Discord so local browser proof does not imply unproven
production editor or chat support.

Scale: 10 means beta-ready for normal people. 5 means promising but still easy
to break or annoy users.

## Executive Rating

Overall: 9.0/10.

The app is much better than a raw lab prototype now. TextEdit and local Chrome
fixtures can show readable inline ghost text, accept with Tab/full accept, and
verify insertion. The app now blocks password/token-like fields, blocks selected
text replacement, bounds screenshot capture backlog, caps long synthetic-caret
measurement, clips ghost text vertically inside editor bounds, throttles slow
focused-text polling, suppresses stale async suggestions, fails closed when the
keyboard event tap is disabled, scopes recent word memory by app, and removes
fixed sleeps from AX value-replacement insertion. This pass also made instant
word completion obey repeated-miss suppression, removed lab/debug vocabulary
from the global word list, and tightened dogfood prompt detection so loose
words like `table`, `model`, or `test` do not bias normal writing. The latest
wave also added expiring debug capture, green/yellow/diagnostics-only app
support status, a wired serial AX reader for focused-text polling, app-specific
AX cooldowns, stronger assistant-y output filtering, safer Codex/Claude prompt
profiles, calmer menu/status copy, Settings "why hidden" copy,
placement-confidence diagnostics, and screenshot-backed Chrome chat-like
no-submit proof. The latest placement pass also hides stale ghosts when
placement cannot be trusted and feeds repeated caret-geometry uncertainty into
field quiet mode, with the active quiet scope visible in Diagnostics. Slow
focused-text AX reads that return no focused text context now cool down that app
immediately by default, which keeps failing editors from being polled twice
before the app backs away. A single slow AX read with context now also starts a
short focused-text polling throttle and drops that returned context instead of
turning a stale read into a visible suggestion. The latest trust pass also makes
post-accept verification fail closed when the frontmost app, focused text
context, or field identity no longer matches the accepted suggestion baseline;
those cases now trace as `insertionFailed`, count as wrong-insertion annoyance,
and suppress the original field when the profile is configured to quiet failed
insertions.

It is not a 10/10 yet. The biggest remaining gaps are still recorder-grade proof
for the remaining prompt-app and Obsidian variants, especially Claude Code,
Claude desktop, and Obsidian theme, pane, and long-note shapes. The
evidence-backed score should stay lower until those rows are closed.

## Area Ratings

| Area | Rating | Why |
| --- | ---: | --- |
| Normal typing passthrough | 10/10 | Fresh TextEdit endurance proof passed exact 1,200-, 2,400-, 4,800-, and 12,000-character runs with no tap-disable events and zero focused-poll skips. Normal typing correctly keeps keyboard capture idle until a suggestion is visible. Recent text-change polling now backs off during active typing while visible suggestions keep the fast active cadence. The fresh 2026-05-08 10-minute strict run verified exact 12,000-character TextEdit text, event-tap p95 78us, event-tap p99/max 82us, focused-poll p95 max 35ms, focused-poll max 57ms, zero slow markers, zero focused-poll skips, and zero tap disables. |
| Keyboard capture safety | 10/10 | Capture starts only after a suggestion panel frame is actually usable, ordinary typing/IME/dead-key/modifier chords pass through, selected-text replacement is blocked, focus/protected-field/stale accepts replay the original key, unsafe accept failures drop and diagnose the captured key instead of replaying an unsafe accept, repeated Tab is suppressed inside the replay guard window, Esc dismissal inserts zero text, event-tap disabled/start/fail-closed markers are hard key-capture failures, fast typing invalidates suggestions, and Diagnostics separates key-capture failures from AX warning noise. |
| Acceptance reliability | 9.8/10 | TextEdit, core Chrome fixtures, Chrome chat-like, public Chrome text fields, normal-Chrome real Monaco/ProseMirror default-AX rows, Apple Notes title/body/checklist, Codex one-word no-submit, and default Obsidian verify accept paths on current PR #35 proof rows. Prompt-app full accept is intentionally disabled until separate full-accept no-submit proof exists, and a profile-aware safety gate blocks no-submit profiles from full accept, multiword accepted text, non-visible accepted text, and newline/tab/control accepted text before insertion. Selected text is blocked before suggestions/acceptance, AX insertion is faster, full accept has trace-safe exact-visible-text proof, Tab accept is traced as a visible-prefix accept, after-cursor drift fails verification, and missing/changed post-write verification targets are recorded as insertion failures instead of disappearing. Obsidian variants, Claude Code, and Claude desktop remain honest proof gaps. |
| Visual caret alignment | 9.82/10 | TextEdit, core Chrome fixtures, Chrome chat-like, public Chrome text fields, real Monaco/ProseMirror under isolated forced-renderer Chrome and normal Chrome default AX, Apple Notes title/body/checklist, Codex, default Obsidian, Claude Code, and Claude desktop now have screenshot-backed proof. Stale line rects are dropped, vertical clipping is enforced, too-narrow inline space suppresses display instead of showing a sliver, async suggestions refresh current geometry before display, and low-confidence mirror fallback is now suppressed for untrusted yellow profiles instead of showing detached element/window ghosts. Obsidian theme, pane, and long-note variants still need strict rows. |
| Self-healing behavior | 10/10 | The app falls back from inline to mirror, learns compatibility observations, captures screenshots when enabled, records placement evidence, applies only explicit trusted visual offsets, manual nudges move the visible ghost immediately, untrusted placement suppression hides stale ghosts, and trusted visual offsets expire when the target app version, screen, or field shape changes. The latest proof adds explicit applied/refused trust reasons, geometry-only correction proof, and a fresh TextEdit screenshot trace where trusted correction improved measured placement. This proves the scoped self-healing lane, not broad support for every app. |
| Screenshot tracing | 10/10 | Screen Recording is preflighted, capture runs off the hot path, screenshots include editor bounds plus ghost text, traces/logs include capture rect plus rendered panel rect, and capture has a backlog guard plus timeout. Fresh stable-build TextEdit, forced-Chrome, and normal-Chrome default-AX real-editor traces prove screenshot-backed placement without raw text or screenshot-path leakage in the report. |
| TextEdit support | 9.8/10 | Fresh bounded screenshot-backed run at 2026-05-09T06:58:40Z on `361a62f19239` shows ghost text aligned after the caret with two verified accepts and current proof fingerprints. The smoke harness respects the active full-accept shortcut, opens a unique disposable file through a fresh TextEdit instance, targets that exact AX window/title even when old TextEdit windows are restored, seeds only that disposable text area, and dismisses TextEdit's native inline completion before waiting for Autocomplete Lab. |
| Notes support | 9.4/10 | Title, body, and checklist all have current PR #35 bounded strict visual proof with two verified accepts each. Notes now tries verified AX insertion before key fallback, uses a slower read-only verification recheck for Notes AX lag, repairs stale Notes text-after-cursor reads before display/verification, and still fails closed if accepted text is unchanged. The typed-over cooldown was shortened from 5s to 750ms, and cooldown expiry now re-arms the same snapshot so suggestions recover without another keystroke. More list lengths, checked items, and undo variants are still needed. |
| Chrome textarea support | 9.5/10 | Fresh local full-frame screenshot, two verified accepts, and fresh bounded production proof on the public EditPad page with strict screenshot-backed trace evidence. More public domains would make this stronger, but the defined production text-field gate is green. |
| Chrome contenteditable support | 9.5/10 | Fresh local full-frame screenshot, two verified accepts, and fresh bounded production proof on the public MediumEditor page with strict screenshot-backed trace evidence. The verifier now tolerates Chromium rich-editor height reflow without ignoring target movement. More public domains would make this stronger, but the defined production contenteditable gate is green. |
| Chrome editor-like support | 9/10 | Fresh full-frame screenshot and two verified accepts. |
| Chrome Monaco-like support | 9.65/10 | Fresh local Monaco-like proof verifies insertion, `monaco-real` has current isolated renderer-accessibility proof on `361a62f19239`, and `monaco-real-default` now has current normal-Chrome default-AX proof on `834dd2843b6a` with two verified accepts and strict visual evidence. Production editor variants remain open. |
| Chrome ProseMirror-like support | 9.7/10 | Fresh local ProseMirror-like proof verifies insertion, `prosemirror-real` has current isolated renderer-accessibility proof on `361a62f19239`, and `prosemirror-real-default` now has current normal-Chrome default-AX proof on `834dd2843b6a` with two verified accepts and strict visual evidence. Production editor variants remain open. |
| Chrome chat-like no-submit support | 9.5/10 | A local no-submit fixture now has screenshot-backed proof with Tab/full accept verified and submit count still zero. A bounded HTTP browser-chat harness adds one-word Tab proof with submit, send-key collision, prompt mutation, and wrong-context counters held at zero. Browser-hosted ChatGPT, Slack, and Discord are still blocked by surface policy until exact real-service no-submit proof exists, so these harnesses do not imply broad chat enablement. |
| Obsidian support | 9.25/10 | Default Obsidian now has current PR #35 strict visual proof with two verified accepts on `qwen3-0.6b`. The fix proved that the old `afterChars=4` failure was real typed text, then moved Obsidian to exact AX value replacement plus same-pid descendant verification so CodeMirror's stale AX focus/selection does not turn a good insertion into a false failure. The `obsidian-theme`, `obsidian-pane`, and `obsidian-long-note` lanes remain honest proof gaps. |
| Codex support | 9.1/10 | Fresh current PR #35 disposable prompt proof on `361a62f19239` shows visible inline placement, one verified Tab insertion, and prompt no-submit confirmation in the same bounded slice. The helper seeds only disposable `AUTOCOMPLETE_LAB_CODEX_PROOF` text, rechecks the marked composer before accepting, confirms the marker remains after Tab, and never presses Enter. Full accept stays disabled until separate full-accept no-submit proof exists, and more prompt layouts remain open. |
| Claude Code support | 9.5/10 | Direct bundle support is still diagnostics-only because `com.anthropic.claude-code` is a background-only CLI helper on this machine. A proof-only terminal-host adapter maps supported terminal hosts to a virtual Claude Code profile only when proof mode is active, validates the disposable marker/current input line/shell-prompt guard, rejects command-shaped prompt lines, active agent output, stale marked scrollback, and multiline command buffers, carries the virtual bundle ID through suggestion traces, rechecks focus and the acceptance snapshot before insertion, inserts through the terminal host's own Paste menu via AX, and keeps full accept disabled. Host-specific commands now label Terminal, iTerm2, Warp, Ghostty, kitty, Alacritty, and WezTerm proof. Bounded strict visual smoke at 2026-05-08T17:04:17Z proved one verified Tab one-word accept in Terminal-hosted Claude Code without shell or agent submit. iTerm2 and Ghostty are installed but still need host-labeled proof rows; Warp is not installed here. |
| Claude desktop support | 9.2/10 | Bounded strict visual smoke at 2026-05-08T03:49:56Z proves same-baseline screenshot-backed synthetic-caret placement, exactly one verified Tab one-word accept, and no prompt submit signal in Claude desktop. The detector reported `dx=0.2`, `dy=-0.4` for the visible ghost. Full accept stays disabled until separate full-accept no-submit proof exists, and more prompt layouts still need coverage. |
| Output relevance | 9.2/10 | Prompt labels, instruction echoes, assistant filler, unsafe prompt actions, punctuation suffixes, parroting, recommendation/rewrite/next-action starters, visible typed-word duplicates, phrase restarts, and more assistant-y advice/planning prefixes like "what I would do", "one option is", and "the next step would" are suppressed before display. Sentence-mode streaming now waits for a fuller three-word partial and only shows one partial before the final result, accepted-kept display thresholds are stricter for prompt/chat and sentence-like prose profiles after enough local samples, and quiet/normal/eager control tunes cadence plus display thresholds. Dogfood prompts avoid loose substring triggers, but default redacted tracing means deeper output-quality audits require explicit raw-content dogfood runs. |
| Word completion quality | 9.6/10 | Word completion and partial acceptance are useful, bounded, app-scoped, activation and fast ranking both require 3+ typed letters, fast completions obey repeated-miss suppression, and unrelated whole-word completions are rejected. `docs/evals/word-completion-quality-2026-05-09.md` now shows deterministic app-surface evidence across TextEdit, Notes, Obsidian, and Chrome-like fields: 100% candidate quality, 9% miss rate, 9% typed-over rate, 1/1 repeated-miss suppression, 1/1 prefix-family cooldown, and 4/4 partial accept success. It still needs larger live dogfood volume before this can honestly score 10/10. |
| Non-annoyance | 9.35/10 | Esc, typed-over tracking, repetition suppression, a 3+ typed-letter floor for word completion, sentence-streaming partial restraint, quiet/normal/eager control, profile-aware accepted-kept display restraint, visible placement-uncertainty quiet mode, pause control, insertion recovery, app-specific AX cooldowns, single slow-AX-read throttle, explicit copy-only fallback status for unsafe inline cases, Settings "why hidden" copy, and untrusted low-confidence mirror suppression help. Ordinary typed-over cooldown is now 750ms instead of 5s, and when that cooldown expires the app re-arms the unchanged snapshot so a suggestion can come back without waiting for another keystroke. Visual misses still make the app feel annoying where real-app placement proof is missing. |
| Privacy | 10/10 | Local-first, secure fields suppressed, password/token/API-key-like fingerprints blocked before text reads, diagnostics redact text by default, screenshots are opt-in, recent word memory is app-scoped, clipboard fallback requires explicit per-profile opt-in in addition to the runtime flag, raw/global/per-app screenshot debug capture expires from app UI, Settings shows share-safe privacy status, Diagnostics exports a redacted privacy bundle with a manifest/checklist, and the beta packet explicitly forbids raw traces, screenshots, prompts, typed text, and accepted text by default. |
| Onboarding | 10/10 | Settings explains runtime readiness, current app state, local privacy controls, and Accessibility setup in one short paragraph. Screen Recording copy appears only when screenshot capture is enabled, fresh installs start with suggestion-capable apps off, first success points to enabling TextEdit, missing/invalid local model assets can now install or repair in-app with plain no-model-server recovery copy, progress, cancel, retry, validation, and runtime warm, and the Apps section now shows exact disposable-text proof steps plus the matching smoke command with one-click copy while blocking proof start until the current app is enabled. TextEdit and Chrome now have one-click in-app proof runners; the Chrome runner includes the default-AX real-editor add-on, automatic proof plans are unit-tested, Settings action dispatch is unit-tested, and the latest TextEdit skip-build proof passed against a proof-mode app with strict visual trace evidence. |
| User control | 10/10 | Pause, current-field/session silence, current-app enablement, visible per-app render mode, force-mirror override, quiet/normal/eager aggressiveness, app-proof starter, green/yellow/diagnostics-only/unsupported support status, privacy controls, temporary screenshot/raw trace toggles, local log deletion, direct accept-all shortcut editing, full-accept shortcut state, and Settings "why hidden" copy are now first-class enough for this scorecard. |
| Diagnostics | 10/10 | Placement, event-tap latency, focused poll latency, AX cooldowns, insertion, trace, screenshot-file evidence, active quiet mode, and smoke logs are strong. The Diagnostics window now separates key capture health from AX polling health, treats event-tap start failures and failed-closed events as key-capture attention instead of AX noise, and exposes placement confidence, anchor source, render fallback, self-healing action, clipping state, screenshot state, caret failure rates, and trace-safe prompt-context shape without suggestion text or raw title text. |
| Automated tests | 10/10 | `swift test` passes the current suite, including app-target settings state tests, app-proof command runner, coordinator, and proof-mode cleanup tests, Settings proof action dispatch, command fallback policy tests, suggestion aggressiveness tests, suggestion orchestrator request/ticket delegation, orchestrator rich request construction, orchestrator session-cache metadata, orchestrator app-model candidate metadata, orchestrator display-score, sentence-streaming restraint, streaming, replacement, prefix-cooldown, placement, and placement-fallback decisions, orchestrator failure visibility gating, orchestrator field-delivery race gating, orchestrator engine replacement after runtime reload, current-field silence copy, per-app mirror override copy, direct shortcut editing copy, onboarding copy tests, diagnostics typing-health key-capture failure tests, prompt-context diagnostics tests, placement diagnostics tests, typed-through suggestion progress, word-completion suffix survival, 3-letter word-completion floor, profile-aware fresh-paragraph trigger suppression, accepted-kept utility adjustment, profile-aware accepted-kept display thresholds, duplicate/restart quality guards, static prompt cache metadata, trace-safe document/window title shape, prefix-family HMAC trace metadata, deterministic stable-bounds field identity, Claude Code terminal-host proof profile and scrollback input-line extraction, browser hosted-surface blocks, Chrome automatic proof-plan coverage, acceptance visible-text proof, runtime session-cache policy and trace metadata, Notes text-context repair, scoped recent-word memory, privacy expiry, support status, serial AX reader, focused AX-health cooldown, missing-context AX cooldown, single slow-AX-read throttle, active-typing focused-poll cadence, focused-poll backoff, dogfood false-positive coverage, neutral word-completion vocabulary, directive-output suppression, fast-word candidate metadata, screenshot trace capture policy, pixel offset detector policy, synthetic caret centering, proof-gated Chrome synthetic-caret trust, profile-aware placement trust policy, replay proof, smoke-slice replay proof, and trace visual evidence. Script self-tests now cover strict score targets, the 10-pass score loop path, manual smoke status, visual proof, replay slicing, replay profiles, key-capture failure classification, typing performance, and the 10-minute endurance soak command. |
| Real-app smoke | 9.9/10 | TextEdit, Apple Notes title/body/checklist, core Chrome fixtures, public Chrome textarea/contenteditable, real Chrome Monaco/ProseMirror under isolated renderer-accessibility mode and normal Chrome default AX, Chrome chat-like no-submit, Codex one-word no-submit, and default Obsidian are green on current PR #35 proof rows. Obsidian variants, Claude Code, and Claude desktop layout lanes remain honest proof gaps. |
| Release readiness | 8/10 | Packaging is in decent shape, but beta readiness still correctly fails unless all required manual and screenshot-backed proof rows are closed. Notarization/stapling and beta onboarding still need a final product pass. |
| Architecture | 10/10 | Core policy, geometry, scoped word memory, trace analysis, privacy expiry, support status, serial AX focused-text reads, AX-health cooldowns, app-proof command coordination, and suggestion request/ticket/request-construction/candidate-metadata/display-score/streaming/replacement/prefix-cooldown/placement/placement-fallback/field-delivery/failure-visibility orchestration are tested and wired. Final panel delivery and presentation trace payload creation now live in `SuggestionPresentationDelivery`, while host/version/safety/proof state lives in `HostCompatibilityPolicyCatalog` and is mirrored by the proof manifest. AppDelegate still wires app lifetime and OS services, but it no longer owns those proof-sensitive policy tables or final presentation delivery details. |

## Visual Placement And Text Box Audit

| App or surface | Grade | Evidence | What is good | What still needs work |
| --- | ---: | --- | --- | --- |
| TextEdit | 9.5/10 | [textedit-inline.png](visual-placement-screenshots/textedit-inline.png) | Ghost is on the same line, after the caret, readable, and not focus-stealing. | Pending: more dark/light document variants. |
| Chrome textarea | 9.5/10 | [chrome-textarea.png](visual-placement-screenshots/chrome-textarea.png) | Inline ghost is readable and follows the typed text; untrusted low-confidence mirror fallback is now suppressed instead of showing detached yellow-profile placement. The public EditPad proof now has strict screenshot-backed trace evidence. | Pending: broaden to more public textarea domains. |
| Chrome contenteditable | 9.5/10 | [chrome-contenteditable.png](visual-placement-screenshots/chrome-contenteditable.png) | Ghost starts immediately after the caret with enough contrast, and the public MediumEditor proof now has strict screenshot-backed trace evidence. | Pending: broaden to more public contenteditable/rich-editor domains. |
| Chrome editor-like | 9/10 | [chrome-editor-like.png](visual-placement-screenshots/chrome-editor-like.png) | CodeMirror-style fixture aligns well after the caret. | Pending: Obsidian now covers real CodeMirror; still needs more production editor variants. |
| Chrome Monaco-like | 9.7/10 | [chrome-monaco-like.png](visual-placement-screenshots/chrome-monaco-like.png), [chrome-monaco-real.png](visual-placement-screenshots/chrome-monaco-real.png) | Local Monaco-like proof is readable near the caret, and real Monaco has current strict screenshot evidence in isolated forced-renderer Chrome plus normal Chrome default AX. | Pending: broader production editor variants. |
| Chrome ProseMirror-like | 9.75/10 | [chrome-prosemirror-like.png](visual-placement-screenshots/chrome-prosemirror-like.png), [chrome-prosemirror-real.png](visual-placement-screenshots/chrome-prosemirror-real.png) | Local ProseMirror-like proof is inline, and real ProseMirror has current strict screenshot evidence in isolated forced-renderer Chrome plus normal Chrome default AX. | Pending: broader production editor variants. |
| Chrome chat-like no-submit | 9.5/10 | [chrome-chat-like.png](visual-placement-screenshots/chrome-chat-like.png) | Ghost is inline after the caret, Tab and full accept verified, and the local submit counter stayed at zero. Bounded HTTP browser-chat harness proof adds one-word/no-submit counter coverage for a disposable browser composer. | Pending: exact ChatGPT, Slack, and Discord no-submit proof before broad enablement. |
| Obsidian | 9.25/10 | [obsidian.png](visual-placement-screenshots/obsidian.png) | Default Obsidian has a fresh strict visual row with two verified accepts. Direct AX value replacement plus descendant verification handles CodeMirror stale cursor/focus churn without changing models. | Pending: run `obsidian-theme`, `obsidian-pane`, and `obsidian-long-note` with strict screenshot-backed trace rows. |
| Codex | 8.5/10 | [codex-inline.png](visual-placement-screenshots/codex-inline.png) | Disposable prompt screenshot shows the ghost visible on the same line after the caret on a negative-origin side display, but the profile stays diagnostics-only until no-submit evidence is captured with accept evidence. | Pending: one bounded lane must show one-word accept with no submit. |
| Apple Notes title | 9/10 | [notes-title.png](visual-placement-screenshots/notes-title.png) | Bounded strict visual smoke at 2026-05-07T21:24:14Z shows inline title placement with two verified accepts and current proof fingerprints. | Pending: more title lengths and a live `notes-title-undo` run. |
| Apple Notes body | 9/10 | [notes-body.png](visual-placement-screenshots/notes-body.png) | Bounded strict visual smoke at 2026-05-07T23:33:48Z shows inline body placement with two verified accepts and current proof fingerprints. The retention check now correctly treats accepted word-completion suffixes as kept inside completed words. | Pending: more body lengths and a live `notes-body-undo` run. |
| Apple Notes checklist | 9/10 | [notes-checklist.png](visual-placement-screenshots/notes-checklist.png) | Bounded strict visual smoke at 2026-05-08T00:21:33Z shows native checklist-row placement with two verified accepts and current proof fingerprints. | Pending: checked items, longer checklist rows, and a live `notes-checklist-undo` run. |
| Claude Code | 9.5/10 | [claude-code-terminal.png](visual-placement-screenshots/claude-code-terminal.png) | Bounded strict visual smoke at 2026-05-08T17:04:17Z proves inline Terminal-host placement plus a one-word Tab accept in the real Claude Code prompt without shell or agent submit. The adapter stays proof-only, marker-gated, shell-command guarded, active-output guarded, stale-focus rechecked, host-labelable, and full-accept disabled. | Pending: host-labeled iTerm2 and Ghostty proof rows on this Mac; Warp is not installed here; separate full-accept no-submit proof stays blocked. |
| Claude desktop | 9.2/10 | [claude-desktop.png](visual-placement-screenshots/claude-desktop.png) | Bounded strict visual smoke at 2026-05-08T03:49:56Z proves same-baseline ghost placement plus a one-word Tab accept in the real Claude desktop composer without a submit signal. The proof lane now has bounded layout commands for empty, long, wrapped, narrow, context, light, and dark prompt layouts. | Pending: record those layout rows; full accept remains disabled because no safe full-accept no-submit proof command exists yet. |

## Latest Proof

- 2026-05-08 continuation hardening pass: post-accept verification now fails
  closed when the frontmost app, focused text context, or focused field no
  longer matches the accepted suggestion baseline; these cases trace as
  insertion failures and quiet the original field when configured.
- 2026-05-08 stable identity and unknown-field pass: stable-bounds field
  identity now uses deterministic hashing, and profiles reject unknown AX field
  kinds unless they explicitly opt in.
- 2026-05-08 local deletion pass: Settings deletion now removes compatibility
  learning artifacts along with raw/redacted traces, screenshots, and
  diagnostics.
- Suggestion orchestrator refactor pass: `swift test --filter
  SuggestionOrchestratorTests` passed 18 focused app tests after moving active
  request ownership, rich request construction, request-ticket gating,
  runtime session-cache metadata, app-model candidate metadata, display-score
  construction, streaming partial pacing state, replacement gating, placement
  planning, Chrome synthetic-caret proof gating, and placement-fallback metadata,
  prefix-cooldown display pressure, field-delivery race gating, failure
  visibility gating, fast word-selection delegation, engine delegation, and
  runtime-reload engine replacement behind `SuggestionOrchestrator`.
- Chrome proof-runner pass: `swift test --filter AppProofCommandRunnerTests`
  passed 7 focused app tests and `./script/real_app_smoke_self_test.sh` passed
  after the Settings Chrome proof command started running the forced
  all-fixtures lane plus default-AX real Monaco and real ProseMirror add-on
  lanes, and failed proof command starts now clean up temporary proof mode.
- Sentence-streaming restraint pass: `swift test --filter
  SuggestionPresentationGateTests` passed after sentence-mode streaming started
  requiring a fuller three-word partial and capping sentence streaming to one
  visible partial before the final result.
- Key-capture failure classification pass: `swift test --filter
  DiagnosticsTypingHealthTests` and `./script/check_typing_performance_log_self_test.sh`
  passed after event-tap start failures and failed-closed markers started
  counting as hard key-capture failures while AX polling warnings remain in
  their separate suggestion-responsiveness lane.
- Keyboard capture completion pass: stress tests now cover event-tap disable,
  focus/protected-field movement during accept, selected-text/stale accept
  blocks, IME/dead-key and modifier collision pass-through, repeated Tab replay
  suppression, Esc zero-text dismissal, fast typing invalidation, and replay/drop
  diagnostics that keep key-capture safety separate from AX warning noise.
- Proof-manifest honesty pass: variant-incomplete A- rows now stay `partial`
  in `docs/product/proof-manifest.json`, and
  `./script/check_proof_manifest_self_test.sh` covers partial live proof that
  verifies trace slices but still fails strict `--require-all`.
- Five-agent continuation pass: prompt-app safety hardening, strict visual proof
  gates, focused-text AX-health cooldown, Notes/Obsidian proof triage, and
  Apple-native polish ranking all completed on branch
  `codex/trust-first-autocomplete-hardening`.
- Current focused-text endurance pass: full `swift test` passed 599 tests after
  adding bounded AX string-range reads around the caret and stabilizing the
  TextEdit endurance harness.
- Local final polish pass: full `swift test` passed 326 tests, and
  `swift test --filter DiagnosticsTypingHealthTests`,
  `swift test --filter SettingsWindowControllerStateTests`, and
  `swift test --filter FocusedTextAXHealthPolicyTests` passed after adding the
  Diagnostics typing-health summary, Settings "why hidden" copy, calmer menu
  status titles, and AX-health cooldown diagnostics.
- Prompt-app safety worker pass: full `swift test` passed 318 tests after
  keeping prompt-app full accept disabled until separate full-accept no-submit
  proof exists and suppressing unsafe prompt actions like Enter/send/submit/run.
- AX-health worker pass: full `swift test` passed 318 tests after wiring
  app-specific focused-text AX cooldowns before/after serial reads.
- Strict proof gate worker pass: visual and manual smoke self-tests passed, and
  live strict gates fail honestly on the current pending app-proof rows.
- `./script/smoke_test.sh`: passed after the final diagnostics/status/docs
  pass. It ran 326 Swift tests, test coverage manifest, model asset self-test,
  manual smoke self-test, real-app smoke self-test, visual evidence self-test,
  trace eval self-test, typing performance self-test, model latency self-test,
  package preflight, app build/sign/verify, and diagnostics verification. The
  fresh diagnostics slice showed event-tap latency had no samples, no slow tap
  markers, no tap disable events, focused poll p95 max 3ms, focused poll max
  94ms, one off-main slow focused-poll marker, and two focused-poll skips. The
  typing guard passed because key capture stayed clean and AX slowness is now a
  suggestion-responsiveness warning.
- `./script/manual_smoke_status.sh --strict`: exits 1 honestly. Remaining
  prompt-app insertion gap is Codex. Claude Code now has terminal-host strict
  visual proof with one verified one-word no-submit accept. Codex still needs
  same-slice one-word no-submit visual proof.
- `./script/check_score_targets.sh`: exits 1 honestly on the current docs with
  69 target and proof-gate misses across this scorecard, the Apple-native
  checklist, the app proof matrix, manual smoke status, visual evidence, and
  the proof manifest. This makes the requested "all 10s / all 100s / all As"
  target executable instead of subjective.
- `swift test --filter ClaudeCodeTerminalHostProofPolicyTests`: passed 8 tests
  after adding the Claude Code terminal-host proof profile and input-line
  extraction. This proves the adapter gate blocks unsupported hosts, missing
  proof mode, missing proof markers, shell prompts with commands, and multiline
  buffers before any live terminal-host proof can count.
- `AUTOCOMPLETE_LAB_LOG_START_LINE=200587 AUTOCOMPLETE_LAB_TRACE_START_LINE=56581 AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF_MARKER_CONFIRMED=1 script/manual_smoke_session.sh claude-code --check --visual`: passed after the live Terminal-hosted Claude Code proof inserted `ant` through the terminal host's own Paste menu, changing the disposable prompt from `inst` to `instant` without shell or agent submit.
- `./script/check_proof_manifest.sh`: verifies the machine-readable
  `docs/product/proof-manifest.json` against current proof-fingerprint
  constants, tracked screenshots, scorecard links, and matching manual smoke
  rows. It passes in report mode. Strict mode now also parses each matched
  trace JSONL slice, requires bounded line evidence, screenshot-backed
  presented events for strict visual proof, verified insertions, and current
  proof fingerprints. It verifies the latest bounded trace slices for TextEdit,
  real Chrome editor lanes, Chrome chat-like, Obsidian, Notes title/body/checklist,
  and Claude desktop. Require-all mode still fails on partial or pending surfaces.
- `./script/typing_performance_endurance_soak.sh --minutes 1 --strict-ax --require-ax-samples 5`:
  passed with exact 1,200-character TextEdit verification, no tap-disable
  events, focused-poll p95 max 25ms, focused-poll max 51ms, zero focused-poll
  slow markers, and zero focused-poll skips. Event-tap samples are no longer
  required for this normal-typing soak because keyboard capture intentionally
  starts only while a suggestion is visible.
- `script/typing_performance_endurance_soak.sh --minutes 1 --strict-ax --require-ax-samples 5`:
  passed again on 2026-05-08 after active-typing cadence backoff and unique
  TextEdit file targeting. It verified exact 1,200-character TextEdit text,
  event-tap p95 51us, p99 99us, focused-poll p95 max 11ms, focused-poll max
  37ms, zero focused-poll slow markers, and zero focused-poll skips.
- `script/typing_performance_endurance_soak.sh --minutes 2 --strict-ax --require-ax-samples 5`:
  passed on 2026-05-08 after adding longer long-document select/copy settling
  to the soak capture step. It verified exact 2,400-character TextEdit text,
  event-tap p95 78us, p99 87us, focused-poll p95 max 27ms, focused-poll max
  50ms, zero focused-poll slow markers, and zero focused-poll skips.
- `./script/typing_performance_endurance_soak.sh --minutes 4 --strict-ax --require-ax-samples 5`:
  passed with exact 4,800-character TextEdit verification through the prior
  4,000-character drift point, focused-poll p95 max 38ms, focused-poll max
  90ms, four under-threshold slow markers, and zero focused-poll skips.
- `script/typing_performance_endurance_soak.sh --minutes 4 --strict-ax --require-ax-samples 5`:
  passed again on 2026-05-08 after active-typing cadence backoff and
  long-document capture settling. It verified exact 4,800-character TextEdit
  text, event-tap p95 65us, p99 87us, focused-poll p95 max 22ms,
  focused-poll max 58ms, zero focused-poll slow markers, and zero focused-poll
  skips.
- `./script/typing_performance_endurance_soak.sh --minutes 10 --strict-ax --require-ax-samples 5`:
  passed the full 10-minute gate with exact 12,000-character TextEdit
  verification, no tap-disable events, focused-poll p95 max 57ms,
  focused-poll max 87ms, 4 under-threshold slow markers, and zero focused-poll
  skips after the fast word-completion context reuse pass.
- `script/typing_performance_endurance_soak.sh --minutes 10 --strict-ax --require-ax-samples 5`:
  passed again on 2026-05-08 after active-typing cadence backoff and
  long-document capture settling. It verified exact 12,000-character TextEdit
  text, event-tap p95 78us, p99 82us, focused-poll p95 max 35ms,
  focused-poll max 57ms, zero focused-poll slow markers, and zero focused-poll
  skips.
- Latest harness hardening now creates the disposable TextEdit target as a
  unique temporary `.txt` file and opens that exact filename through TextEdit,
  captures via clipboard while restoring the previous clipboard, refocuses the target window
  before each 250-character segment, and uses bounded AX string-range reads
  around the caret so long TextEdit documents do not require full-value AX reads
  on the hot path.
- `./script/scorecard_goal_loop.sh --iterations 10`: completed all 10 requested
  proof-loop iterations and still failed, as expected, because the same manual
  app-proof gaps remain. It is now the repeatable repo command for grinding
  against the score targets without inflating grades.
- Latest live TextEdit proof: after launching with TextEdit proof mode,
  `AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 AUTOCOMPLETE_LAB_REAL_APP_SKIP_BUILD=1 ./script/real_app_smoke.sh textedit --skip-build`
  passed at 2026-05-08T10:07:34Z with two verified accepts, strict screenshot
  trace evidence, bounded diagnostics lines 175090-175129, bounded trace lines
  50702-50711, and current trace/placement/key/runtime proof fingerprints. The
  prior 2026-05-08T09:16:49Z full smoke pass also proved accepted-insertion
  undo.
- Latest live Notes body proof: `AUTOCOMPLETE_LAB_LOG_START_LINE=138145 AUTOCOMPLETE_LAB_TRACE_START_LINE=35010 AUTOCOMPLETE_LAB_SMOKE_ACCEPT_ALL_SHORTCUT=optionTab ./script/manual_smoke_session.sh notes-body --check --visual`
  passed at 2026-05-07T23:33:48Z with two verified accepts, strict screenshot
  trace evidence, bounded diagnostics lines 138146-138299, bounded trace lines
  35011-35048, and current trace/placement/key/runtime proof fingerprints.
- Latest live Notes checklist proof: `AUTOCOMPLETE_LAB_LOG_START_LINE=138740 AUTOCOMPLETE_LAB_TRACE_START_LINE=35082 AUTOCOMPLETE_LAB_SMOKE_ACCEPT_ALL_SHORTCUT=optionTab AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/manual_smoke_session.sh notes-checklist --check --visual`
  passed at 2026-05-08T00:21:33Z with a visible native checklist circle, two
  verified accepts, strict screenshot trace evidence, bounded diagnostics lines
  138741-138783, bounded trace lines 35083-35095, and current
  trace/placement/key/runtime proof fingerprints.
- Latest older live typing soak: `./script/typing_performance_soak.sh --skip-build --characters 1800 --chunk-size 10 --delay-ms 15 --require-event-tap-samples 100`
  passed after increasing the post-typing focused-text poll pause. The hard key
  path stayed clean over 600 event-tap summary samples: p95 max 35us, p99 max
  95us, max 161us, zero slow markers, and zero tap-disabled events. The same
  run still reported off-main AX polling warnings: focused poll p95 max 59ms,
  focused poll max 209ms, two slow markers, and four in-flight skip events.
- Current multi-agent hardening pass: `swift test` passed 303 tests after wiring slow-poll throttle, stale-context suppression, event-tap fail-closed handling, app-scoped recent-word memory, fast-word repeated-miss suppression, dogfood false-positive tests, neutral word-completion vocabulary tests, privacy-expiry tests, support-status tests, serial AX reader tests, settings state tests, and faster AX value replacement.
- Follow-up strictness/performance pass: `swift test` passed after AppDelegate routed focused-text polling through the serial off-main AX reader; `./script/manual_smoke_self_test.sh` passed after `manual_smoke_status.sh --strict` started failing on pending screenshot proof, not just missing insertion proof.
- `./script/smoke_test.sh`: passed after the serial AX polling and checker split. The final diagnostics slice started at line 75648 and showed no event-tap latency samples, no slow tap markers, no tap disable events, focused poll p95 max 3ms, focused poll max 21ms, and zero focused-poll skips.
- `./script/check_trace_eval_self_test.sh`: passed after trace evaluation started verifying screenshot files and placement failure details.
- `./script/check_typing_performance_log_self_test.sh`: passed after typing performance checks defaulted to a bounded recent log window.
- `AUTOCOMPLETE_LAB_LOG_START_LINE=75390 AUTOCOMPLETE_LAB_TYPING_PERF_REQUIRE_SAMPLES=1 ./script/check_typing_performance_log.sh`: passed on the fresh TextEdit smoke slice with event-tap p95 96us. Off-main focused-text poll warnings are reported separately so slow AX reads do not masquerade as key latency.
- `git diff --check`: passed for the current hardening patch before commit.
- Settings polish pass: `swift build --target AutocompleteLabApp`, `swift test --filter AutocompleteLabAppTests`, and full `swift test` passed before commit `95f9583`.
- Screenshot-evidence pass: `script/check_trace_eval_self_test.sh`, `script/check_visual_placement_evidence_self_test.sh`, and `script/check_visual_placement_evidence.sh` passed before commit `faffcad`.
- App proof matrix pass: `git diff --check` and `./script/check_visual_placement_evidence.sh` passed before commit `6ef3bd1`.
- Prior full `swift test`: 273 tests passed before this script/docs-only no-submit fixture pass; no Swift sources changed in this loop.
- Apple-native placement pass: `swift test` now passes 274 tests after adding the inline frame guard that clips at the caret and suppresses too-narrow inline panels instead of showing invisible or wrong-side ghost text.
- `./script/manual_smoke_self_test.sh`: passed after adding Chrome chat-like no-submit to the self-test proof ledger.
- `bash -n script/real_app_smoke.sh script/real_app_smoke_self_test.sh script/manual_smoke_session.sh script/manual_smoke_status.sh`: passed after adding the chat-like no-submit guard.
- `./script/real_app_smoke_self_test.sh`: passed, including dry-run coverage for the Chrome chat-like fixture and the all-fixtures plan.
- `AUTOCOMPLETE_LAB_CHROME_FIXTURE=chat-like ./script/manual_smoke_session.sh chrome --print`: passed and points chat-like proof toward `script/real_app_smoke.sh chrome --fixture chat-like` so submit count is checked.
- `./script/manual_smoke_self_test.sh`: passed.
- `AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh textedit`: passed with two verified accepts and screenshot capture.
- `AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh chrome --fixture chat-like`: passed with two verified accepts, strict visual trace evidence, and submit count zero after switching the fixture check from Chrome JavaScript execution to a tab-title submit marker.
- Prior `AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh chrome --fixture all`: passed for textarea, contenteditable, editor-like, Monaco-like, and ProseMirror-like fixtures before the chat-like fixture was added.
- `AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh chrome --fixture monaco-like`: passed after the final Monaco gap adjustment.
- `./script/smoke_test.sh`: passed after the visual-evidence telemetry change, including model asset, trace eval, typing-performance, real-app smoke self-test, visual evidence, and package preflight checks. Latest focused-text poll p95 was 3ms, max was 4ms, with no slow markers.
- `AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh textedit`: passed on a fresh app launch with two verified accepts and screenshot tracing.
- `AUTOCOMPLETE_LAB_TRACE_START_LINE=20143 AUTOCOMPLETE_LAB_TRACE_END_LINE=20158 AUTOCOMPLETE_LAB_TRACE_REQUIRE_APP=com.apple.TextEdit AUTOCOMPLETE_LAB_TRACE_REQUIRE_CONFIDENT_PLACEMENT=1 AUTOCOMPLETE_LAB_TRACE_REQUIRE_VISUAL_EVIDENCE=1 ./script/check_trace_eval.sh`: passed with `Visual evidence complete: 2/2`, high placement confidence, and p90 suggestion latency of 113ms.
- Live Codex disposable prompt probe: screenshot `visual-placement-screenshots/codex-inline.png` shows visible inline ghost text after the caret on the negative-origin side display; focused poll p95 was 5ms and event-tap p95 stayed in microseconds during the probe.
- Hardening pass: focused Swift tests passed for sensitive field policy, selected-text activation blocking, capped synthetic caret estimation, vertical clipping, and stale text-line rejection.
- Full smoke pass after hardening: `./script/smoke_test.sh` passed. Fresh diagnostics from line 64151 scanned 240 focused-text poll samples with p95 max 2ms, max 3ms, zero slow markers, and zero skipped polls.
- `script/beta_readiness.sh` now includes `./script/check_visual_placement_evidence.sh --require-all`, so beta readiness cannot pass while screenshot proof rows are still pending.
- Local chat-like Chrome fixture was added to prove Tab/full accept does not submit a chat-style composer. This is the safe precursor to Codex/Claude no-submit proof, not a substitute for real prompt-app proof.
- Chrome-hosted Google Docs, Notion, Slack, and Discord now return a trace-safe
  `unsupported-browser-surface` block until those production surfaces have
  screenshot-backed insertion and no-submit proof.
- Parent handoff: a disposable Notes note produced screenshot-backed suggestion presentation and at least one verified Tab insertion, but this is generic historical evidence only. The later bounded Notes title and body runs are complete; checklist still needs its own proof.
- `./script/manual_smoke_status.sh --strict`: now shows Chrome chat-like no-submit, Obsidian, Notes title/body/checklist, Claude Code, and Claude desktop as passed, and fails honestly on Codex prompt proof and remaining score targets. The current prompt-app blocker is Codex same-slice insertion proof.
- `./script/check_visual_placement_evidence_self_test.sh`: passed, including missing, empty, invalid, too-small, unreferenced, and pending strict screenshot failure cases.
- `./script/check_visual_placement_evidence.sh`: passed with 16 verified visual-placement screenshots and reports the stale same-slice Codex row.
- `./script/check_visual_placement_evidence.sh --require-all`: fails honestly on the remaining Codex same-slice proof gap.
- `AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh chrome --fixture prosemirror-real`: passed at 2026-05-08T03:17:54Z with pinned upstream ProseMirror, isolated temp-profile Chrome, renderer accessibility forced, strict screenshot evidence, Tab accept, Option-Tab full accept, and two verified insertions.
- `AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh chrome --fixture monaco-real --skip-build`: passed at 2026-05-08T03:19:38Z with pinned upstream Monaco, isolated temp-profile Chrome, renderer accessibility forced, strict screenshot evidence, Tab accept, Option-Tab full accept, and two verified insertions. Monaco's own suggestions are disabled in the fixture so the proof targets Autocomplete Lab, not Monaco's completion menu.
- Historical default-Chrome real-editor proof from 2026-05-08 is no longer treated as current. The 2026-05-09 follow-up fixed the normal-Chrome smoke harness so it raises the matching smoke fixture tab before typing/checking, then recorded fresh `monaco-real-default` and `prosemirror-real-default` rows with two verified accepts and strict visual evidence on `834dd2843b6a`.
- Chrome production-proof harness pass: `bash -n script/real_app_smoke.sh script/manual_smoke_session.sh script/real_app_smoke_self_test.sh`, `./script/real_app_smoke_self_test.sh`, and `./script/check_proof_manifest.sh` passed after adding `codemirror-official`, `monaco-official`, and `prosemirror-official` dry-run lanes. These lanes do not raise the Chrome score yet because no bounded official-demo trace has passed.
- Chrome smoke safety hardening: the real-app smoke script now refuses concurrent proof runs through a local lock plus an active-process scan, checks that Chrome is frontmost with the expected active tab URL, fails official-demo lanes fast when Chrome JavaScript from Apple Events is disabled, requires a focused editable web text AX target, and sends Chrome setup text to the Chrome process with AX value verification instead of global setup keystrokes. This was added after interrupted production-proof attempts exposed stale concurrent smoke processes and global keystroke focus changes as wrong-app typing risks. Scores remain unchanged until a clean official-demo proof run completes.
- `./script/manual_smoke_self_test.sh`: passed after prompt-app no-submit
  proof started requiring exactly one trace-level accept and rejecting
  trace-level full-accept or field-send finalization signals.
- `swift test --filter CompatibilityLearningTests`: passed, covering trusted manual visual offsets and untrusted stale-offset rejection.
- `swift test --filter 'PlacementHealthTests|CompatibilityLearningTests|VisualPlacementGeometryCorrectionPolicyTests'`: passed after synthetic caret confidence and visual-offset trust hardening.
- `swift test`: passed on the visual self-healing proof branch with 982 tests.
- `./script/visual_calibration_report_self_test.sh`: passed, including applied/refused correction reasons, geometry-only screenshot correction proof, and raw-text/screenshot-path leak checks.
- `./script/check_visual_placement_evidence.sh`: passed with 16 verified screenshot-backed rows.
- `AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 AUTOCOMPLETE_LAB_REAL_APP_SKIP_BUILD=1 ./script/real_app_smoke.sh textedit --skip-build`: passed at 2026-05-09T02:09:53Z with two verified accepts and strict visual trace evidence.
- `./script/visual_calibration_report.py --start-line 60617 --diagnostics-start-line 235335 --require-app com.apple.TextEdit`: reported `Screenshot correction proof: com.apple.TextEdit: applied=3 refused=1 improved=3 bestImprovement=13.5 ... privacy=geometry-only:4`.
- `./script/check_trace_eval_self_test.sh`: passed, including strict visual-evidence guardrails for screenshot path, anchor rect, rendered panel rect, capture rect, and placement confidence.
- `git diff --check`: passed.
- `swift build`: passed after the screenshot trace capture-rect changes.

## What Changed In This Pass

- Screenshot capture now runs asynchronously, preflights Screen Recording access,
  and avoids stealing focus.
- Screenshot tracing now captures the editor bounds plus the rendered suggestion,
  so visual placement can be graded from real pixels.
- Streaming model partials no longer schedule repeated screenshot captures.
- Chrome moved to synthetic inline caret placement with mirror fallback instead
  of defaulting to a detached floating mirror.
- Inline ghost text now uses a neutral readable color instead of trusting
  unreliable app-reported foreground colors.
- Browser rich-editor synthetic caret tuning now handles textarea,
  contenteditable, CodeMirror-style, Monaco-like, and ProseMirror-like fixtures
  separately.
- Real-app smoke now waits for screenshot capture when tracing is enabled and
  asserts the target app is still frontmost before accepting.
- Screenshot evidence has been committed only from disposable TextEdit/Chrome
  fixtures, not from private prompts or user work.
- Visual-placement evidence now has an executable repo check that fails on
  missing, empty, invalid, too-small, or unreferenced screenshots.
- Manual smoke status now separates insertion proof from screenshot-backed
  placement proof, and the visual evidence check can fail on pending audit rows.
- Trusted learned visual offsets now apply to synthetic-caret apps such as
  Codex, Obsidian, and Chrome; untrusted stale offsets are still ignored.
- Trusted visual offsets are now scoped to target app version, screen, and field
  shape, so a manual or future screenshot correction expires when that context
  changes instead of silently applying to a different layout.
- Manual visual nudges now target the visible suggestion's app instead of
  relying on frontmost-app state after the menu opens, and the visible ghost
  moves immediately after the nudge.
- Synthetic caret anchors now emit `placementAnchorSource=synthetic-caret` and
  medium confidence instead of pretending to be high-confidence real AX carets.
- Generic presentation observations can no longer make visual offsets trusted;
  only manual visual nudges and future screenshot visual corrections can.
- Screenshot pixel offset detection now has a pure, unit-tested detector that
  finds high-contrast ghost/panel drift inside a bounded search region, rejects
  blank or low-contrast screenshots, rejects outlier offsets, and feeds the
  existing visual correction trust gate.
- Screenshot capture now runs that detector after a PNG is captured and records
  offset metadata (`screenshotOffsetDetection`, confidence, pixels, dx/dy, and
  signal bounds).
- Per-app screenshot tracing now lets high-confidence detector output write a
  trusted scoped correction through `VisualPlacementCorrectionPolicy`; global
  screenshot tracing remains diagnostics-only.
- Trusted corrections now carry explicit `applied`, `refused`, or `none`
  status plus refusal reasons for app-version, screen, field-shape, missing
  context, missing scope, and insufficient evidence.
- Screenshot correction proof now records before/after distance, improvement,
  and the `geometry-only` privacy boundary, so reports can explain when a
  correction helped and when it was refused without leaking raw content.
- Screenshot traces now carry the capture rect in trace metadata and diagnostics.
- Suggestion presentation traces now carry the rendered panel rect, and
  diagnostics keep geometry-shaped keys readable instead of redacting them as
  text.
- Trace evaluation now has an opt-in strict visual-evidence gate that fails a
  screenshot-backed pass unless screenshot path, anchor rect, rendered panel
  rect, capture rect, and placement confidence are all present.
- Manual Notes proof now uses first-class `notes-title`, `notes-body`, and
  `notes-checklist` recorder targets; generic Notes rows are historical
  evidence only and do not close those gaps.
- Manual recorder rows only claim strict screenshot evidence when strict trace
  visual evidence was required and passed.
- Trace evaluation can now bound a proof slice with `AUTOCOMPLETE_LAB_TRACE_END_LINE`,
  so later app activity cannot pollute a completed real-app proof run.
- Password/token/API-key-like fields are now treated as sensitive from AX
  fingerprint metadata before editable text is read.
- Suggestions are now blocked while text is selected, preventing Tab accept from
  replacing highlighted user content.
- Screenshot tracing now skips captures when a small backlog exists and times
  out stuck `screencapture` processes.
- Synthetic caret estimation now measures only a bounded tail of the current
  paragraph, so long prompts cannot make wrapping work grow without bound.
- Inline and floating frames now clamp vertically to editor clipping bounds, and
  stale text-line rectangles far from the caret are ignored.
- Inline ghost frames now prefer staying attached to the caret over sliding left
  to fit inside cramped bounds; if too little visible width remains, the
  suggestion is suppressed so Tab cannot accept invisible text.
- A local Chrome chat-like no-submit fixture now tracks form submissions and
  fails the smoke run if Tab/full accept submits the disposable composer.
- A 15-minute Codex automation exists outside this repo to check this scorecard;
  the repository itself still treats the below-10 rows as open work.
- Typing performance checks now scan the last bounded log window by default
  while preserving an all-history override. The checker now treats event-tap
  latency as the hard typing guard and reports off-main focused-text poll
  slowness as a separate warning unless strict AX-poll enforcement is requested.
- Slow focused-text poll summaries and overlapping-poll summaries now apply
  throttle/backoff and hide visible suggestions instead of continuing to chase
  the caret during a slow AX stretch.
- Async model and streaming suggestions now refresh current focused app, field,
  prompt target, and surrounding text before display, suppressing stale results
  instead of showing ghost text at old geometry.
- Keyboard capture now starts only after `suggestionPanel.show` returns a usable
  panel frame, closing the invisible-panel/Tab-capture gap.
- The keyboard event tap now fails closed when macOS disables it for timeout or
  user-input reasons.
- AX value replacement removed fixed 30ms and 40ms sleeps from the accept hot
  path while keeping immediate read-back confirmation plus async insertion
  verification.
- Recent word memory is now scoped by app bundle, so learned local vocabulary
  does not bleed from one app into another.
- Fast word completion now uses the same repeated-miss suppression as model
  completions before showing anything.
- The global word-completion list no longer includes Codex, Transcripted,
  autocomplete, diagnostics, traces, or other lab/debug vocabulary.
- Dogfood prompt detection now uses explicit phrases and token boundaries, so
  normal words like `table`, `stable`, `model`, and `test` do not pull
  suggestions toward autocomplete debugging topics.
- Settings now uses clearer native sections, checkbox controls, app state copy,
  privacy diagnostics copy, and app-target state tests.
- Inline ghost text now uses the system placeholder color instead of a fixed
  gray, with light, dark, and high-contrast appearance coverage tests.
- App bundle checks now verify the generated ICNS is valid, multi-size, and
  declared by Info.plist.
- Raw text capture, global screenshot tracing, and per-app screenshot tracing
  now expire when enabled from Settings, and deleting local privacy logs also
  disables those capture modes where possible.
- Settings and menu copy now expose green/yellow/diagnostics-only/unsupported
  app support status and disable toggles for unavailable apps.
- A serial off-main focused-text AX reader now exists with tests, and AppDelegate
  routes live focused-text polling through it.
- App-specific focused-text AX health now cools down only the slow app after
  repeated slow reads, records active cooldown/recovery diagnostics, and keeps
  typing passthrough separate from suggestion responsiveness.
- Slow focused-text AX reads that return no focused text context now start a
  short app-specific cooldown immediately, so fields that are slow and
  unreadable stop being chased before a second slow read is required.
- A single slow focused-text AX read with context now starts an immediate
  focused-text polling throttle and drops that returned context, so a stale
  slow read cannot produce the next visible suggestion.
- Diagnostics now shows a typing-health summary that separates key capture from
  AX polling/cooldown health.
- Settings now shows the last suggestion decision as "Why", and menu bar status
  copy is calmer while detailed reasons stay in the tooltip/diagnostics.
- Codex, Claude Code terminal-host, and Claude desktop prompt profiles require
  one-word no-submit proof and keep full accept disabled until separate
  full-accept no-submit proof exists. The direct Claude Code bundle stays
  diagnostics-only; prompt completions now reject unsafe submit/run actions.
- Prompt-app smoke proof now requires exactly one trace-level accepted
  suggestion and rejects full-accept or field-send finalization signals before
  it records Codex, Claude Code terminal-host, or Claude desktop as a prompt
  no-submit pass.
- App-level Command-Z undo now clears acceptance-survival tracking and records
  `acceptanceRetentionCleared` with `accepted-insertion-undone`, so deliberate
  undo is not treated as accidental accepted-then-deleted. The TextEdit smoke
  lane now has a fresh live pass that asserts this log event; remaining undo
  work is per-app coverage beyond TextEdit.
- Codex prompt proof now also requires explicit confirmation that the disposable
  prompt contains `AUTOCOMPLETE_LAB_CODEX_PROOF`; unmarked Codex proof slices
  fail before they can be recorded.
- Settings now mirrors that Codex proof marker requirement so the in-app proof
  copy cannot guide an operator into a recorder-rejected prompt pass.
- Output cleaning suppresses more assistant-y starts and rejects unrelated
  whole-word completions in word-completion mode. It also rejects
  recommendation, rewrite, next-action, "you should", "we need to", and
  "I'd recommend" candidates so a separate product behavior cannot masquerade
  as inline autocomplete.
- Word completion keeps suffix-only behavior while preserving typed casing, so
  uppercase fragments complete with uppercase suffixes and mixed-case recent
  words can keep their useful casing. Activation and fast ranking now share a
  3+ typed-letter floor so 2-letter guesses stay quiet.
- Phrase and sentence cleaning now suppresses candidates that still restart the
  current sentence or duplicate visible typed words after prefix trimming.
- Sentence-mode ranking now suppresses invented action commitments like
  scheduling, calls, new names, and dates instead of treating them as harmless
  sentence starters.
- Dogfood prompt guidance and output cleaning now reject generic productivity
  filler like boosting productivity, streamlining workflows, and unlocking
  efficiency.
- Workspace app activation/deactivation now clears the focused field, hides
  visible suggestions, stops key capture, and invalidates pending requests
  immediately instead of waiting for the next poll.
- Esc dismissal now records that it inserted zero suggestion text, so replay
  and diagnostics can distinguish pure dismissal from acceptance paths.
- Repeated typed-over misses now escalate from a short prefix cooldown to a
  longer quiet period and then raise display thresholds for that same
  app/field/mode/prefix family after cooldown.
- Punctuation cadence is now profile-aware at fragile boundaries: email
  greeting commas and short list-label colons wait longer, while coding closing
  brackets stay quiet.
- Sentence continuations now keep a tighter 10-token generation ceiling even
  when environment overrides raise the global ambient token cap.
- Accepted-kept style memory now includes raw-text-free suffix shape: short
  suffix rate and average final-token length.
- Chrome chat-like no-submit proof now uses a tab-title submit counter so the
  smoke test works even when Chrome JavaScript execution from Apple Events is
  disabled.
- Real-app smoke now waits for and verifies the configured full-accept shortcut
  (`backtick` or `optionTab`) instead of hard-coding Backtick, which fixed a
  live TextEdit smoke failure on machines where the shortcut state differs.
- The post-typing focused-text poll pause increased from 120ms to 220ms so
  repeated normal typing gives AX reads more room before the app resumes chasing
  the caret.
- Score targets are now checked by `script/check_score_targets.sh`, self-tested
  by `script/check_score_targets_self_test.sh`, and looped by
  `script/scorecard_goal_loop.sh --iterations 10` together with strict manual
  smoke status, strict visual evidence, and the proof manifest gate.
- Stable-bounds field identity now uses deterministic normalized metadata and
  rounded geometry instead of Swift's process-random `Hasher`, so proof traces
  for hard editor surfaces no longer get new field IDs just because the lab app
  restarted.
- Profile-aware acceptance safety now runs before insertion: no-submit prompt
  profiles block full accept and any accepted text that is multiword,
  non-visible, or contains newline/tab/control characters.
- Clipboard fallback restore now preserves user clipboard changes by restoring
  the original pasteboard only when the delayed restore still sees this app's
  temporary fallback text at the same pasteboard change count.
- `script/typing_performance_endurance_soak.sh` now wraps the safe TextEdit
  soak with a 10-minute default, typing-like 5-character chunks, exact named
  TextEdit document verification, temporary TextEdit enablement, temporary
  pause-state restore, AX warmup flushing, a CGEvent Unicode typing driver that
  focuses and verifies the target TextEdit window before each Swift batch,
  bounded cleanup, segmented Swift typing batches, and dry-run self-test
  coverage.

## Remaining Gaps

1. Run Codex one-word accept/no-submit proof in the same strict visual trace
   slice. Claude Code and Claude desktop now have one-word no-submit proof, but
   still need more prompt-layout and full-accept no-submit coverage before broad
   prompt support can be considered done.
2. Test real production Monaco, ProseMirror, and CodeMirror apps, not just local
   fixtures.
3. Add more first-run proof coverage beyond TextEdit and Chrome so setup can
   steer users away from unsupported or still-unproven apps before they try
   them.
4. Add a fuller shortcut editor if beta users need more than Tab plus the
   current full-accept toggle in proven apps.
6. Keep focused-text polling on the serial AX reader and collect live long-form
   typing proof in the worst real apps.
7. Use the same no-submit expectation for Codex/Claude prompt-app proof now
   that the local Chrome chat-like fixture has screenshot-backed proof.
8. Split AppDelegate into focused services around polling, insertion,
   verification, screenshot tracing, and placement tuning.
9. Run explicit disposable raw-content dogfood audits for suggestion quality;
   default tracing correctly protects privacy, but it cannot fully grade output
   relevance without opt-in raw text.
10. Keep `./script/check_score_targets.sh` and
    `./script/scorecard_goal_loop.sh --iterations 10` failing until every target
    row has real app proof, then raise scores only in the same commit as the
    proof.
11. Obsidian now has repairs for trailing characters, spacer rows, trailing
    hidden CodeMirror scaffolding, descendant `AXWebArea` text fallback, and
    text-verified post-insert surface recovery. It still needs a deterministic
    body harness or manual bounded proof because the current hand-driven note
    can leave the caret before four real after-cursor chars and correctly blocks
    as `middleOfLine`.
