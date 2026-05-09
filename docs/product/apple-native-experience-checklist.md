# Apple-Native Experience Checklist

Created: 2026-05-07

This is the working checklist for making Autocomplete Lab feel natural,
intuitive, fast, quiet, and almost native to macOS.

The product bar is not "AI appears everywhere." The bar is:

> Typing feels completely normal. Help appears only when it is useful, aligned,
> reversible, and calm.

## Current Executive Score

Overall Apple-native feel: 94/100.

This app has real engineering depth now. It is not a toy. It has local model
runtime support, strong privacy defaults, app compatibility profiles, insertion
verification, screenshot tracing, and a growing proof harness.

It is not yet Apple-native. The latest pass made the app more disciplined:
slow focused-text polling now throttles, stale async suggestions re-check the
focused field before showing, keyboard capture fails closed when macOS disables
the event tap, AX value replacement removed fixed hot-path sleeps, fast word
completion honors repeated-miss suppression, recent-word memory is scoped per
app, focused-text AX reads now run through a serial off-main reader,
acceptance now carries trace-safe proof that full accept exactly matches the
visible suggestion and Tab accepts only the visible next-word prefix,
raw/screenshot debug capture now expires from Settings, lab/debug
vocabulary was removed from the global word list, Chrome chat-like no-submit
and Notes checklist now have screenshot-backed proof, prompt-app full accept is disabled until
separate full-accept no-submit proof exists, app-specific slow AX reads cool
down without blocking typing, slow no-context AX reads cool down immediately,
single slow AX reads with context now throttle polling and drop the stale read,
Claude Code now has a proof-only terminal-host adapter gated by explicit proof
mode, marker checks, current input-line extraction, and shell-prompt rejection,
TextEdit now has a clean 10-minute live typing soak with exact
12,000-character verification, no focused-poll skips, no slow poll markers, and
normal key capture staying idle unless a suggestion is visible, app support
status is visible in Settings and the menu, Diagnostics
separates key-capture health from AX-poll health, placement confidence is
visible without suggestion text, placement uncertainty hides stale ghosts and
feeds quiet mode, active quiet mode is visible in Diagnostics, Settings now
reads more like a Mac utility, inline ghost text uses dynamic system placeholder
color instead of fixed gray, and missing/invalid model assets can be installed
or repaired from Settings with progress, cancellation, and runtime warmup.
First-run setup now explains Accessibility in one short paragraph and points
first success at TextEdit, not private notes.
Chrome-hosted Google Docs, Notion, Slack, and Discord now have an explicit
unsupported surface policy so the yellow Chrome profile does not silently
extend to unproved production editors or chat boxes. Post-accept insertion
verification now also fails closed when the frontmost app, focused text context,
or focused field no longer matches the accepted suggestion baseline.

The largest miss is still visual placement proof in real apps. Ghost text can
still be unproven or under-polished in Codex, terminal-hosted Claude Code,
production browser editors, and untested Claude desktop prompt layouts. A native-feeling Mac utility must
fail quietly when it is unsure. Wrong-place text is worse than no suggestion.

## Scoring Rubric

- 100: Feels system-owned. Fast, calm, predictable, and proven in real apps.
- 90: Beta-quality for normal people. Rare issues, clear recovery.
- 80: Strong prototype. Useful, but still visibly an independent app.
- 70: Promising. Some real value, but trust breaks in normal use.
- 60: Lab-only. Useful to dogfood, not safe for broad beta.
- 40: Fragile. Works in demos, fails in real writing.
- 20: Concept only.
- 0: Harmful or unshippable.

## Weighted Scorecard

| Category | Weight | Current | Target | Why |
| --- | ---: | ---: | ---: | --- |
| Typing must feel untouched | 15 | 100 | 100 | The strict TextEdit endurance harness now creates and captures the disposable target through a unique temp file, restores the clipboard, waits for long-document selection/copy to settle, and refocuses before each segment. Fresh live proof passed exact 1,200-, 2,400-, 4,800-, and 12,000-character TextEdit runs. After the active-typing cadence change, the fresh 2026-05-08 10-minute strict run verified exact 12,000-character TextEdit text, event-tap p95 78us, event-tap p99/max 82us, focused-poll p95 max 35ms, focused-poll max 57ms, zero slow markers, zero focused-poll skips, and zero tap disables. Normal typing no longer requires event-tap samples because keyboard capture intentionally starts only while a suggestion is visible, and recent text-change polling now backs off while the user is actively typing. |
| Visual placement and caret alignment | 18 | 91 | 100 | Stale async suggestions refresh focused geometry before display, unusable panels suppress before key capture, inline mode now hides when less than one useful word fits after the caret, screenshot-derived correction is wired behind explicit per-app screenshot tracing, learned visual offsets expire when target app version, screen, or field shape changes, low-confidence mirror fallback is suppressed for untrusted yellow profiles, mirrored-display ambiguity suppresses instead of guessing, display changes hide visible suggestions and cancel pending requests, and visible geometry snapshots now hide on window moves, scroll-like line movement, wrapped-line changes, and multiple-editable field switches instead of moving stale text late. Overlay panels also declare all-Spaces and fullscreen auxiliary behavior. Codex same-slice accept/no-submit proof and more prompt/editor screenshot layouts are still blockers. |
| Acceptance safety | 10 | 96 | 100 | Tab capture is gated behind an actually shown panel, insertion is verified, Esc dismissal is trace-marked as inserting zero suggestion text, full accept is blocked unless accepted text exactly matches the visible suggestion, Tab accept is traced as a visible-prefix accept, profile-aware acceptance safety blocks no-submit profiles from full accept, multiword accept, non-visible accept, and control-text accept before insertion, after-cursor drift fails verification, post-write missing-context or changed-field reads are recorded as insertion failures, the event tap fails closed, event-tap start/failed-closed markers now count as hard key-capture failures, Chrome chat-like proved Tab/full accept without submit, Claude Code and Claude desktop proved one-word Tab accept without submit, and prompt-app full accept is disabled until separate full-accept no-submit proof exists. Codex one-word no-submit proof is still incomplete. |
| Cross-app reliability | 10 | 92 | 100 | The proof matrix now has screenshot artifacts, Notes title/body/checklist are all split out, real Monaco/ProseMirror pass under isolated renderer-accessibility Chrome, Claude Code and Claude desktop have same-slice real prompt no-submit proof, every compatibility profile has owner/safety coverage in the proof manifest, and the app exposes green/yellow/diagnostics-only/unsupported status plus explicit copy-only fallback stance for non-sensitive diagnostics-only or untrusted-placement cases. Current default-Chrome real-editor proof is blocked by missing page-editor AX exposure. Chrome-hosted Google Docs, Notion, Slack, and Discord are now blocked by surface policy until real proof exists. Codex and more production editor variants are still pending proof. |
| Native macOS visual feel | 8 | 95 | 100 | Settings moved toward tested unframed native sections, checkboxes, clearer privacy/app controls, support status, copy-only fallback status, "why hidden" copy, and calmer menu copy. Diagnostics now opens with a short system-font inspector overview, onboarding/permission copy uses plain System Settings language, the menu bar uses a template SF Symbol with text fallback, inline ghost text uses a dynamic system placeholder color across light/dark/high-contrast appearance coverage, the bundle check now verifies a valid multi-size ICNS app icon, and Settings, Diagnostics, plus the suggestion overlay renderer have generated light/dark/high-contrast screenshot evidence. Real host-app light/dark document variants are still needed. |
| Privacy and permissions trust | 9 | 100 | 100 | Local-first and redaction are strong, recent-word memory no longer crosses app boundaries, raw/screenshot debug capture expires from the app UI, Settings shows share-safe privacy status, Diagnostics exports a redacted privacy bundle with a manifest/checklist, and the beta packet explicitly forbids raw traces, screenshots, prompts, typed text, and accepted text by default. |
| Suggestion quality | 8 | 95 | 100 | Output is bounded and filtered, repeated misses apply to fast word completion, repeated typed-over pressure now raises display thresholds for the same app/field/mode/prefix family, accepted-kept learning now adjusts display utility, accepted-kept display thresholds now vary by behavior profile, sentence-mode streaming waits for a fuller partial and caps at one visible partial, quiet/normal/eager aggressiveness now tunes cadence and display thresholds, learned word completion is app-scoped, word completion now has a consistent 3+ typed-letter floor, profile-aware fresh paragraph starts stay quieter, suffix overlap is salvaged, visible typed-word duplicates and phrase restarts are suppressed, dogfood prompts avoid generic productivity filler, unsafe prompt actions are suppressed, and assistant-y advice/planning output filters are stronger. Raw-content quality audits remain opt-in. |
| Failure restraint | 8 | 100 | 100 | Slow polling can hide suggestions, repeated slow app-specific AX reads cool down, slow no-context AX reads cool down immediately, single slow AX reads with context now throttle and drop stale results, stale geometry suppresses display, workspace focus changes immediately hide visible suggestions and invalidate pending requests, post-write target loss records an insertion failure, clipboard fallback requires both a runtime flag and an explicit profile opt-in, clipboard fallback restore preserves user clipboard changes, too-narrow inline placement suppresses instead of showing a sliver, sentence-mode streaming shows at most one partial before the final suggestion, untrusted low-confidence mirror fallback suppresses instead of showing detached placement, prompt/chat and sentence-like prose profiles require stronger accepted-kept probability after enough samples, copy-only fallback status is explicit where inline is unsafe, event-tap disablement/start/fail-closed markers fail the key path, unsafe captured accepts drop and diagnose the key, safe focus/stale blocks replay the original key, Diagnostics keeps key-capture failures separate from AX warnings, prompt full accept requires proof, placement uncertainty hides stale ghosts and feeds field quiet mode, active quiet mode is visible in Diagnostics, and unsupported apps explain their stance. |
| User control | 6 | 100 | 100 | Settings and the menu now expose pause, current-field silence, app blocking, support status, per-app render mode, force-mirror override, quiet/normal/eager aggressiveness, an app-proof starter, privacy diagnostics, temporary raw/screenshot capture, local log deletion, direct accept-all shortcut editing, and why the last suggestion was hidden. |
| Onboarding and setup | 4 | 100 | 100 | Settings explains Accessibility in one short paragraph, only mentions Screen Recording when screenshot capture is on, starts fresh installs with suggestion-capable apps off, points first success at enabling TextEdit, and installs or repairs the local model in-app with plain no-model-server recovery copy, progress, cancellation, failure retry, validation, and runtime warmup. The Apps section now shows visible proof instructions, shows the exact smoke command where one exists, copies the runnable command in one click, disables proof until the current app is enabled, and can launch TextEdit and Chrome smoke proof directly from Settings. TextEdit and Chrome automatic proof plans are unit-tested, the Settings action dispatch is unit-tested, and the current TextEdit skip-build proof passed against a proof-mode app with strict visual trace evidence. |
| Evidence and QA loop | 4 | 99 | 100 | Tests now include app-target settings state, privacy expiry, support status, serial AX reader, focused AX-health cooldown, deterministic stable-bounds field identity, key-capture failure classification, trace eval, strict manual-smoke status, executable score-target gates, a 10-iteration score loop, a self-tested 10-minute typing endurance command with exact TextEdit text checks, Notes text-context repair, Claude Code terminal-host adapter checks, and 16 screenshot artifacts including real Monaco/ProseMirror, same-baseline Claude desktop, and terminal-hosted Claude Code. Codex same-slice proof is still missing. |

Weighted score: 95/100.

## Non-Negotiable Native Feel Rules

- [ ] Normal typing must never lag, drop, swallow, or reorder keys.
- [ ] The app must never capture Tab unless a visible suggestion is active and safe.
- [ ] Inline ghost text must start at the caret, never visually before it.
- [ ] If the app cannot prove caret placement, it must use a safer mirror or hide.
- [ ] Wrong-place text is a release blocker.
- [ ] Suggestions must be suffix-only and must not repeat what the user already typed.
- [ ] The app must never write into a sensitive, password-like, token-like, or selected-text field.
- [ ] The app must never submit agent/chat prompts during proof or acceptance.
- [ ] The app must never require a user-managed model server.
- [ ] The app must default to local-first and privacy-preserving behavior.
- [ ] Debug screenshots and raw text traces must stay opt-in.
- [ ] Every supported app needs evidence, not hope.
- [ ] Unknown apps should start disabled or conservative.
- [ ] The fallback path must feel intentional, not broken.
- [ ] Settings must be boring, obvious, and reversible.

## Category 1: Typing Must Feel Untouched

Current score: 100/100.

Native target: the user cannot tell the app is running unless a suggestion is
visible.

### Checklist

- [x] Keyboard event tap runs in microseconds during recent proof.
- [x] Ordinary keys pass through when no suggestion is visible.
- [x] Option-Tab and system shortcuts pass through.
- [x] Streaming model output cancels stale work.
- [x] Long synthetic caret measurement is capped.
- [x] Screenshot capture is off the hot typing path.
- [x] Performance checks default to a recent proof window, not the entire historical log.
- [x] Polling skips when a previous poll is still in flight.
- [x] Focused-text poll summaries now trigger throttle/backoff when p95 is slow.
- [x] Slow focused-text polling hides visible suggestions instead of fighting the user.
- [x] AX value replacement removed fixed 30ms/40ms sleeps from the accept hot path while preserving immediate read-back confirmation.
- [x] A serial off-main focused-text AX reader exists and is tested.
- [x] Focused-text polling must be wired through the serial AX reader instead of reading synchronously in the polling path.
- [x] Typing performance checks treat event-tap latency as the hard guard and report off-main AX poll slowness separately.
- [x] Slow app-specific AX calls should disable suggestions temporarily for that app.
- [x] Slow app-specific AX calls with no focused text context should disable suggestions immediately for that app.
- [x] Single slow focused-text AX calls with context should throttle polling and drop that stale read.
- [x] Diagnostics should distinguish event-tap latency from AX polling latency in the UI.
- [x] Normal typing proof keeps keyboard capture idle until a suggestion is visible.
- [x] A 10-minute disposable TextEdit endurance soak command exists, is self-tested, and has a current live exact-text pass.
- [x] Zero missed or swallowed keys in the latest 10-minute TextEdit typing session.
- [x] Recent text-change polling backs off during active typing while visible suggestions keep the fast active cadence.
- [x] Focused-text AX polling should stay below the warning threshold during long active typing so diagnostics do not show 200ms-class off-main reads.

### Acceptance Bar

- Event tap p95 under 1ms.
- Event tap max under 8ms.
- Focused poll p95 under 40ms in green apps.
- Focused poll p95 under 80ms in yellow apps.
- No slow poll streak while the user is actively typing.
- Zero missed or swallowed keys in a 10-minute typing session.

## Category 2: Visual Placement And Caret Alignment

Current score: 91/100.

Native target: ghost text feels like it belongs to the host text field.

This is the top issue. A suggestion in the wrong spot makes the whole app feel
cheap, even if the model output is good.

### Checklist

- [x] TextEdit has screenshot-backed placement proof.
- [x] Chrome textarea fixture has screenshot-backed placement proof.
- [x] Chrome contenteditable fixture has screenshot-backed placement proof.
- [x] Chrome editor-like fixture has screenshot-backed placement proof.
- [x] Chrome Monaco-like fixture has screenshot-backed placement proof.
- [x] Chrome ProseMirror-like fixture has screenshot-backed placement proof.
- [ ] Default-Chrome real Monaco and ProseMirror need current proof; the latest rerun exposed only browser chrome through AX.
- [x] Codex has at least one screenshot-backed prompt placement proof.
- [x] Invalid caret rects are rejected.
- [x] Stale text-line rects far from the caret are dropped.
- [x] Inline and floating frames clamp vertically to editor bounds.
- [x] Synthetic impossible carets cannot score high confidence.
- [x] Untrusted yellow-profile mirror fallback suppresses low-confidence detached placement.
- [x] Synthetic caret anchors are labeled as synthetic in traces.
- [x] First code pass: inline ghost text now clips near the caret instead of sliding left to stay inside a box.
- [x] First code pass: too-narrow inline frames now suppress the visible suggestion instead of leaving an invisible Tab-capturing ghost.
- [x] Async model and streaming suggestions refresh the focused context before display and suppress if app, field, or text is stale.
- [x] Keyboard capture now starts only after the panel frame is proven usable.
- [x] Trace eval now surfaces panel-frame failures, inline clipping, placement health reasons, and screenshot-file evidence.
- [x] Chrome chat-like no-submit fixture has live screenshot-backed no-submit proof.
- [x] Obsidian has fresh screenshot-backed placement proof.
- [x] Apple Notes title has screenshot-backed placement proof.
- [x] Apple Notes body has screenshot-backed placement proof.
- [x] Apple Notes checklist has screenshot-backed placement proof.
- [x] Claude desktop has same-baseline screenshot-backed one-word no-submit proof.
- [x] Claude Code has a safe terminal-host adapter before live prompt proof.
- [ ] Codex needs screenshot plus verified one-word no-submit accept in one strict trace slice.
- [x] Real Google Docs has an explicit unsupported browser-surface state until proof exists.
- [x] Real Notion has an explicit unsupported browser-surface state until proof exists.
- [x] Browser Slack/Discord chat boxes stay blocked until no-submit proof exists.
- [x] The app should hide inline suggestions when there is less than one useful word of room after the caret.
- [x] The app should prefer suppression over visually lying with untrusted detached mirror placement.
- [x] Screenshot pixel offset detection should be unit-tested before live
  auto-apply.
- [x] Placement should use screenshot-derived correction only after explicit opt-in proof.
- [x] A learned visual offset must expire after app version, screen, or field-shape changes.
- [x] Mirrored or overlapping display frames suppress placement instead of guessing.
- [x] Display layout changes hide visible suggestions and cancel pending requests.
- [x] Visible geometry snapshots hide on window moves, scrolled lines, wrapped-line changes, and field switches.
- [x] Overlay panels declare all-Spaces and fullscreen auxiliary behavior.
- [x] The UI should expose placement confidence in diagnostics without exposing user text.

### Native Placement Rules

- Inline means after the caret. If it is not after the caret, it is not inline.
- Never center a ghost phrase in the field unless that is an explicit mirror mode.
- Never show ghost text over existing typed text.
- Never show ghost text with host-app foreground color unless contrast is proven.
- Never show black text in dark fields.
- Never let a stale suggestion remain after the caret moves to another line.
- Never show a detached whole-window bubble in prompt apps.
- Never treat "inside the editor bounds" as good enough.

### App Placement Matrix

| Surface | Current | Target | Required proof |
| --- | ---: | ---: | --- |
| TextEdit | 92 | 100 | Light/dark screenshots, long-line wrap, two accepts. |
| Chrome textarea | 88 | 100 | Live screenshot, wrap, Tab, full accept. |
| Chrome contenteditable | 86 | 100 | Live screenshot, rich text, Tab, full accept. |
| Chrome editor-like | 84 | 100 | Real CodeMirror or Obsidian proof. |
| Chrome Monaco-like | 93 | 100 | `monaco-real` now has forced-renderer-accessibility proof with screenshot, Tab, and full accept. Default-Chrome proof is pending because normal Chrome exposed only browser chrome in the latest rerun. Still needs production editor variants. |
| Chrome ProseMirror-like | 94 | 100 | `prosemirror-real` now has forced-renderer-accessibility proof with screenshot, Tab, and full accept. Default-Chrome proof is pending because normal Chrome exposed only browser chrome in the latest rerun. Still needs production editor variants. |
| Chrome chat-like | 80 | 100 | Local screenshot-backed no-submit accept proof exists; real chat apps still need proof. |
| Codex | 74 | 100 | Prompt screenshot plus one-word no-submit proof in same slice. |
| Claude Code | 92 | 100 | Proof-only terminal-host adapter has strict screenshot-backed one-word no-submit proof in Terminal; more terminal hosts and prompt layouts still need coverage. |
| Claude desktop | 90 | 100 | Same-baseline screenshot-backed one-word no-submit proof exists; more prompt layouts still need coverage. |
| Notes title | 90 | 100 | More title lengths and variants. |
| Notes body | 90 | 100 | More body lengths and variants. |
| Notes checklist | 90 | 100 | Dedicated checklist proof exists; checked items, long rows, and undo variants still need proof. |
| Obsidian | 90 | 100 | More vault themes, panes, and long-note variants. |

## Category 3: Acceptance Safety

Current score: 94/100.

Native target: accepting a suggestion feels as safe as accepting a system
autocomplete suggestion.

### Checklist

- [x] Tab accepts only while a suggestion is visible.
- [x] Backtick/tilde accepts full visible suggestion.
- [x] Option-Tab passes through.
- [x] Window switching shortcuts pass through.
- [x] Selected text blocks suggestions and acceptance.
- [x] Insertion verification checks whether accepted text landed.
- [x] Failed insertion can suppress the field.
- [x] Post-accept app, focused-text, and field mismatches trace as failed insertions.
- [x] Notes fails closed instead of trusting flaky rich-text insertion.
- [x] Chat-like fixture exists to prove accept does not submit a form.
- [x] Keyboard capture starts after a usable panel is shown, not before.
- [x] Keyboard event tap disablement fails closed and hides the suggestion.
- [x] AX value replacement confirms the edited value without fixed sleeps, then later async verification catches delayed editor drift.
- [x] Chat-like fixture has a live run with screenshot proof.
- [ ] Codex prompt proof must verify one-word accept without submit.
- [x] Claude Code terminal-host proof must verify Tab cannot submit shell input or an agent prompt.
- [x] Esc must always dismiss without changing text.
- [ ] Undo after accept must behave like normal typed text in each supported app.
- [x] Full accept should be disabled by default in any app without proof.
- [x] Full visible accept must exactly match the visible suggestion, and Tab next-word accept must be traced as a visible-prefix accept.

## Category 4: Cross-App Reliability

Current score: 89/100.

Native target: every app has a named stance: green, yellow, diagnostics-only,
or unsupported.

### Checklist

- [x] Compatibility profiles exist.
- [x] Denylist exists for sensitive/unsupported apps.
- [x] Mail is diagnostics-only.
- [x] Atlas is unsupported.
- [x] Chrome local fixtures cover major browser editor shapes.
- [x] Real Monaco and ProseMirror have isolated renderer-accessibility Chrome proof.
- [ ] Real Monaco and ProseMirror need current default-Chrome AX proof with strict visual trace evidence.
- [x] A dedicated app proof matrix now separates screenshot proof, accept proof, and evidence gaps.
- [x] Every profile has an owner note explaining why it is safe.
- [x] Every profile has an evidence row in the proof manifest.
- [x] Every yellow app needs a visible fallback mode.
- [x] Unsupported apps should explain why, not silently fail.
- [x] Chrome-hosted Google Docs, Notion, Slack, and Discord are blocked by a trace-safe surface policy until production proof exists.
- [x] The menu should show current app support status.
- [ ] The app should not attempt broad unknown-app support until green apps feel native.

## Category 5: Native macOS Visual Feel

Current score: 95/100.

Native target: nothing looks like a web widget floating on top of macOS.

### Checklist

- [x] Suggestion panel uses nonactivating panel.
- [x] Floating mirror uses system material.
- [x] Inline text is subdued.
- [x] Settings now uses clearer native sections, checkboxes, button rows, and calmer app/privacy labels.
- [x] Menu bar copy should be short and calm.
- [x] Diagnostics should start with a utility inspector overview, not only a debug dump.
- [x] Onboarding should use system language for Accessibility and Screen Recording.
- [x] Settings needs light, dark, and increased-contrast screenshot QA.
- [x] Diagnostics needs light, dark, and increased-contrast screenshot QA.
- [x] Suggestion overlay renderer needs light, dark, and increased-contrast screenshot QA.
- [ ] Real host-app light/dark document variants need smoke proof.
- [x] Reduce custom visual language unless system controls cannot do the job.
- [x] Use SF/system font behavior everywhere.
- [x] Avoid card-heavy layouts in settings.
- [x] Use a template menu bar icon with a text fallback.
- [x] Use a proper app icon.

### Appearance QA Evidence

- [Settings light](native-visual-qa/settings-light.png)
- [Settings dark](native-visual-qa/settings-dark.png)
- [Settings high-contrast light](native-visual-qa/settings-high-contrast-light.png)
- [Settings high-contrast dark](native-visual-qa/settings-high-contrast-dark.png)
- [Diagnostics light](native-visual-qa/diagnostics-light.png)
- [Diagnostics dark](native-visual-qa/diagnostics-dark.png)
- [Diagnostics high-contrast light](native-visual-qa/diagnostics-high-contrast-light.png)
- [Diagnostics high-contrast dark](native-visual-qa/diagnostics-high-contrast-dark.png)
- [Suggestion overlay light](native-visual-qa/suggestion-overlay-light.png)
- [Suggestion overlay dark](native-visual-qa/suggestion-overlay-dark.png)
- [Suggestion overlay high-contrast light](native-visual-qa/suggestion-overlay-high-contrast-light.png)
- [Suggestion overlay high-contrast dark](native-visual-qa/suggestion-overlay-high-contrast-dark.png)

## Category 6: Privacy And Permissions Trust

Current score: 100/100.

Native target: the app feels more private than cloud writing tools.

### Checklist

- [x] Local-first runtime.
- [x] No user-managed model server.
- [x] Raw diagnostics redact text by default.
- [x] Screenshots are opt-in.
- [x] Password/token/API-key fields are suppressed before reading text.
- [x] Secure text fields are suppressed.
- [x] Recent word memory is scoped by app so vocabulary learned in one app does not bleed into another.
- [x] Permission copy should explain exactly what is read and why.
- [x] A one-click privacy status panel should show what is currently enabled.
- [x] Raw tracing should auto-expire after a session.
- [x] Screenshot tracing should auto-expire after a session.
- [x] Deleting local privacy logs should disable raw text and screenshot capture where possible.
- [x] Exported debug bundles should have a privacy checklist.
- [x] Private beta feedback should never request raw text by default.

## Category 7: Suggestion Quality

Current score: 95/100.

Native target: suggestions feel like a continuation of the user's sentence, not
like an assistant trying to talk.

### Checklist

- [x] Visible completions are capped.
- [x] Reasoning/thinking markers are removed.
- [x] Prompt labels and instruction echoes are suppressed.
- [x] Assistant meta text is suppressed.
- [x] Repeated unaccepted suggestions are suppressed.
- [x] Fast word completions also obey repeated-miss suppression.
- [x] Word completion can use recent accepted words scoped to the current app.
- [x] Word completion waits for 3+ typed letters in trigger, activation, and fast ranking paths.
- [x] Global word completion defaults no longer include Codex, Transcripted, autocomplete, trace, diagnostics, or other lab-specific words.
- [x] Dogfood prompt guidance no longer triggers from loose substrings like `table`, `stable`, `model`, or `test`.
- [x] Assistant-y prefixes like "as an AI", "happy to", "you could", and "would you like" are suppressed before display.
- [x] Word-completion mode rejects unrelated whole-word completions.
- [x] Accepted-kept display thresholds are stricter for prompt/chat and sentence-like prose profiles after enough evidence.
- [x] Model should prefer suffixes over phrase restarts.
- [x] Suggestions should not duplicate the user's visible text.
- [x] Suggestions should be less eager after repeated typed-over misses.
- [x] Different app modes should have different suggestion aggressiveness.
- [x] User should be able to choose quiet, normal, or eager suggestions.
- [x] Dogfood agent prompts should avoid generic productivity filler.

## Category 8: Failure Restraint

Current score: 100/100.

Native target: when the app is unsure, the user feels nothing.

### Checklist

- [x] Sensitive fields suppress.
- [x] Selected text suppresses.
- [x] Detached suggestions are disabled in prompt apps.
- [x] Placement suppression logs exist.
- [x] Stale model requests cancel.
- [x] Slow AX polling can temporarily suppress visible suggestions and pause polling.
- [x] Single slow AX reads can throttle focused-text polling before a stale suggestion is shown.
- [x] Stale app, field, prompt target, or text suppresses async suggestions before display.
- [x] Low placement confidence should suppress inline mode.
- [x] Prompt apps should require no-submit proof before full accept.
- [x] Prompt/no-submit profiles should block full accept, multiword accepted
  text, non-visible accepted text, and newline/tab/control accepted text before
  insertion.
- [x] Low accepted-kept probability should suppress more aggressively in high-cost profiles after enough local samples.
- [x] Unsupported apps should not appear broken.
- [x] The app should never leave a ghost after focus moves.
- [x] The app should hide after repeated placement uncertainty in the same field.
- [x] Focus/protected-field and selected-text accept blocks replay the original key instead of consuming normal typing.
- [x] Unsafe accept failures drop and diagnose captured keys instead of replaying an unsafe accept.
- [x] Diagnostics separates key-capture drops/replays from unrelated AX warning noise.

## Category 9: User Control

Current score: 100/100.

Native target: a user can understand and control the app in 20 seconds.

### Checklist

- [x] Global pause exists.
- [x] Per-app enable/disable exists.
- [x] Current app state appears in diagnostics/menu.
- [x] Full-accept toggle exists.
- [x] Settings uses clearer controls for suggestions, current app, tracing, raw text capture, screenshot capture, and local log deletion.
- [x] Settings and menu copy now expose green/yellow/diagnostics-only/unsupported app stance.
- [x] Shortcut editing should be first-class.
- [x] Per-app mode should be visible: inline, mirror, command-only, disabled.
- [x] User should be able to force mirror mode for an app.
- [x] User should be able to disable suggestions for current field/session.
- [x] User should see why a suggestion is hidden without reading logs.
- [x] A "make this app safe" flow should guide proof collection.

## Category 10: Onboarding And Setup

Current score: 100/100.

Native target: setup feels like a normal Mac utility, not a developer tool.

### Checklist

- [x] Settings shows model readiness.
- [x] App can reveal expected model folder.
- [x] Accessibility settings link exists.
- [x] Settings now explains current app support, local diagnostics, and raw/screenshot capture states more plainly.
- [x] First run should explain Accessibility in one short paragraph.
- [x] Screen Recording should be explained only when screenshot proof is enabled.
- [x] Local model install/repair should be fully in-app.
- [x] The app should start disabled until the user enables a test app.
- [x] Model install should be cancellable from Settings.
- [x] Failed model installs should leave a retry path.
- [x] Offline/model-host install errors should have plainer recovery copy.
- [x] First success should happen in TextEdit.
- [x] App proof should explain the exact disposable-text steps before it starts.
- [x] App proof should not start while suggestions are disabled for that app.
- [x] App proof should show the exact smoke command when a proof lane exists.
- [x] App proof should copy the runnable smoke command without label text.
- [x] App proof should run the safe Chrome local fixture proof from inside the app.
- [x] App proof should run and verify the TextEdit smoke pass from inside the app.
- [x] Onboarding should never ask users to test in private notes first.

## Category 11: Evidence And QA Loop

Current score: 99/100.

Native target: every claim has proof.

### Checklist

- [x] `swift test` covers core behavior.
- [x] Manual smoke recorder exists.
- [x] Manual smoke status separates insertion proof from screenshot proof.
- [x] Strict manual smoke status fails on pending screenshot proof, not only missing insertion proof.
- [x] Visual placement evidence checker exists.
- [x] Trace eval has strict visual evidence gates.
- [x] Trace eval now verifies required screenshot files exist and are non-empty.
- [x] App-target settings state tests exist.
- [x] App proof matrix separates product confidence from proof confidence.
- [x] All requested score targets are executable with `script/check_score_targets.sh`.
- [x] The requested 10-pass score loop exists as `script/scorecard_goal_loop.sh --iterations 10`.
- [x] The 10-minute typing endurance command is covered by a dry-run self-test.
- [x] Beta readiness fails when proof rows are missing.
- [ ] All pending screenshot rows need real proof.
- [x] Performance proof defaults to a fresh bounded log slice.
- [x] Chrome chat-like no-submit proof is screenshot-backed.
- [x] The checklist should be updated after every product pass.
- [ ] Each beta session should produce a short report row.

## Priority Work Plan

### Pass 1: Stop Wrong-Spot Text

- [x] Add this Apple-native checklist.
- [x] Change inline frame math so ghost text clips instead of sliding left before the caret.
- [x] Add a guard to hide inline mode when useful width after caret is too small.
- [x] Add trace/diagnostic evidence for unusable inline panel frames.
- [x] Refresh focused context before showing async suggestions.
- [x] Start keyboard capture only after panel display succeeds.
- [x] Run screenshot proof for Chrome chat-like fixture.
- [ ] Run screenshot proof for Codex with one-word no-submit accept.

### Pass 2: Make Typing Untouchable

- [x] Move focused-text polling off the main actor or isolate slow AX calls.
- [x] Add adaptive poll backoff after slow p95 or overlapping-poll summaries.
- [x] Add slow-poll suppression after repeated spikes.
- [x] Add immediate app cooldown for slow focused-text reads with no context.
- [x] Add immediate focused-text polling throttle for single slow AX reads with context.
- [x] Make performance check use fresh log windows by default.
- [x] Add a 10-minute typing soak script.

### Pass 3: Make App Stances Honest

- [ ] Green apps: TextEdit, Chrome textarea, Chrome contenteditable.
- [ ] Yellow apps: Codex, Claude desktop, Obsidian, Notes.
- [ ] Red/disabled apps: Mail compose, Atlas, terminals unless explicitly scoped.
- [x] Add per-app support mode to settings.
- [x] Add "why disabled" text.

### Pass 4: Add Native Fallback Surface

- [ ] Add command/context panel for uncertain apps.
- [ ] Selected text or current field context feeds the panel.
- [x] Expose copy-only fallback status for non-sensitive diagnostics-only or untrusted-placement cases.
- [ ] One-click insert or copy.
- [ ] Never slows normal typing.
- [ ] This becomes the universal path when inline is unsafe.

### Pass 5: Native Polish

- [x] Settings pass using clearer native sections and checkbox controls.
- [x] Menu bar copy pass.
- [ ] Privacy status panel.
- [ ] First-run setup.
- [x] App icon/menu icon polish.
- [x] Settings light, dark, increased contrast visual QA.
- [x] Diagnostics light, dark, increased contrast visual QA.
- [x] Suggestion overlay renderer light, dark, increased contrast visual QA.
- [ ] Real host-app light/dark document variants.

## References

- Apple Human Interface Guidelines: https://developer.apple.com/design/human-interface-guidelines/
- Apple HIG Typography: https://developer.apple.com/design/human-interface-guidelines/typography
- Apple HIG Color: https://developer.apple.com/design/human-interface-guidelines/color
- Apple HIG Machine Learning: https://developer.apple.com/design/human-interface-guidelines/machine-learning/
- Current scorecard: `docs/product/deep-dive-scorecard-2026-05-06.md`
- Compatibility matrix: `docs/product/compatibility-matrix.md`
- Automated real-app smoke: `docs/product/automated-real-app-smoke.md`
