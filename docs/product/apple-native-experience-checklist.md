# Apple-Native Experience Checklist

Created: 2026-05-07

This is the working checklist for making Autocomplete Lab feel natural,
intuitive, fast, quiet, and almost native to macOS.

The product bar is not "AI appears everywhere." The bar is:

> Typing feels completely normal. Help appears only when it is useful, aligned,
> reversible, and calm.

## Current Executive Score

Overall Apple-native feel: 82/100.

This app has real engineering depth now. It is not a toy. It has local model
runtime support, strong privacy defaults, app compatibility profiles, insertion
verification, screenshot tracing, and a growing proof harness.

It is not yet Apple-native. The latest pass made the app more disciplined:
slow focused-text polling now throttles, stale async suggestions re-check the
focused field before showing, keyboard capture fails closed when macOS disables
the event tap, AX value replacement removed fixed hot-path sleeps, fast word
completion honors repeated-miss suppression, recent-word memory is scoped per
app, focused-text AX reads now run through a serial off-main reader,
raw/screenshot debug capture now expires from Settings, lab/debug
vocabulary was removed from the global word list, Chrome chat-like no-submit
now has screenshot-backed proof, prompt-app full accept is disabled until
separate full-accept no-submit proof exists, app-specific slow AX reads cool
down without blocking typing, TextEdit now has a live typing soak where event
tap p95 stayed at 35us, app support status is visible in Settings and the menu, Diagnostics
separates key-capture health from AX-poll health, and Settings now reads more
like a Mac utility.

The largest miss is still visual placement proof in real apps. Ghost text can
still be unproven in Notes, Obsidian, Claude Code, Claude desktop, and real
browser editors. A native-feeling Mac utility must fail quietly when it is
unsure. Wrong-place text is worse than no suggestion.

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
| Typing must feel untouched | 15 | 93 | 100 | Live TextEdit soak proves event tap p95 max 35us, p99 max 95us, max 161us over 600 samples with zero slow markers and zero tap disable events. A 10-minute endurance soak command now exists and is self-tested. Slow AX polling is off the hot key path but still warned in the same run, with p95 max 59ms and max 209ms, so worst-app AX proof remains open. |
| Visual placement and caret alignment | 18 | 64 | 100 | Stale async suggestions refresh focused geometry before display, unusable panels suppress before key capture, and Chrome chat-like now has proof. Notes, Obsidian, Claude Code, and Claude desktop are still the blocker. |
| Acceptance safety | 10 | 90 | 100 | Tab capture is gated behind an actually shown panel, insertion is verified, the event tap fails closed, Chrome chat-like proved Tab/full accept without submit, and prompt-app full accept is disabled until separate full-accept no-submit proof exists. Prompt-app one-word no-submit proof is still incomplete. |
| Cross-app reliability | 10 | 70 | 100 | The proof matrix now has 8 screenshot rows and the app exposes green/yellow/diagnostics-only/unsupported status. Many real apps are still yellow or pending screenshot proof. |
| Native macOS visual feel | 8 | 80 | 100 | Settings moved toward native sections, checkboxes, clearer privacy/app controls, support status, "why hidden" copy, and calmer menu copy. Diagnostics and onboarding still need polish. |
| Privacy and permissions trust | 9 | 93 | 100 | Local-first and redaction are strong, recent-word memory no longer crosses app boundaries, and raw/screenshot debug capture now expires when enabled from the app UI. Stronger plain-language warnings remain open. |
| Suggestion quality | 8 | 87 | 100 | Output is bounded and filtered, repeated misses apply to fast word completion, learned word completion is app-scoped, dogfood prompts are stricter, unsafe prompt actions are suppressed, and assistant-y output filters are stronger. Raw-content quality audits remain opt-in. |
| Failure restraint | 8 | 86 | 100 | Slow polling can hide suggestions, repeated slow app-specific AX reads cool down, stale geometry suppresses display, event-tap disablement fails closed, prompt full accept requires proof, and unsupported apps now explain their stance. Low-confidence inline mode still needs stricter real-app gating. |
| User control | 6 | 88 | 100 | Settings now exposes pause, app blocking, support status, privacy diagnostics, temporary raw/screenshot capture, local log deletion, shortcut state, and why the last suggestion was hidden. Per-app modes remain open. |
| Onboarding and setup | 4 | 73 | 100 | Settings is clearer, but first-run permission flow and model install/repair are still not one calm native flow. |
| Evidence and QA loop | 4 | 98 | 100 | Tests now include app-target settings state, privacy expiry, support status, serial AX reader, focused AX-health cooldown, trace eval, strict manual-smoke status, executable score-target gates, a 10-iteration score loop, a self-tested 10-minute typing endurance command, and 8 screenshot proofs. Full real-app screenshot proof is still missing. |

Weighted score: 82/100.

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

Current score: 93/100.

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
- [x] Diagnostics should distinguish event-tap latency from AX polling latency in the UI.
- [x] Live TextEdit soak proves the event-tap key path stays in microseconds while typing.
- [x] A 10-minute disposable TextEdit endurance soak command exists and is self-tested.
- [ ] Focused-text AX polling should stay below the warning threshold during long active typing so diagnostics do not show 200ms-class off-main reads.

### Acceptance Bar

- Event tap p95 under 1ms.
- Event tap max under 8ms.
- Focused poll p95 under 40ms in green apps.
- Focused poll p95 under 80ms in yellow apps.
- No slow poll streak while the user is actively typing.
- Zero missed or swallowed keys in a 10-minute typing session.

## Category 2: Visual Placement And Caret Alignment

Current score: 64/100.

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
- [x] Codex has at least one screenshot-backed prompt placement proof.
- [x] Invalid caret rects are rejected.
- [x] Stale text-line rects far from the caret are dropped.
- [x] Inline and floating frames clamp vertically to editor bounds.
- [x] Synthetic impossible carets cannot score high confidence.
- [x] Synthetic caret anchors are labeled as synthetic in traces.
- [x] First code pass: inline ghost text now clips near the caret instead of sliding left to stay inside a box.
- [x] First code pass: too-narrow inline frames now suppress the visible suggestion instead of leaving an invisible Tab-capturing ghost.
- [x] Async model and streaming suggestions refresh the focused context before display and suppress if app, field, or text is stale.
- [x] Keyboard capture now starts only after the panel frame is proven usable.
- [x] Trace eval now surfaces panel-frame failures, inline clipping, placement health reasons, and screenshot-file evidence.
- [x] Chrome chat-like no-submit fixture has live screenshot-backed no-submit proof.
- [ ] Obsidian needs fresh screenshot-backed placement proof.
- [ ] Apple Notes title needs screenshot-backed proof.
- [ ] Apple Notes body needs screenshot-backed proof.
- [ ] Apple Notes checklist needs screenshot-backed proof.
- [ ] Claude Code needs safe live prompt proof.
- [ ] Claude desktop needs fresh screenshot-backed proof.
- [ ] Codex needs screenshot plus verified one-word no-submit accept in one strict trace slice.
- [ ] Real Google Docs needs a distinct proof path or an explicit unsupported state.
- [ ] Real Notion needs a distinct proof path or an explicit unsupported state.
- [ ] Real Slack/Discord chat boxes need no-submit proof before enablement.
- [ ] The app should hide inline suggestions when there is less than one useful word of room after the caret.
- [ ] The app should prefer mirror mode over visually lying about inline placement.
- [ ] Placement should use screenshot-derived correction only after explicit opt-in proof.
- [ ] A learned visual offset must expire after app version, screen, or field-shape changes.
- [ ] The UI should expose placement confidence in diagnostics without exposing user text.

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
| Chrome Monaco-like | 78 | 100 | Real Monaco proof, not only local fixture. |
| Chrome ProseMirror-like | 84 | 100 | Real ProseMirror/Notion proof. |
| Chrome chat-like | 80 | 100 | Local screenshot-backed no-submit accept proof exists; real chat apps still need proof. |
| Codex | 74 | 100 | Prompt screenshot plus one-word no-submit proof in same slice. |
| Claude Code | 35 | 100 | Safe prompt proof with one-word accept. |
| Claude desktop | 72 | 100 | Fresh screenshot-backed proof. |
| Notes title | 50 | 100 | Dedicated title proof. |
| Notes body | 55 | 100 | Dedicated body proof. |
| Notes checklist | 45 | 100 | Dedicated checklist proof. |
| Obsidian | 66 | 100 | Real vault note screenshot and accept proof. |

## Category 3: Acceptance Safety

Current score: 90/100.

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
- [x] Notes fails closed instead of trusting flaky rich-text insertion.
- [x] Chat-like fixture exists to prove accept does not submit a form.
- [x] Keyboard capture starts after a usable panel is shown, not before.
- [x] Keyboard event tap disablement fails closed and hides the suggestion.
- [x] AX value replacement confirms the edited value without fixed sleeps, then later async verification catches delayed editor drift.
- [x] Chat-like fixture has a live run with screenshot proof.
- [ ] Codex/Claude prompt proof must verify one-word accept without submit.
- [ ] Esc must always dismiss without changing text.
- [ ] Undo after accept must behave like normal typed text in each supported app.
- [x] Full accept should be disabled by default in any app without proof.
- [ ] The visible suggestion must exactly match the accepted text.

## Category 4: Cross-App Reliability

Current score: 70/100.

Native target: every app has a named stance: green, yellow, diagnostics-only,
or unsupported.

### Checklist

- [x] Compatibility profiles exist.
- [x] Denylist exists for sensitive/unsupported apps.
- [x] Mail is diagnostics-only.
- [x] Atlas is unsupported.
- [x] Chrome local fixtures cover major browser editor shapes.
- [x] A dedicated app proof matrix now separates screenshot proof, accept proof, and evidence gaps.
- [ ] Every profile needs an owner note explaining why it is safe.
- [ ] Every profile needs a screenshot evidence row.
- [x] Every yellow app needs a visible fallback mode.
- [x] Unsupported apps should explain why, not silently fail.
- [x] The menu should show current app support status.
- [ ] The app should not attempt broad unknown-app support until green apps feel native.

## Category 5: Native macOS Visual Feel

Current score: 80/100.

Native target: nothing looks like a web widget floating on top of macOS.

### Checklist

- [x] Suggestion panel uses nonactivating panel.
- [x] Floating mirror uses system material.
- [x] Inline text is subdued.
- [x] Settings now uses clearer native sections, checkboxes, button rows, and calmer app/privacy labels.
- [x] Menu bar copy should be short and calm.
- [ ] Diagnostics should look like a utility inspector, not a debug dump.
- [ ] Onboarding should use system language for Accessibility and Screen Recording.
- [ ] Dark Mode and increased contrast need visual QA.
- [ ] Reduce custom visual language unless system controls cannot do the job.
- [ ] Use SF/system font behavior everywhere.
- [ ] Avoid card-heavy layouts in settings.
- [ ] Use a proper app icon and menu bar icon variants.

## Category 6: Privacy And Permissions Trust

Current score: 93/100.

Native target: the app feels more private than cloud writing tools.

### Checklist

- [x] Local-first runtime.
- [x] No user-managed model server.
- [x] Raw diagnostics redact text by default.
- [x] Screenshots are opt-in.
- [x] Password/token/API-key fields are suppressed before reading text.
- [x] Secure text fields are suppressed.
- [x] Recent word memory is scoped by app so vocabulary learned in one app does not bleed into another.
- [ ] Permission copy should explain exactly what is read and why.
- [ ] A one-click privacy status panel should show what is currently enabled.
- [x] Raw tracing should auto-expire after a session.
- [x] Screenshot tracing should auto-expire after a session.
- [x] Deleting local privacy logs should disable raw text and screenshot capture where possible.
- [ ] Exported debug bundles should have a privacy checklist.
- [ ] Private beta feedback should never request raw text by default.

## Category 7: Suggestion Quality

Current score: 87/100.

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
- [x] Global word completion defaults no longer include Codex, Transcripted, autocomplete, trace, diagnostics, or other lab-specific words.
- [x] Dogfood prompt guidance no longer triggers from loose substrings like `table`, `stable`, `model`, or `test`.
- [x] Assistant-y prefixes like "as an AI", "happy to", "you could", and "would you like" are suppressed before display.
- [x] Word-completion mode rejects unrelated whole-word completions.
- [ ] Model should prefer suffixes over phrase restarts.
- [ ] Suggestions should not duplicate the user's visible text.
- [ ] Suggestions should be less eager after repeated typed-over misses.
- [ ] Different app modes should have different suggestion aggressiveness.
- [ ] User should be able to choose quiet, normal, or eager suggestions.
- [ ] Dogfood agent prompts should avoid generic productivity filler.

## Category 8: Failure Restraint

Current score: 86/100.

Native target: when the app is unsure, the user feels nothing.

### Checklist

- [x] Sensitive fields suppress.
- [x] Selected text suppresses.
- [x] Detached suggestions are disabled in prompt apps.
- [x] Placement suppression logs exist.
- [x] Stale model requests cancel.
- [x] Slow AX polling can temporarily suppress visible suggestions and pause polling.
- [x] Stale app, field, prompt target, or text suppresses async suggestions before display.
- [ ] Low placement confidence should suppress inline mode.
- [x] Prompt apps should require no-submit proof before full accept.
- [ ] Unsupported apps should not appear broken.
- [ ] The app should never leave a ghost after focus moves.
- [ ] The app should hide after repeated placement uncertainty in the same field.

## Category 9: User Control

Current score: 88/100.

Native target: a user can understand and control the app in 20 seconds.

### Checklist

- [x] Global pause exists.
- [x] Per-app enable/disable exists.
- [x] Current app state appears in diagnostics/menu.
- [x] Full-accept toggle exists.
- [x] Settings uses clearer controls for suggestions, current app, tracing, raw text capture, screenshot capture, and local log deletion.
- [x] Settings and menu copy now expose green/yellow/diagnostics-only/unsupported app stance.
- [ ] Shortcut editing should be first-class.
- [ ] Per-app mode should be visible: inline, mirror, command-only, disabled.
- [ ] User should be able to force mirror mode for an app.
- [ ] User should be able to disable suggestions for current field/session.
- [x] User should see why a suggestion is hidden without reading logs.
- [ ] A "make this app safe" flow should guide proof collection.

## Category 10: Onboarding And Setup

Current score: 73/100.

Native target: setup feels like a normal Mac utility, not a developer tool.

### Checklist

- [x] Settings shows model readiness.
- [x] App can reveal expected model folder.
- [x] Accessibility settings link exists.
- [x] Settings now explains current app support, local diagnostics, and raw/screenshot capture states more plainly.
- [ ] First run should explain Accessibility in one short paragraph.
- [ ] Screen Recording should be explained only when screenshot proof is enabled.
- [ ] Local model install/repair should be fully in-app.
- [ ] The app should start disabled until the user enables a test app.
- [ ] First success should happen in TextEdit.
- [ ] Onboarding should never ask users to test in private notes first.

## Category 11: Evidence And QA Loop

Current score: 98/100.

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
- [x] Make performance check use fresh log windows by default.
- [x] Add a 10-minute typing soak script.

### Pass 3: Make App Stances Honest

- [ ] Green apps: TextEdit, Chrome textarea, Chrome contenteditable.
- [ ] Yellow apps: Codex, Claude desktop, Obsidian, Notes.
- [ ] Red/disabled apps: Mail compose, Atlas diagnostics, terminals unless explicitly scoped.
- [x] Add per-app support mode to settings.
- [x] Add "why disabled" text.

### Pass 4: Add Native Fallback Surface

- [ ] Add command/context panel for uncertain apps.
- [ ] Selected text or current field context feeds the panel.
- [ ] One-click insert or copy.
- [ ] Never slows normal typing.
- [ ] This becomes the universal path when inline is unsafe.

### Pass 5: Native Polish

- [x] Settings pass using clearer native sections and checkbox controls.
- [x] Menu bar copy pass.
- [ ] Privacy status panel.
- [ ] First-run setup.
- [ ] App icon/menu icon polish.
- [ ] Light, dark, increased contrast visual QA.

## References

- Apple Human Interface Guidelines: https://developer.apple.com/design/human-interface-guidelines/
- Apple HIG Typography: https://developer.apple.com/design/human-interface-guidelines/typography
- Apple HIG Color: https://developer.apple.com/design/human-interface-guidelines/color
- Apple HIG Machine Learning: https://developer.apple.com/design/human-interface-guidelines/machine-learning/
- Current scorecard: `docs/product/deep-dive-scorecard-2026-05-06.md`
- Compatibility matrix: `docs/product/compatibility-matrix.md`
- Automated real-app smoke: `docs/product/automated-real-app-smoke.md`
