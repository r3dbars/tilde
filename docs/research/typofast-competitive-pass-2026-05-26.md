# TypoFast Competitive Pass - 2026-05-26

Competitor: [blefo/typofast](https://github.com/blefo/typofast)
Snapshot studied: [`4ddc96f8975e66d2829766c6ccff2a2e74d89aa5`](https://github.com/blefo/typofast/tree/4ddc96f8975e66d2829766c6ccff2a2e74d89aa5)

This pass treats TypoFast as public product evidence, not a clone target. We should copy no code, assets, UI, prompts, branding, or trade dress. The useful old SteadyType learning still holds: keep the app tiny, local-first, non-annoying, proof-gated, and honest about what has not been proven.

## Executive Takeaway

TypoFast is a thin but useful signal. It shows the same product pull we care about: local, fast, system-wide writing suggestions with a tiny accept loop. Its best transferable ideas are fast stale-request rejection, local OCR context, clear per-app disable controls, and simple performance counters. Its biggest risks are broad "any app" expectation-setting, default-on OCR, raw debug logging of typed text/prompts, and weak public trust material.

The highest-leverage SteadyType improvement from this pass is to keep OCR context useful while filtering the active typed line before it enters prompt context. That lets screen context help with reply/topic evidence without letting OCR echo the exact sentence the user is currently writing.

## Source Findings

Public footprint is tiny:

- GitHub metadata on 2026-05-26: 3 stars, 0 forks, 0 open issues, no releases, no tags, no license listed. Source: GitHub repo/API for [blefo/typofast](https://github.com/blefo/typofast).
- README says TypoFast uses a local on-device LLM, no account, no cloud typing, OCR/context from the current app, and Tab accept. Source: [`README.md` lines 3-5](https://github.com/blefo/typofast/blob/4ddc96f8975e66d2829766c6ccff2a2e74d89aa5/README.md#L3-L5).
- No public complaint trail was found in GitHub issues, releases, forks, HN, Product Hunt, or exact public search. Treat complaint themes below as inferred from product/code evidence, not user quotes.

## Research Questions

- Core writing loop: menu bar app watches focused text through Accessibility, listens for keydown events, runs local llama.cpp completion, then draws an overlay near the caret. Sources: [`GlobalSuggestionController.swift` lines 121-162](https://github.com/blefo/typofast/blob/4ddc96f8975e66d2829766c6ccff2a2e74d89aa5/typofast/GlobalSuggestionController.swift#L121-L162), [`ContentView.swift` lines 364-380](https://github.com/blefo/typofast/blob/4ddc96f8975e66d2829766c6ccff2a2e74d89aa5/typofast/ContentView.swift#L364-L380), [`SuggestionOverlayWindow.swift` lines 25-45](https://github.com/blefo/typofast/blob/4ddc96f8975e66d2829766c6ccff2a2e74d89aa5/typofast/SuggestionOverlayWindow.swift#L25-L45).
- Delight moment: a short local suggestion appears where the user is already typing, and Tab inserts only the next word. Evidence: README Tab loop plus code path for first-word accept. Sources: [`README.md` line 5](https://github.com/blefo/typofast/blob/4ddc96f8975e66d2829766c6ccff2a2e74d89aa5/README.md#L5), [`GlobalSuggestionController.swift` lines 644-698](https://github.com/blefo/typofast/blob/4ddc96f8975e66d2829766c6ccff2a2e74d89aa5/typofast/GlobalSuggestionController.swift#L644-L698).
- Annoyance moment: stale or overconfident suggestions while typing continues. TypoFast explicitly guards against this by discarding completions when the key counter or text counter changes. Source: [`ContentView.swift` lines 397-449](https://github.com/blefo/typofast/blob/4ddc96f8975e66d2829766c6ccff2a2e74d89aa5/typofast/ContentView.swift#L397-L449).
- When not to suggest: explicit default disabled apps are Terminal, Xcode, iTerm2, Warp, and VS Code. Secure AX fields are rejected. Sources: [`ContentView.swift` lines 951-957](https://github.com/blefo/typofast/blob/4ddc96f8975e66d2829766c6ccff2a2e74d89aa5/typofast/ContentView.swift#L951-L957), [`AccessibilityHelpers.swift` lines 89-120](https://github.com/blefo/typofast/blob/4ddc96f8975e66d2829766c6ccff2a2e74d89aa5/typofast/AccessibilityHelpers.swift#L89-L120).
- Supported apps/editors: public README implies broad app support, but source evidence shows app-level restrictions and AX/overlay implementation. No public compatibility matrix was found.
- Where it breaks: no public issues were found. Inference from code: permission friction, Screen Recording trust, fragile AX surfaces, missing release artifacts, no license, and no broad proof material.
- Sensitive fields: rejects `AXSecureTextField`; no evidence found for broad URL/search/payment/password-manager/webmail suppression. Source: [`AccessibilityHelpers.swift` lines 89-120](https://github.com/blefo/typofast/blob/4ddc96f8975e66d2829766c6ccff2a2e74d89aa5/typofast/AccessibilityHelpers.swift#L89-L120).
- Browser/search/URL/code/docs/chat/notes handling: public code appears generic AX plus app restrictions. VS Code, Terminal, Xcode, iTerm2, and Warp are disabled by default. No public browser-form classifier was found.
- Controls: Tab accepts first word; `@` or backtick accepts all; Esc dismisses; Delete can undo internal accepted suggestion state. Source: [`GlobalSuggestionController.swift` lines 644-858](https://github.com/blefo/typofast/blob/4ddc96f8975e66d2829766c6ccff2a2e74d89aa5/typofast/GlobalSuggestionController.swift#L644-L858).
- Partial/full accept: one-word Tab and all-suggestion shortcut are implemented. There is also an experimental InputMethod path with marked text, but the main app path appears to be AX overlay and insertion. Source: [`InputMethod/TypofastInputController.swift` lines 34-101](https://github.com/blefo/typofast/blob/4ddc96f8975e66d2829766c6ccff2a2e74d89aa5/InputMethod/TypofastInputController.swift#L34-L101).
- Pause/disable/app allowlist: app restriction list is exposed in UI. Source: [`ContentView.swift` lines 1092-1156](https://github.com/blefo/typofast/blob/4ddc96f8975e66d2829766c6ccff2a2e74d89aa5/typofast/ContentView.swift#L1092-L1156).
- Privacy claims: "no account, no cloud typing" with local on-device LLM. Source: [`README.md` line 3](https://github.com/blefo/typofast/blob/4ddc96f8975e66d2829766c6ccff2a2e74d89aa5/README.md#L3).
- Typed data stored/transmitted: inference from public code: no cloud completion upload path found; first run downloads a model from Hugging Face. Debug builds can print raw typed text, raw completions, and full model prompts. Sources: [`ContentView.swift` lines 80-82](https://github.com/blefo/typofast/blob/4ddc96f8975e66d2829766c6ccff2a2e74d89aa5/typofast/ContentView.swift#L80-L82), [`ContentView.swift` lines 419-422](https://github.com/blefo/typofast/blob/4ddc96f8975e66d2829766c6ccff2a2e74d89aa5/typofast/ContentView.swift#L419-L422), [`ContentView.swift` lines 810-814](https://github.com/blefo/typofast/blob/4ddc96f8975e66d2829766c6ccff2a2e74d89aa5/typofast/ContentView.swift#L810-L814), [`ContentView.swift` lines 891-906](https://github.com/blefo/typofast/blob/4ddc96f8975e66d2829766c6ccff2a2e74d89aa5/typofast/ContentView.swift#L891-L906).
- Local vs cloud: completion appears local through llama.cpp; network download is for managed model asset. Sources: [`AutocompleteEngine.swift` lines 1-2](https://github.com/blefo/typofast/blob/4ddc96f8975e66d2829766c6ccff2a2e74d89aa5/typofast/AutocompleteEngine.swift#L1-L2), [`LlamaContext.swift` lines 47-89](https://github.com/blefo/typofast/blob/4ddc96f8975e66d2829766c6ccff2a2e74d89aa5/typofast/LlamaContext.swift#L47-L89).
- Trust onboarding: public README says open menu bar, allow permissions, type. No privacy policy, release artifact, or signed distribution proof found.
- Essential settings: OCR on/off, disabled apps, model/runtime status, acceptance/performance counters. Sources: [`ContentView.swift` lines 995-1156](https://github.com/blefo/typofast/blob/4ddc96f8975e66d2829766c6ccff2a2e74d89aa5/typofast/ContentView.swift#L995-L1156).
- Diagnostics/proof: TypoFast exposes TTFT, tokens/sec, cache reuse, suggested/accepted counts. It lacks public proof manifests or privacy export proof.

## Architecture Inferences

- Main path is likely a normal macOS overlay with AX/event taps, not a production InputMethodKit flow. Inference from Xcode project shape and main app source.
- OCR is used as nearby context and filtered by confidence, chrome terms, crop/caret band, active line text, and duplicate detection. Source: [`WindowContextExtractor.swift` lines 41-127](https://github.com/blefo/typofast/blob/4ddc96f8975e66d2829766c6ccff2a2e74d89aa5/typofast/WindowContextExtractor.swift#L41-L127), [`OCRTextProcessor.swift`](https://github.com/blefo/typofast/blob/4ddc96f8975e66d2829766c6ccff2a2e74d89aa5/typofast/OCRTextProcessor.swift).
- Prompt caching matters for latency. TypoFast tracks cached tokens reused and uses prompt/generation sequences. Sources: [`AutocompleteEngine.swift` lines 7-16](https://github.com/blefo/typofast/blob/4ddc96f8975e66d2829766c6ccff2a2e74d89aa5/typofast/AutocompleteEngine.swift#L7-L16), [`AutocompleteEngine.swift` lines 119-180](https://github.com/blefo/typofast/blob/4ddc96f8975e66d2829766c6ccff2a2e74d89aa5/typofast/AutocompleteEngine.swift#L119-L180).

## Do Not Copy

- Do not copy TypoFast code, prompts, UI text, brand, model choice, or exact settings layout.
- Do not copy broad "any app" expectation-setting without current-head proof.
- Do not copy default-on OCR for public beta.
- Do not copy raw debug logging of typed text, prompts, or completions.
- Do not copy creator-specific personalization defaults.
- Do not copy an InputMethodKit rewrite until the floating overlay proves usefulness.

## Opportunity Matrix

Scale: 1 low, 5 high. For effort/risk, 5 means expensive or risky.

| Idea | User value | Annoyance reduction | Privacy fit | Effort | Tech risk | Repo fit | Proofability | Decision |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| Filter active typed line out of OCR prompt context | 5 | 4 | 5 | 2 | 2 | 5 | 5 | Shipped in this pass |
| Add trace/eval assertion for active-line filtering | 4 | 3 | 5 | 1 | 1 | 5 | 5 | Shipped in this pass |
| Diagnostics line for OCR active-line filtered yes/no | 3 | 2 | 5 | 2 | 1 | 4 | 4 | Next |
| Pre-read suppression for URL/search/form when AX metadata is enough | 5 | 5 | 5 | 3 | 3 | 5 | 4 | Next |
| Expand browser/search/payment/webmail fixtures | 5 | 5 | 5 | 3 | 2 | 5 | 5 | Next |
| Prompt/session cache metrics in UI | 3 | 2 | 4 | 4 | 4 | 3 | 3 | Later, evidence-led |
| Default-on OCR | 3 | 2 | 1 | 1 | 3 | 1 | 3 | Avoid |
| InputMethodKit true inline ghost text | 4 | 3 | 3 | 5 | 5 | 1 | 2 | Avoid for now |
| Broad "works everywhere" marketing | 2 | 1 | 1 | 1 | 5 | 1 | 1 | Avoid |

## Our Gap Map

- OCR prompt boundary: [Sources/AutocompleteLabCore/Engine/VisiblePageContext.swift](/Users/redbars/.codex/worktrees/7cb0/transcripted-autocomplete-lab/Sources/AutocompleteLabCore/Engine/VisiblePageContext.swift). Gap was that visible context could carry the same active typed line into model prompt context. Fixed by adding `excludingActiveTextLine` and `visiblePageContextActiveLineFiltered` metadata.
- OCR provider handoff: [Sources/AutocompleteLabApp/Mac/VisiblePageContextProvider.swift](/Users/redbars/.codex/worktrees/7cb0/transcripted-autocomplete-lab/Sources/AutocompleteLabApp/Mac/VisiblePageContextProvider.swift). Fixed by deriving the current line from `FocusedTextContext.textBeforeCursor` before background OCR capture.
- Prompt eval proof: [Tests/AutocompleteLabCoreTests/MagicWritingOCRPromptEvalTests.swift](/Users/redbars/.codex/worktrees/7cb0/transcripted-autocomplete-lab/Tests/AutocompleteLabCoreTests/MagicWritingOCRPromptEvalTests.swift). Added a focused prompt test that keeps reply context while suppressing active-line echo.
- OCR sanitizer proof: [Tests/AutocompleteLabCoreTests/VisiblePageContextTests.swift](/Users/redbars/.codex/worktrees/7cb0/transcripted-autocomplete-lab/Tests/AutocompleteLabCoreTests/VisiblePageContextTests.swift). Added exact and prefix active-line filtering tests.
- Existing suppression and privacy surfaces that remain the right next targets: [Sources/AutocompleteLabCore/Session/SensitiveTextFieldPolicy.swift](/Users/redbars/.codex/worktrees/7cb0/transcripted-autocomplete-lab/Sources/AutocompleteLabCore/Session/SensitiveTextFieldPolicy.swift), [Sources/AutocompleteLabCore/Session/AXFieldClassifier.swift](/Users/redbars/.codex/worktrees/7cb0/transcripted-autocomplete-lab/Sources/AutocompleteLabCore/Session/AXFieldClassifier.swift), [Sources/AutocompleteLabCore/Configuration/BrowserHostedSurfacePolicy.swift](/Users/redbars/.codex/worktrees/7cb0/transcripted-autocomplete-lab/Sources/AutocompleteLabCore/Configuration/BrowserHostedSurfacePolicy.swift), [Sources/AutocompleteLabApp/App/PrivacyExportProofCommand.swift](/Users/redbars/.codex/worktrees/7cb0/transcripted-autocomplete-lab/Sources/AutocompleteLabApp/App/PrivacyExportProofCommand.swift).

## Implementation Plan

This pass intentionally picked one small shipped improvement:

1. Keep OCR context opt-in and local-first.
2. Derive the active typed line from the focused text context before OCR capture.
3. Filter OCR lines that exactly match, contain, or prefix-match the active typed line after normalization.
4. Expose redacted metadata only: whether active-line filtering happened, not the filtered text.
5. Prove with focused unit tests and prompt eval tests.

Next best follow-ups:

1. Add a Diagnostics/Settings proof row: `Screen context filtered current line: yes/no`.
2. Add pre-read suppression when AX metadata already identifies URL/search/form/unknown risky surfaces.
3. Expand browser hosted surface fixtures for search, recipient, subject, login, payment, Google Docs, Notion, Slack, Discord, and prompt apps.
4. Refresh stale proof manifest/manual smoke gates before claiming beta readiness.

## Scorecard

| Area | Before | After | Note |
| --- | ---: | ---: | --- |
| Suggestion quality | B | B+ | OCR context is less likely to echo current text. |
| Timing | B | B | No latency change. |
| Non-annoyance | B+ | A- | Less active-line repetition. |
| Tab safety | A- | A- | Existing one-word Tab behavior unchanged. |
| Esc/snooze behavior | B+ | B+ | Unchanged. |
| Sensitive-field suppression | A- | A- | Existing gates remain; next work is pre-read suppression. |
| Browser/form suppression | B | B | No direct browser policy change in this pass. |
| Visual placement | B+ | B+ | Unchanged. |
| Latency | B | B | Unchanged. |
| Local-first/privacy | A- | A | OCR prompt boundary is safer. |
| Onboarding/trust | B | B+ | Research doc plus trace metadata makes the behavior easier to explain. |
| Diagnostics | B | B+ | Metadata exists; visible UI row remains next. |
| Beta readiness | C+ | B- | Improved one trust edge; stale global proof gates remain. |
| Test coverage | B+ | A- | Added OCR sanitizer and prompt eval tests. |

## Verification Plan

Run, in this order:

```bash
swift test --jobs 1 --filter 'VisiblePageContextTests|MagicWritingOCRPromptEvalTests'
swift test --jobs 1 --filter 'CompletionPromptBuilderTests|SuggestionOrchestratorTests|VisiblePageContextRefreshPolicyTests'
swift test --jobs 1
./script/check_trace_eval_self_test.sh
./script/check_quality_eval.sh
```

Known broader blockers from the proof lane before verification: `check_proof_manifest.sh` expects a newer host-policy version than the manifest currently has, and `manual_smoke_status.sh --strict` reports stale current-head app proof rows. Do not claim current-head beta readiness until those pass.

## Verification Results From This Pass

Passed:

```bash
swift test --jobs 1 --filter 'VisiblePageContextTests|MagicWritingOCRPromptEvalTests'
swift test --jobs 1 --filter 'CompletionPromptBuilderTests|SuggestionOrchestratorTests|VisiblePageContextRefreshPolicyTests'
swift test --jobs 1 --filter SuggestionEpisodeTests
swift test --jobs 1
./script/check_trace_eval_self_test.sh
./script/check_quality_eval.sh
./script/build_and_run_self_test.sh
AUTOCOMPLETE_LAB_DIRECT_LAUNCH=true AUTOCOMPLETE_LAB_VERIFY_STABILITY_SECONDS=1 ./script/build_and_run.sh --verify
./script/check_test_coverage_manifest.sh
./script/check_local_only_network_surface_self_test.sh
AUTOCOMPLETE_LAB_PRIVACY_EXPORT_LOCK_WAIT_SECONDS=0 ./script/check_current_build_privacy_export.sh
./script/check_proof_manifest.sh
git diff --check -- <changed files>
```

Full Swift result: 1333 tests in 179 suites passed.

Follow-up notes:

- The first `./script/build_and_run.sh --verify` wrapper used a bad zsh variable and did not produce a reliable exit. The direct-launch retry passed and produced `dist/SteadyType.app` with bundle id `bar.r3d.steadytype` and build `1451`.
- The first privacy export attempt was blocked by an active sibling `real_app_smoke.sh codex --manual-gate`; after the lock cleared, the current build privacy export proof passed.
- `./script/check_proof_manifest.sh` initially failed because `hostPolicy.policyVersion` was stale. The manifest was updated to `2026-05-23.1`, matching `HostCompatibilityPolicy.currentPolicyVersion`, without changing proof states.
