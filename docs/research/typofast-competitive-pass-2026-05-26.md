# TypoFast Competitive Pass

Date: 2026-05-26  
Competitor: [blefo/typofast](https://github.com/blefo/typofast)  
Reviewed public commit: [`4ddc96f8975e66d2829766c6ccff2a2e74d89aa5`](https://github.com/blefo/typofast/tree/4ddc96f8975e66d2829766c6ccff2a2e74d89aa5)

This is a public-behavior and architecture-clue review. Do not copy TypoFast code, UI, prompts, assets, or app structure. The useful lessons below are rewritten into SteadyType's own privacy-first, proof-gated product shape.

## Executive Takeaway

TypoFast is a very small, new public repo. Its sharp idea is simple: a Mac menu bar app predicts the next words locally, shows grey text near the caret, and uses screen/OCR context to make completions feel more aware. Its public weakness is lack of proof: no releases, no issues, no privacy policy, no compatibility matrix, and no public smoke evidence.

SteadyType should not chase TypoFast's broad "any app" claim. The best transferable idea is safer visible-context handling: screen context can help, but the current typed line must be filtered out so OCR does not cause echoing or raw-field leakage into prompt context.

## Public Source Inventory

| Source | Finding |
| --- | --- |
| [README](https://github.com/blefo/typofast/blob/4ddc96f8975e66d2829766c6ccff2a2e74d89aa5/README.md) | Claims local on-device LLM, no account, no cloud typing, OCR context, menu bar startup, Tab accept, dismiss by continued typing. |
| [GlobalSuggestionController.swift](https://github.com/blefo/typofast/blob/4ddc96f8975e66d2829766c6ccff2a2e74d89aa5/typofast/GlobalSuggestionController.swift) | Uses Accessibility polling, AXObserver, event tap, overlay window, app restrictions, Tab/Esc/backtick handling, insertion fallbacks. |
| [ContentView.swift](https://github.com/blefo/typofast/blob/4ddc96f8975e66d2829766c6ccff2a2e74d89aa5/typofast/ContentView.swift) | Stores disabled apps, OCR toggle, personal prompt, acceptance stats, TTFT/tokens/sec/cache stats, first-run model download. |
| [AutocompleteEngine.swift](https://github.com/blefo/typofast/blob/4ddc96f8975e66d2829766c6ccff2a2e74d89aa5/typofast/AutocompleteEngine.swift) | Runs llama.cpp locally, warms kernels, reuses common prompt-token prefixes, tracks TTFT and cached tokens. |
| [WindowContextExtractor.swift](https://github.com/blefo/typofast/blob/4ddc96f8975e66d2829766c6ccff2a2e74d89aa5/typofast/WindowContextExtractor.swift) | Uses ScreenCaptureKit and Vision OCR, captures visible window context near the caret, excludes the active line/caret band. |
| [InputMethod controller](https://github.com/blefo/typofast/blob/4ddc96f8975e66d2829766c6ccff2a2e74d89aa5/InputMethod/TypofastInputController.swift) | Experimental InputMethodKit path uses marked text, Tab first-word accept, Esc dismiss. |
| [GitHub repo metadata](https://github.com/blefo/typofast) | Public repo, 3 stars, 0 forks, no license, no releases, no open issues or PRs at review time. |

## Deep Dive

### Core Writing Loop

Sourced behavior: TypoFast starts as a menu bar app, asks for permissions, watches focused text through Accessibility, and shows a short suggestion near the caret. README says Tab accepts a suggestion and continued typing dismisses it. Code adds more controls: Tab accepts the first word, backtick or `@` accepts the full suggestion, Esc dismisses, and Backspace can clear the last accepted suggestion state.

Transfer: SteadyType already has the safer version of this loop: `Tab` accepts one word only, full accept is separate, Esc calms the field, and broad app support remains proof-gated.

### Delight Moment

Likely delight, by inference: the first time a local model suggests the exact next word from surrounding screen context without an account or cloud service. TypoFast's README centers this promise: local next-word suggestions plus OCR context.

SteadyType adaptation: make screen context useful but visibly controlled. The concrete shipped change filters the active typed line out of OCR context before prompt construction.

### Annoyance Moment

Likely annoyance, by inference: permission friction, wrong app behavior, suggestion echoing the user's current text, and editor fragility. TypoFast's public repo has no complaint corpus, so this is code-risk inference, not user-review evidence.

SteadyType adaptation: keep unsupported apps blocked, keep screen context opt-in, and trace whether active-line filtering happened.

### When Not To Suggest

TypoFast source blocks its own app, disabled apps, missing Accessibility, and `AXSecureTextField`. It defaults to disabling Terminal, Xcode, iTerm2, Warp, and VS Code. I did not find a broad classifier for search fields, URLs, OTP, payment, API-key-like text, password managers, private prompt fields, or unsafe browser forms.

SteadyType already has stronger suppression through `AXFieldClassifier`, `SensitiveTextFieldPolicy`, compatibility profiles, hosted-browser policy, proof-only prompt lanes, and trace redaction.

### Supported Apps And Breakage

TypoFast README says "any app," but code evidence points to a narrower reality: Accessibility text roles and some web areas are the likely happy path; developer tools and terminals are disabled by default. There is no public compatibility matrix, smoke report, or app-by-app proof.

SteadyType should keep its current stance: TextEdit, Notes, Obsidian, and local Chrome fixtures are the beta-safe targets; prompt apps and production browser apps remain proof-only or blocked.

### Sensitive Fields

TypoFast rejects secure text fields in Accessibility helpers. That is necessary but not enough for browser forms, search/URL bars, banking/health pages, password managers, private prompts, and token/API-key fields.

SteadyType's advantage is to keep category-level suppression and make the reason visible in diagnostics without raw text.

### Browser, Docs, Chat, Notes, Code Editors

TypoFast has general AX and OCR paths, but no public proof for Chrome, Google Docs, chat apps, Notes, CodeMirror, Monaco, or Obsidian. The default disabled app list includes developer editors, which is strong evidence that code/editor surfaces are risky.

SteadyType should avoid "any app" language and keep proof-specific rows in `docs/product/compatibility-matrix.md` and `docs/product/app-proof-matrix.md`.

### Privacy And Data Handling

TypoFast's README claims no cloud typing. Public code shows local llama.cpp inference after model download, but also default OCR context and DEBUG logs that can include raw text, prompts, completions, and window titles. No public privacy policy or data checklist was found.

SteadyType should keep the stricter story: no raw typed text, prompts, screenshots, document names, URLs, recipients, or subject lines in default diagnostics. Visible page context remains opt-in, local, redacted in traces, and now filters the active typed line before model prompt use.

### Runtime And Model

TypoFast uses llama.cpp with GGUF, auto-downloads `unsloth/gemma-4-E2B-it-GGUF`, warms kernels, tracks TTFT/tokens/sec, and reuses common prompt-token prefixes. That is a useful latency pattern, but SteadyType's current MLX app-owned runtime is a better fit for the existing repo and beta gates.

Transfer later: keep exploring runtime cache reuse, but do not switch runtime stacks because of one new competitor repo.

## Complaint Mining

No meaningful public complaint corpus was found:

- GitHub issues: none.
- GitHub PRs: none.
- GitHub releases/tags: none.
- HN/web exact-name searches: no useful hits.
- Reddit evidence: inconclusive because direct JSON access was blocked.

The most reliable pain signals are therefore maintainer-visible gaps in the README: improved caching and improved UI are requested contribution directions.

## Do Not Copy

- No TypoFast source code, no exact app structure, no exact UI or tile layout.
- No hardcoded personal prompt, name, writing style, or wording.
- No raw DEBUG logging of typed text, prompts, completions, or window titles.
- No default-on OCR context for beta users.
- No broad "any app" support claim without proof.
- No unverified model-download/provenance story.
- No exact OCR heuristics or disabled-app list as product truth.

## Opportunity Matrix

Scores are 1-5, where 5 is best for user value/privacy/repo fit/proofability, and 5 is highest effort/risk.

| Idea | User value | Annoyance reduction | Privacy fit | Effort | Tech risk | Repo fit | Proofability | Decision |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| Filter active typed line out of screen/OCR context | 5 | 5 | 5 | 2 | 2 | 5 | 5 | Shipped now. |
| Show redacted context status in diagnostics | 4 | 3 | 5 | 2 | 1 | 5 | 5 | Already mostly present; keep improving later. |
| Runtime prompt-prefix cache reuse | 4 | 3 | 4 | 4 | 4 | 3 | 4 | Later; requires MLX-specific proof. |
| TTFT/tokens/cache metrics in tester UI | 3 | 2 | 4 | 2 | 2 | 4 | 5 | Later, if diagnostics need simpler numbers. |
| InputMethodKit ghost text path | 3 | 2 | 3 | 5 | 5 | 2 | 2 | Avoid for now. Too speculative. |
| Rich OCR context by default | 3 | 2 | 1 | 3 | 4 | 2 | 3 | Avoid. Keep opt-in only. |
| Broad any-app mode | 2 | 1 | 1 | 4 | 5 | 1 | 1 | Avoid. Conflicts with proof-gated stance. |
| Per-app restrictions UI polish | 4 | 4 | 5 | 2 | 1 | 5 | 5 | Already strong; continue in controls work. |

## Our Gap Map

| Lesson | Current SteadyType files | Gap | Change |
| --- | --- | --- | --- |
| Visible context can help local completions. | `Sources/AutocompleteLabCore/Engine/VisiblePageContext.swift`, `Sources/AutocompleteLabApp/Mac/VisiblePageContextProvider.swift`, `Sources/AutocompleteLabCore/Engine/CompletionPromptBuilder.swift` | Existing OCR sanitization removed chrome but did not explicitly remove the active typed line. | Added active-line filtering and trace metadata. |
| Suggestions should not echo what the user is typing. | `CompletionOutputCleaner.swift`, `CompletionCandidateRanker.swift`, `VisiblePageContext.swift` | Output cleaner handles model output, but OCR context could still bias echo. | Filter before prompt input. |
| Proof beats broad claims. | `docs/product/compatibility-matrix.md`, `docs/product/app-proof-matrix.md`, `docs/product/proof-manifest.json` | TypoFast has no proof; SteadyType should keep strict proof language. | Documented this as intentional avoid path. |
| Local-first is not enough; context reading needs trust. | `TracePrivacyPolicy.swift`, `RawAutocompleteTraceLog.swift`, `SettingsWindowController.swift`, `VisiblePageContextProvider.swift` | Screen context is trust-sensitive even when local. | Keep opt-in, filter active line, trace only metadata. |
| Latency metrics matter. | `RuntimeBackedCompletionEngine.swift`, `MLXModelRuntime.swift`, `model_latency_report.py`, `runtime_performance_report.py` | TypoFast exposes TTFT/tokens/cache in UI. SteadyType has proof scripts but less simple UI surfacing. | Later candidate, not shipped here. |

## Implementation Plan

Shipped in this pass:

1. Add `excludingActiveTextLine` to `VisiblePageContext` construction.
2. Normalize the active typed line and OCR lines the same way.
3. Drop exact, containing, or prefix-matched OCR lines that mirror the user's active line.
4. Surface `visiblePageContextActiveLineFiltered` in trace metadata.
5. Pass the current focused line from `VisiblePageContextProvider` into OCR context construction.
6. Add unit tests for exact active-line filtering and prefix filtering.

Next best follow-up:

1. Add a diagnostics row showing whether the last screen-context prompt used active-line filtering.
2. Add a trace replay fixture proving context filtering reduces echo suggestions.
3. Evaluate MLX prompt-prefix cache reuse only after a current latency slice proves it is the bottleneck.

## Scorecard

| Area | Before | After | Notes |
| --- | ---: | ---: | --- |
| Suggestion quality | 8 | 8.5 | Less chance OCR causes repeated current-line suggestions. |
| Timing | 8 | 8 | No timing change. |
| Non-annoyance | 8 | 8.5 | Reduces echo/duplicate context annoyance when screen context is on. |
| Tab safety | 9 | 9 | No accept behavior changed. |
| Esc/snooze behavior | 9 | 9 | No control behavior changed. |
| Sensitive-field suppression | 9 | 9 | Existing blocks stay intact. |
| Browser/form suppression | 8.5 | 8.5 | Existing policy unchanged. |
| Visual placement | 8 | 8 | No overlay change. |
| Latency | 7.5 | 7.5 | No runtime change. |
| Local-first/privacy | 9 | 9.3 | Screen context now avoids active-line prompt echo. |
| Onboarding/trust | 8 | 8 | No onboarding UI change. |
| Diagnostics | 8.5 | 8.8 | New redacted metadata says when active-line filtering happened. |
| Beta readiness | 7.5 | 7.8 | Safer optional screen-context behavior; live smoke still required. |
| Test coverage | 8.5 | 8.8 | Added focused unit coverage for OCR active-line filtering. |

## Verification Plan

Required:

```bash
swift test --jobs 1 --filter VisiblePageContextTests
swift test --jobs 1
./script/check_trace_eval.sh
```

Useful when doing live app proof:

```bash
./script/build_and_run.sh --verify
./script/manual_smoke_status.sh --strict
./script/check_current_build_privacy_export.sh
```

