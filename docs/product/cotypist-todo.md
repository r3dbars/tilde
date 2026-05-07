# Autocomplete Lab Product And Code Todo

This is the working backlog for turning the current lab into a calm Mac typing
assistant.

Source input: `/Users/redbars/Downloads/deep-research-report (1).md`.

The report's main point is simple: the product is not won by having the biggest
model. It is won by interruption policy. The app should finish the boring next
word or phrase, stay quiet when unsure, never make `Tab` feel dangerous, and
never make the user wonder where their typing went.

## Status Key

- `[x] Done`: implemented or documented in this repo.
- `[~] Partly done`: real work exists, but there is still a clear gap.
- `[ ] Queued`: not built yet.

## Current Code Map

- App shell: `Sources/AutocompleteLabApp/App/AppDelegate.swift`
- Accessibility and focused-field plumbing: `Sources/AutocompleteLabApp/Mac/AccessibilityClient.swift`
- Key capture: `Sources/AutocompleteLabApp/Mac/KeyboardEventTap.swift`
- Insertion: `Sources/AutocompleteLabApp/Mac/InsertionEngine.swift`
- Suggestion panel: `Sources/AutocompleteLabApp/UI/SuggestionPanelController.swift`
- Settings: `Sources/AutocompleteLabApp/UI/SettingsWindowController.swift`
- Diagnostics: `Sources/AutocompleteLabApp/UI/DiagnosticsWindowController.swift`
- App-owned runtime factory: `Sources/AutocompleteLabApp/Runtime/AppModelRuntimeFactory.swift`
- MLX runtime: `Sources/AutocompleteLabApp/Runtime/MLXModelRuntime.swift`
- Supported-app profiles: `Sources/AutocompleteLabCore/Configuration/CompatibilityProfile.swift`
- Local model policy: `Sources/AutocompleteLabCore/Configuration/ModelPolicy.swift`
- Activation/silence rules: `Sources/AutocompleteLabCore/Session/CompletionActivationPolicy.swift`
- Trigger timing: `Sources/AutocompleteLabCore/Session/SuggestionTriggerPolicy.swift`
- Request invalidation: `Sources/AutocompleteLabCore/Session/SuggestionRequestGate.swift`
- Keyboard actions: `Sources/AutocompleteLabCore/Session/KeyboardAction.swift`
- Suggestion state: `Sources/AutocompleteLabCore/Session/SuggestionSession.swift`
- Prompt shape: `Sources/AutocompleteLabCore/Engine/CompletionPromptBuilder.swift`
- Output cleanup: `Sources/AutocompleteLabCore/Engine/CompletionOutputCleaner.swift`
- Trace analysis: `Sources/AutocompleteLabCore/Tracing/AutocompleteTraceAnalyzer.swift`

## Product Defaults

- [x] Default to next-word acceptance on `Tab`.
  - Code: `KeyboardActionRouter` maps plain `Tab` to `acceptNextWord`.
  - Code: `SuggestionSession.commitNextWordAcceptance` leaves the rest visible.
  - Why: the report says long suggestions are usually only right for the first word or two.

- [x] Put full visible accept on backtick/tilde, not `Tab`.
  - Code: `KeyboardActionRouter` maps backtick to `acceptAllVisible`.
  - Keep this default. It protects normal desktop typing better than full-accept-on-`Tab`.

- [x] Give users literal-tab passthrough.
  - Code: `KeyboardActionRouter` maps `Option+Tab` to `passThrough`.
  - Keep this visible in docs and setup because `Tab` is a trust issue.

- [x] Let `Esc` dismiss the current suggestion.
  - Code: `KeyboardActionRouter` maps `Esc` to `dismiss`.

- [x] Let `Esc` snooze the current field until blur.
  - Code map: compatibility profiles set `suppressesUntilBlurAfterEscape`.
  - Product rule: if the user said no, do not immediately ask again.

- [x] Make continued typing a normal rejection path.
  - Code map: trace events include `suggestionHidden`, `suggestionTypedOver`, and typed-through outcomes.
  - Product rule: rejecting a suggestion should feel like doing nothing.

- [x] Keep suggestions short.
  - Code: `CompletionSuggestion` caps visible text.
  - Code: `CompletionModelPolicy` has `maxVisibleWords`.
  - Code: `CompletionLengthConfiguration` supports local length trials through environment overrides.

- [x] Tighten the default visible-word cap from lab mode to daily-use mode.
  - Code: `CompletionModelPolicy.defaultVisibleWords` is `4`.
  - Code: `CompletionModelPolicy.maximumVisibleWords` is `7` for explicit local trials.
  - Report target: default `1-4` words, soft cap around `7` only when confidence is very high.
  - Keep `AUTOCOMPLETE_LAB_VISIBLE_WORDS` for model trials, not normal daily use.

- [x] Keep reasoning off.
  - Code: `CompletionModelPolicy.mvp.reasoningEnabled` is `false`.
  - Code: `CompletionOutputCleaner` strips `<think>` output.

- [x] Make "routine text, not ideas" an explicit product rule in prompts.
  - Code: `CompletionPromptBuilder` now asks for boring, likely connective text.
  - Code: it explicitly avoids brainstorming, rewriting, new topics, and the user's bigger thought.
  - Tests assert the prompt keeps autocomplete small instead of acting like chat.

## Silence And Trigger Policy

- [x] Suppress suggestions in secure fields.
  - Code: `CompletionActivationPolicy` blocks `secureField`.
  - Product rule: privacy beats usefulness every time.

- [x] Suppress suggestions when the field was snoozed.
  - Code: `CompletionActivationPolicy` blocks `suppressedField`.

- [x] Suppress suggestions with too little context unless word completion is safe.
  - Code: `CompletionActivationPolicy` blocks `tooLittleContext`.
  - Code: word completion can still run after a safe partial word.

- [x] Suppress middle-of-line phrase continuation.
  - Code: `CompletionActivationPolicy` blocks `middleOfLine`.
  - Why: mid-line editing is where autocomplete feels most intrusive.

- [x] Suppress unfinished-word phrase continuation.
  - Code: `CompletionActivationPolicy` blocks `unfinishedWord`.
  - Code: word-completion mode handles actual word suffixes.

- [x] Trigger after natural boundaries or a short pause.
  - Code: `SuggestionTriggerPolicy` requests after whitespace, punctuation, a pause, or eligible word-completion changes.

- [x] Tune trigger delays for real typing, not demo speed.
  - Code: the app-level trigger now waits for a small pause/boundary instead of firing phrase requests on every character.
  - Code: deletion now stays silent instead of immediately requesting another phrase.
  - Report target: fast enough to disappear, but not flashing after every character.
  - Queued eval: compare accept rate, typed-over rate, ignored rate, and p95 latency before/after.

- [x] Cancel stale requests when typing continues.
  - Code: `SuggestionRequestGate` uses generation tickets.
  - Product rule: old model output must not pop in after the user moved on.

- [~] Add stronger "typing fast, stay silent" behavior.
  - Done: request generation invalidation exists.
  - Queued code: add typing-speed or burst detection before issuing phrase requests.
  - Likely home: `SuggestionTriggerPolicy` or a small policy beside it.
  - Queued tests: burst typing should skip phrase requests but still allow safe word completion.

- [~] Add search-box, URL-field, form-field, and short-chat suppression.
  - Report says these are high-annoyance zones.
  - Done: `AccessibilityClient` collects title/description/placeholder/help purpose hints.
  - Done: `AppDelegate` suppresses search fields and address/URL-like fields before requests.
  - Queued: form-field and short-chat suppression still need stronger context heuristics.
  - Product default: off unless the app/profile explicitly opts in.

- [ ] Add per-domain controls for browser apps.
  - Report calls out per-app and per-domain controls.
  - Likely home: Chrome/Safari adapter layer plus settings persistence.
  - MVP version: domain allowlist/blocklist for browser text fields.
  - Do not store typed page content for this.

## Supported Apps And Compatibility

- [x] Keep TextEdit as the green reference target.
  - Code: `CompatibilityProfileStore.mvp` has `com.apple.TextEdit`.
  - Docs: `docs/product/compatibility-matrix.md`.
  - Proof: recorded manual smoke pass.

- [x] Support Notes with key-event insertion.
  - Code: Notes profile uses `keyEvents`.
  - Reason: Notes can report AX selected-text insertion success without moving the caret.

- [x] Support Obsidian carefully.
  - Code: Obsidian profile uses `floatingMirror`, `axThenKeyEvents`, and `stableBounds`.
  - Code: detached suggestions are disabled.
  - Product rule: no whole-editor floating guesses when caret bounds are missing.

- [x] Support Chrome local textarea fields.
  - Code: Chrome profile uses `floatingMirror` and `axValueReplacement`.
  - Docs: compatibility matrix says local textarea passed.

- [~] Finish Codex dogfood support.
  - Done: Codex profile exists with inline-adjacent render and key-event insertion.
  - Gap: compatibility matrix says manual smoke proof is pending.
  - Queued: run Codex dogfood smoke and record it in `docs/product/manual-smoke-runs.md`.
  - Queued: require Codex proof in `script/manual_smoke_status.sh` only after the pass is real.

- [~] Keep Mail diagnostics-only until insertion is safe.
  - Done: Mail profile is disabled and marked sensitive.
  - Queued: build a safe compose adapter only after AX value, selected range, and insertion verification are proven.
  - Stop rule: do not enable Mail if the compose body cannot prove accepted text landed.

- [ ] Add Safari support after Chrome is stable.
  - Report mentions Chrome and Safari as common writing surfaces.
  - Likely home: new `CompatibilityProfile` entry plus manual smoke checklist.
  - Proof needed: textarea, contenteditable, Gmail/Google Docs if AX exposes stable fields.

- [ ] Add Slack/Teams/WhatsApp/Messages only as explicit opt-in targets.
  - Report says short chat messages can get annoying fast.
  - Product default: unsupported or disabled until a user chooses the app.
  - Required behavior: stronger minimum context, quieter trigger delay, instant snooze.

- [x] Denylist terminals and password managers.
  - Code: `CompatibilityProfileStore.defaultDenylist`.
  - Current denylist includes Terminal, iTerm, Keychain Access, and 1Password bundle IDs.

- [ ] Expand denylist for developer tools and raw-control apps.
  - Add common code editors unless the user opts in.
  - Candidates: Xcode, VS Code, Cursor, Windsurf, JetBrains IDEs.
  - Reason: `Tab` already has strong meaning there, and code autocomplete is a different product.

## Rendering And Placement

- [x] Support inline-adjacent and floating mirror render modes.
  - Code: `SuggestionRenderMode.inlineAdjacent` and `floatingMirror`.
  - Code: app UI renders through `SuggestionPanelController`.

- [x] Use floating mirror when inline bounds are unstable.
  - Code: profiles choose render mode and fallback render mode.

- [x] Avoid detached suggestions where they look wrong.
  - Code: `allowsDetachedSuggestions` exists per profile.
  - Code: Obsidian and Codex profiles disable detached suggestions.

- [~] Move toward real ghost text where it is safe.
  - Current app: floating/adjacent panel exists.
  - Report target: caret-anchored ghost text is the best default form.
  - Queued: keep panel fallback, but add a true inline-looking renderer only for apps with stable caret rects.
  - Proof: screenshot traces should show no overlap, no focus steal, and no whole-field anchoring.

- [ ] Add visual stability budget.
  - Product rule: a slightly worse suggestion that stays still is better than a better suggestion that flickers.
  - Likely code: `SuggestionPanelController` plus trace metadata.
  - Track: panel moves per suggestion, hidden/shown churn, and suggestion replacement count.

- [ ] Add per-app placement calibration to the beta checklist.
  - Done foundation: compatibility learning can store visual offsets.
  - Queued doc/process: each beta app needs one placement pass before testers use it.

## Insertion And Verification

- [x] Verify insertion after accept.
  - Code: `InsertionVerification` and insertion failure trace events.
  - Product rule: never keep walking the suggestion if the accepted text did not land.

- [x] Keep the remaining suggestion only when accepted text landed.
  - Code: `SuggestionSession.commitNextWordAcceptance`.

- [x] Suppress after insertion failure where the profile says to.
  - Code: `CompatibilityProfile.suppressesAfterInsertionFailure`.

- [x] Support multiple insertion modes.
  - Code: `InsertionMode.axSelectedText`.
  - Code: `InsertionMode.axValueReplacement`.
  - Code: `InsertionMode.axThenKeyEvents`.
  - Code: `InsertionMode.keyEvents`.
  - Code: `InsertionMode.clipboardFallbackOptIn`.

- [~] Keep clipboard fallback opt-in only.
  - Done: insertion mode exists as `clipboardFallbackOptIn`.
  - Queued: confirm the settings UI never enables clipboard fallback silently.
  - Queued tests: assert unsupported profiles do not fall through to clipboard insertion.

- [ ] Add undo-safety checks.
  - Report warns that wrong acceptance must be cheap to recover from.
  - Likely code: `InsertionEngine` and app-specific insertion plans.
  - Manual proof: accepting one word in TextEdit/Notes/Chrome should be undoable with one normal undo action.

- [ ] Add "wrong app" hard stop.
  - Stop condition from beta plan: insertion in the wrong app ends the beta.
  - Likely code: verify focused app and field identity immediately before insertion.
  - Trace: record app/field mismatch without raw text.

## Local Runtime And Model Policy

- [x] Keep the model runtime app-owned.
  - Code: `ModelRuntimeOwnership.appOwnedEmbedded`.
  - Product rule: users should not start Ollama, llama.cpp, or any model server.

- [x] Use MLX as the native local runtime path.
  - Code: `MLXModelRuntime`.
  - Code: `AppModelRuntimeFactory`.

- [x] Ship with a practical local model default.
  - Code: `CompletionModelPolicy.mvp.model` is `qwen35FourB`.
  - Docs: eval docs list model override names.

- [x] Suppress suggestions until the local runtime is ready.
  - Code map: runtime readiness flows through app runtime state and diagnostics.

- [x] Keep output generation small.
  - Code: `maxGeneratedTokens` is part of `CompletionModelPolicy`.
  - Code: environment overrides can compare visible words and token caps.

- [~] Make latency gates match the product bar.
  - Current code: target latency is `50ms`, trace analyzer flags `>= 1000ms` as slow.
  - Report bar: sub-perceptual is ideal; late suggestions become interruption.
  - Queued code: add tighter trace miss buckets, probably `>=250ms`, `>=500ms`, and `>=1000ms`.
  - Queued eval: compare p50/p90/p95 by app and request mode.

- [ ] Add confidence gating before display.
  - Report says the winners show suggestions only when confidence is high.
  - Current code mostly gates by cleaned output shape and context, not explicit confidence.
  - Options:
    - Use local ranker score for word completion.
    - Add heuristic confidence for phrase output: length, repetition, generic filler, latency, prompt mode, app profile.
    - Hide low-confidence suggestions and trace the suppression reason.
  - Likely home: new policy between `CompletionOutputCleaner` and presentation.

- [ ] Add boilerplate/name/local-term boost.
  - Report says the "wait, that was good" moment comes from project names, repeated phrases, local terms, and closers.
  - Existing code: `RecentWordExtractor` and `WordCompletionCandidateRanker` exist.
  - Queued: bias completions toward recent capitalized terms and repeated phrases without storing a permanent profile.
  - Privacy rule: keep this session-local unless the user opts into personalization.

## Prompting And Output Cleaning

- [x] Strip assistant-style output.
  - Code: `CompletionOutputCleaner.looksLikeAssistantMeta`.
  - Code: `looksLikeGenericChatFiller`.

- [x] Strip thinking markup.
  - Code: `<think>` removal in `CompletionOutputCleaner`.

- [x] Reject repeated context.
  - Code: `CompletionOutputCleaner.repeatsEarlierContext`.

- [x] Reject low-value single-word phrase suggestions.
  - Code: low-value set includes words like `the`, `and`, `to`, `of`.

- [x] Keep word-completion mode to a suffix.
  - Code: prompt says no spaces, punctuation, quotes, reasoning, or extra words.
  - Code: cleaner rejects invalid word completions.

- [~] Add an explicit "do not create new ideas" cleaner/prompt check.
  - Report warning: suggestions can quietly shift what people write about.
  - Queued: suppress open-ended starts like "I think we should", "The best way", "You might want", unless already present in context.
  - Queued tests: output cleaner should reject generic advice-shaped continuations.

- [ ] Add tone-flattening checks.
  - Report warns about generic suggestions that flatten the user's voice.
  - Likely code: output cleaner plus trace analyzer miss categories.
  - Examples to suppress: fake enthusiasm, moralizing, salesy filler, corporate phrases.

## Settings, Controls, And Trust

- [x] Persist per-app disable across launches.
  - Code map: disabled app selection exists in core configuration.
  - Product rule: user control should survive restart.

- [x] Make current app state visible in menu/diagnostics.
  - Code map: diagnostics and settings controllers exist.

- [x] Cancel pending suggestions when the current app is disabled.
  - Code map: request invalidation and app state checks.

- [x] Add a global temporary off switch.
  - Report calls this out for calls, screen shares, and focus mode.
  - Code: the menu bar now has pause for 15 minutes, pause for 1 hour, pause until restart, and resume.
  - Code: pause clears visible suggestions, cancels pending requests, and keeps status honest while paused.

- [ ] Add key remapping.
  - Report says forcing one control scheme can create resentment.
  - MVP can keep defaults, but beta should support at least:
    - `Tab` next word
    - backtick full visible accept
    - `Esc` snooze field
    - `Option+Tab` literal tab
  - Later: allow disabling full accept entirely.

- [ ] Add plain-English privacy setup copy.
  - Report says privacy explanation belongs in setup.
  - Needed message: "Text is read locally to make suggestions. It does not leave this Mac unless you turn on a feature that says so."
  - Keep it short. No legal mush.

- [ ] Add onboarding that teaches by doing.
  - Current docs cover first-run setup.
  - Queued UX: first launch should open TextEdit-style safe sample or guide the user to TextEdit.
  - Teach only: `Tab`, backtick, `Esc`, `Option+Tab`, per-app off.

- [ ] Add a "why no suggestion?" user-visible reason.
  - Diagnostics already explain blocked suggestions.
  - Queued: lightweight menu/status reason for normal users.
  - Examples: secure field, unsupported app, app paused, model warming, not enough context.

## Privacy And Data

- [x] Keep raw trace logs local.
  - Docs: `docs/product/eval-and-tracing.md`.
  - Product boundary: raw tracing is lab-only and local.

- [x] Do not require cloud inference.
  - Code: app-owned embedded runtime.

- [x] Keep screenshot tracing explicit.
  - Docs: screenshot trace env var and diagnostics toggle are documented.

- [~] Make customer-facing raw tracing off by default.
  - Docs say it must be off by default for a customer-facing app.
  - Queued code: before any beta outside the developer machine, require explicit debug toggle for raw prompt/output traces.
  - Queued tests: production/default config should not record raw typed text.

- [ ] Add a privacy mode test suite.
  - Assertions:
    - no typed text in default logs,
    - no screenshot trace unless enabled,
    - secure fields never emit raw text,
    - unsupported apps only log shape data,
    - diagnostics export redacts sensitive values.
  - Likely tests: `DiagnosticValueRedactorTests`, `DiagnosticsMetadataRedactorTests`, plus new runtime/default logging tests.

- [ ] Keep personalization opt-in.
  - Report says personalization is powerful but creepy if assumed.
  - Product default: no permanent writing-style learning.
  - Allowed early version: session-local repeated terms only.

- [ ] Keep clipboard context off by default.
  - Report praises this default in Cotypist.
  - Queued: if clipboard context is ever added, make it a separate explicit toggle with a visible explanation.

## Eval, QA, And Proof

- [x] Maintain manual smoke checklist.
  - Docs: `docs/product/manual-smoke-checklist.md`.

- [x] Maintain manual smoke run ledger.
  - Docs: `docs/product/manual-smoke-runs.md`.

- [x] Gate app proof with smoke scripts.
  - Docs: `docs/product/compatibility-matrix.md`.
  - Script mentioned: `./script/manual_smoke_status.sh --require-all`.

- [x] Track accept/useful rates and top misses.
  - Code: `AutocompleteTraceAnalyzer`.
  - Docs: `docs/product/eval-and-tracing.md`.

- [x] Track latency percentiles.
  - Code: trace summary includes p50, p90, p95.

- [x] Track app and request-mode buckets.
  - Code: trace summary includes accept/useful rates by app and mode.

- [~] Add acceptance quality thresholds.
  - Current eval summarizes rates but docs do not define ship/no-ship thresholds.
  - Queued default gates:
    - word completion p95 under target,
    - phrase continuation p95 under target,
    - insertion failure rate is zero in green apps,
    - accepted or typed-through rate beats ignored rate,
    - repeated-unaccepted suggestions trend down after tuning.

- [ ] Add annoyance metrics.
  - Report says uninstall risk comes from flicker, lag, bad `Tab`, wrong places, long generic prose.
  - Add counters for:
    - `Esc` snooze rate,
    - repeated same-field suppression,
    - suggestions hidden under 500ms,
    - suggestions shown then immediately typed over,
    - per-app disable events.

- [ ] Add a "do not ship" dashboard section.
  - Use trace analyzer top misses.
  - Show hard blockers first:
    - insertion failed,
    - secure field suggestion,
    - unsupported app presentation,
    - detached suggestion shown,
    - mock runtime fallback,
    - slow p95.

- [ ] Add dogfood report template.
  - Each session should answer:
    - Which app?
    - How many suggestions shown?
    - How many accepted?
    - What was annoying?
    - Did `Tab` ever surprise you?
    - Did anything feel private or risky?
    - Top trace miss to fix next.

## Packaging And Beta

- [x] Add app icon.

- [x] Validate bundle structure, MLX Metal libraries, and signature in smoke.

- [x] Sign debug bundles with hardened runtime.

- [x] Add release packaging and notarization-readiness script.

- [x] Add private beta packet generation.
  - Docs: `docs/product/private-beta-plan.md`.
  - Script: `./script/beta_readiness.sh`.

- [~] Finish signing and notarization submission.
  - Current todo already tracked this as not done.
  - Queued: submit notarization, staple, and verify Gatekeeper launch on a clean account.

- [ ] Run the first tiny private beta.
  - Shape: 3-5 people, one week.
  - Start: TextEdit, Notes, Obsidian only if they already use it, Chrome textarea sanity check.
  - Ask:
    - Did it help?
    - Did it interrupt?
    - Did it break trust?
    - Did `Tab` feel predictable?
    - Did suggestions feel like your words?

- [ ] Add beta stop automation.
  - If any stop condition happens, the app should make it easy to export the local diagnostic packet and pause suggestions.
  - Stop conditions:
    - wrong-app insertion,
    - suggestion over sensitive text,
    - unreliable `Tab`,
    - mock fallback,
    - manual model/server setup required.

## Research Patterns Already Reflected In The Code

- [x] "Tab accepts next word" from Cotypist-style behavior.
- [x] `Esc` dismisses and field-snoozes instead of popping right back.
- [x] local-first runtime, no separate model server.
- [x] per-app compatibility profiles.
- [x] password-manager and terminal denylist.
- [x] output cleaning for assistant/meta/generic filler.
- [x] local trace loop for accept rate, useful rate, latency, and misses.
- [x] diagnostics-only stance for unsafe rich text targets like Mail.

## Research Patterns Still Queued

- [x] Daily-use visible cap around `1-4` words.
- [~] Confidence gating before display.
- [~] Stronger fast-typing silence.
- [~] Search/URL/form suppression.
- [ ] Per-domain browser controls.
- [x] Global temporary off switch.
- [ ] Plain-English privacy setup.
- [ ] Production-safe default logging with raw text off.
- [ ] Optional personalization only after local trust is earned.
- [ ] More app adapters only after the core loop is boringly reliable.

## Near-Term Build Order

1. Prove the calmer defaults with dogfood traces.
   - Compare accept rate, useful rate, ignored rate, and p95 latency before widening app support.
   - Watch whether the new 4-word cap feels helpful or too clipped.

2. Finish confidence gating.
   - Hide more low-value phrase completions before display.
   - Trace suppression reasons.
   - Add tests around generic advice, tone drift, and long prose.

3. Add stronger silence for short chat and forms.
   - Extend `CompletionActivationPolicy`.
   - Prove accept rate improves or ignored rate drops.

4. Finish Codex dogfood proof.
   - Run a manual dogfood pass.
   - Record it in `docs/product/manual-smoke-runs.md`.
   - Use trace eval to pick the next miss.

5. Make privacy defaults beta-safe.
   - Raw text tracing off by default outside lab/debug mode.
   - Screenshot tracing explicit.
   - Diagnostics export redacted by default.

6. Add richer beta privacy controls.
   - Raw text tracing off by default outside lab/debug mode.
   - Redacted diagnostics export by default.
   - Clear local data button in first-run/settings, not only diagnostics.

7. Only then widen app support.
   - Safari next.
   - Mail only with a proven safe adapter.
   - Chat apps opt-in only.

## Non-Goals For Now

- No chat panel bundled into the typing loop.
- No cloud-only inference.
- No permanent writing-style personalization by default.
- No suggestions in sensitive fields.
- No full-suggestion-on-`Tab` default.
- No broad app expansion before the core apps are stable.
- No source-code-editor support unless explicitly opted in.
