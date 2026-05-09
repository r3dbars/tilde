# Suggestion Quality Scorecard - 2026-05-08

## Source

- Deep Research topic: Suggestion Quality Rubric for Local Autocomplete (`/Users/redbars/Downloads/deep-research-report (18).md`)
- Repo: `transcripted-autocomplete-lab`
- Date: 2026-05-08
- Commit inspected: `771f14d` plus this goal's working-tree changes on `codex/autocomplete-lab-worktree-20260508-3f8a`

## Executive Summary

The research says this app should not feel like a chat assistant. It should quietly complete the user's current wording with short, local, easy-to-ignore suggestions. For this repo, suggestion quality is a trust problem, not a novelty problem: wrong-topic, assistant-like, long, structural, or stale suggestions should be suppressed.

The current app has strong scaffolding: local-first runtime, short output policy, prompt construction, output cleaning, candidate ranking, conservative triggers, typed-over suppression, trace analysis, and proof scripts. This loop tightened the main weak spots: assistant-voice filtering, markdown/code and sentence-boundary suppression, ranking before display, unknown-field suppression, fresh-install default-off wiring, and accepted-and-kept survival tracking after verified insertion.

The score still cannot honestly reach 100 because current real-model dogfood proof is not fresh enough, accepted-and-kept proof now tracks 2s/10s/30s but not the research's full 10-minute/send-save horizon, and several app-compatibility proof rows remain manual.

## Product Standard

Excellent behavior for this app means:

- suggestions are 1-6 words by default and never more than 12 words, 60 characters, one clause, and one sentence;
- suggestions continue only the local thought already in progress;
- mid-word suggestions only complete the current word;
- terminal punctuation defaults to silence;
- bullets, markdown, and prompts keep their structure;
- code-like regions are suppressed unless a real code-specific path exists;
- assistant stems like `Certainly`, `Here's`, `I can`, `Let's`, `Overall`, and `you should` are blocked before display;
- accepted-and-kept means the inserted text survived after acceptance, not just that insertion succeeded;
- no suggestion is preferred over a weak, distracting, or risky one.

## Non-Negotiables

Any of these block beta for suggestion quality or force the relevant category to zero:

- assistant-like replies shown in prompt-writing contexts;
- a suggestion answers the prompt instead of completing the user's wording;
- phrase suggestions appear mid-word;
- suggestions continue after `.`, `!`, or `?` by default;
- a suggestion invents a new bullet, heading, code fence, or second sentence;
- wrong-topic suggestions are shown in real dogfood proof;
- accepted-and-kept is counted immediately after insertion instead of after survival checks;
- mock fallback is presented as production-quality suggestion proof;
- raw typed text is stored or exported without explicit opt-in;
- broad app support is claimed without current proof.

## Current App Assessment

The repo is much closer to a credible private-beta quality gate than the starting state, but it is still not a 100/100 product-quality system. The deterministic gates are now strong: common assistant voice, generic filler, unsafe prompt actions, second sentences, invented markdown structures, terminal punctuation, markdown code contexts, unknown AX fields, and low-ranked candidates are suppressed before display.

The biggest remaining gap is evidence. The app can now record survival checkpoints after verified insertion, but there is no current proof set showing a high accepted-and-kept rate, low deletion rate, low typed-over rate, zero assistant-voice rate, and zero wrong-topic rate from real local model dogfood across trusted apps.

## Score

Overall score: 90/100

Starting score before this loop: 79/100
Accepted-kept restraint update: 89/100 -> 90/100 (+1).

Proof cap: 90/100 until fresh real-model, current-build dogfood proof closes the remaining evidence gaps.

## Score Breakdown

### Locality and Topic Discipline

- Category name: Locality and topic discipline
- Weight: 25
- Current score: 23/25
- Why this score: Prompt construction, candidate cleaning, and ranking heavily favor local continuation and suppress prompt-answer, rewrite, planning-drift, date/name, and repetition failures. It is not 25 because there is no fresh human-labeled wrong-topic dogfood set.
- Evidence found in repo: `Sources/AutocompleteLabCore/Engine/CompletionPromptBuilder.swift`, `Sources/AutocompleteLabCore/Engine/CompletionOutputCleaner.swift`, `Sources/AutocompleteLabCore/Engine/CompletionCandidateRanker.swift`, `Tests/AutocompleteLabCoreTests/CompletionQualityEvalTests.swift`, `Tests/AutocompleteLabCoreTests/CompletionCandidateRankerTests.swift`.
- Missing evidence: current raw opt-in local dogfood labels for wrong-topic and answer-like suggestions.
- What would make it 100/100: zero wrong-topic or answer-like suggestions in a current real-model audit across TextEdit, Notes, Obsidian, and prompt-writing fixtures.

### Usefulness and Likely Acceptance

- Category name: Usefulness and likely acceptance
- Weight: 20
- Current score: 18/20
- Exact metric change: 17/20 -> 18/20 (+1), moving overall suggestion quality 89/100 -> 90/100.
- Why this score: Ranking now chooses among cleaned candidates before display, and accepted-and-kept survival is tracked after verified insertion. Immediate deletion, typed-over, and high normalized edit distance now feed bounded future display restraint with tiny-sample guardrails. It is not 20 because the proof horizon is 2s/10s/30s, not the research's ideal 10-minute/send-save horizon, and current real-model accepted-and-kept proof is still incomplete.
- Evidence found in repo: `Sources/AutocompleteLabCore/Engine/LocalCompletionEngine.swift`, `Sources/AutocompleteLabApp/Runtime/MLXModelRuntime.swift`, `Sources/AutocompleteLabApp/App/AcceptanceSurvivalChecker.swift`, `Sources/AutocompleteLabApp/App/AppDelegate.swift`, `Sources/AutocompleteLabCore/Session/AcceptedAndKeptLearning.swift`, `Sources/AutocompleteLabCore/Session/DisplayScorePolicy.swift`, `Tests/AutocompleteLabCoreTests/AcceptedAndKeptLearningTests.swift`, `Tests/AutocompleteLabAppTests/SuggestionOrchestratorTests.swift`, `script/check_trace_eval.sh`, `script/experiment_report.py`.
- Missing evidence: current kept-after-10-minutes/send-save proof and real deletion/typed-over/edit-distance rates across trusted apps.
- What would make it 100/100: accepted-and-kept beats the target on current-build dogfood, immediate deletion is near zero, and typed-over failures feed suppression without false positives.

### Voice Match and Non-Assistant Tone

- Category name: Voice match and non-assistant tone
- Weight: 15
- Current score: 14/15
- Why this score: The cleaner blocks the research's explicit assistant stems and common generic pivots. It is not 15 because there is no real-model assistant-voice classifier or fresh raw dogfood audit.
- Evidence found in repo: `Sources/AutocompleteLabCore/Engine/CompletionOutputCleaner.swift`, `Tests/AutocompleteLabCoreTests/CompletionOutputCleanerTests.swift`, `Tests/AutocompleteLabCoreTests/CompletionQualityEvalTests.swift`.
- Missing evidence: assistant-voice rate from current local model output.
- What would make it 100/100: zero assistant-voice suggestions in a labeled current-model sample, plus a repeatable script that fails if assistant stems leak.

### Brevity and Boundary Control

- Category name: Brevity and boundary control
- Weight: 10
- Current score: 9/10
- Why this score: Runtime config is short, cleaner uses visible-word limits, second sentences are suppressed, and terminal punctuation now stays quiet. It is not 10 until fresh traces prove too-long rate stays near zero under the real runtime.
- Evidence found in repo: `Sources/AutocompleteLabCore/Runtime/CompletionModelPolicy.swift`, `Sources/AutocompleteLabCore/Session/CompletionActivationPolicy.swift`, `Sources/AutocompleteLabCore/Session/SuggestionTriggerPolicy.swift`, `Tests/AutocompleteLabCoreTests/CompletionActivationPolicyTests.swift`, `Tests/AutocompleteLabCoreTests/SuggestionTriggerPolicyTests.swift`.
- Missing evidence: current too-long rate from real-model traces.
- What would make it 100/100: trace eval proves no shown suggestions violate the length and one-sentence policy.

### Ignoreability and Low Intrusion

- Category name: Ignoreability and low intrusion
- Weight: 10
- Current score: 9/10
- Why this score: Typing hides suggestions, repeated typed-over behavior suppresses future suggestions, and fresh install now starts unproven apps disabled. It is not 10 because real-app annoyance proof is still incomplete.
- Evidence found in repo: `Sources/AutocompleteLabCore/Session/AnnoyanceSuppressor.swift`, `Sources/AutocompleteLabApp/App/AppDelegate.swift`, `Sources/AutocompleteLabCore/Configuration/DisabledAppSelection.swift`, `Tests/AutocompleteLabCoreTests/DisabledAppSelectionTests.swift`.
- Missing evidence: current typed-over rate, immediate deletion rate, and real prompt-app no-annoyance proof.
- What would make it 100/100: current proof shows suggestions disappear harmlessly on normal typing and do not pressure prompt/chat users.

### Structural Fidelity

- Category name: Structural fidelity
- Weight: 10
- Current score: 9/10
- Why this score: Markdown code contexts, fenced code, inline code spans, invented markdown structures, new bullets, renumbering, unsafe field kinds, and mid-word phrase completions are blocked. It is not 10 because real app markdown/editor proof still needs current screenshots and trace rows.
- Evidence found in repo: `Sources/AutocompleteLabCore/Session/CompletionActivationPolicy.swift`, `Sources/AutocompleteLabCore/Engine/CompletionOutputCleaner.swift`, `Tests/AutocompleteLabCoreTests/CompletionActivationPolicyTests.swift`, `Tests/AutocompleteLabCoreTests/CompletionOutputCleanerTests.swift`, `docs/product/manual-smoke-checklist.md`.
- Missing evidence: current Obsidian/Markdown proof and real editor trace proof.
- What would make it 100/100: current app proof shows bullets, markdown, and prompt fields stay structurally intact with no invented structure.

### Safety and Neutral Phrasing

- Category name: Safety and neutral phrasing
- Weight: 10
- Current score: 8/10
- Why this score: Secure/suppressed fields, unknown AX fields, unsafe prompt actions, search/form/url/unproven surfaces, and assistant coaching phrases are blocked. It is not 10 because there is no current safety-labeled output audit for biased, offensive, or sensitive suggestions.
- Evidence found in repo: `Sources/AutocompleteLabCore/Session/AXFieldClassifier.swift`, `Sources/AutocompleteLabCore/Session/AcceptedTextSafetyPolicy.swift`, `Sources/AutocompleteLabCore/Engine/CompletionOutputCleaner.swift`, `Tests/AutocompleteLabCoreTests/AXFieldClassifierTests.swift`, `Tests/AutocompleteLabCoreTests/CompletionOutputCleanerTests.swift`.
- Missing evidence: current toxicity/bias/sensitive-output audit and prompt-app no-submit proof.
- What would make it 100/100: labeled audit proves zero unsafe, biased, offensive, privacy-sensitive, or submit-like suggestions on current build.

## 0/100 Definition

Suggestion quality is 0/100 if the app shows assistant-like replies, answers prompts, generates phrase suggestions mid-word, starts new bullets or sentences unexpectedly, counts immediate insertion as accepted-and-kept, or leaks raw typed text without opt-in.

## 50/100 Definition

The app mostly produces short text and has some filters, but it still shows assistant-like, wrong-topic, too-long, or structure-breaking suggestions often enough that a user would lose trust.

## 80/100 Definition

The app is private-beta plausible in narrow supported apps. Most dangerous classes are blocked by deterministic gates, but current real-model proof is still incomplete and some metrics require manual review.

## 100/100 Definition

The app has deterministic gates plus current real-model proof showing short, local, non-assistant, structurally faithful suggestions with strong accepted-and-kept rate, near-zero deletion/typed-over failures, no wrong-topic output, no unsafe output, no mock fallback counted as quality proof, and current proof for every claimed app surface.

## Failure Modes

1. Assistant reply appears while the user is writing a prompt.
2. Suggestion answers or rewrites instead of completing wording.
3. Accepted-and-kept is falsely counted before survival is known.
4. Suggestion starts a second sentence or new bullet.
5. Phrase suggestion appears in the middle of a word.
6. Suggestion appears after terminal punctuation.
7. Suggestion invents names, dates, requirements, or topics.
8. Suggestion breaks markdown, code, list, or prompt structure.
9. User accepts then immediately deletes most of it.
10. Suggestion is technically safe but low-value enough to train users to ignore the app.

## Evidence Requirements

- `swift test` must pass.
- Targeted quality tests must cover assistant stems, prompt-answer framing, second sentences, markdown structure, mid-word suppression, terminal punctuation, candidate ranking, unknown-field suppression, default-off state, and survival tracking.
- `./script/check_quality_eval.sh` must pass.
- `./script/check_trace_eval.sh` must show accepted-and-kept, deletion, typed-over, too-long, assistant-voice, repetition, latency, and app/field slices from current traces.
- `./script/check_proof_manifest.sh` must pass for any app-compatibility claim counted toward 100.
- `./script/manual_smoke_status.sh --strict` and `./script/check_visual_placement_evidence.sh --require-all` must pass before beta support claims are treated as current.
- Manual dogfood must include labeled wrong-topic, assistant-voice, too-long, repetition, and kept-after-10-minutes/send-save results.

Current completed screenshot artifacts referenced by the proof manifest:

- TextEdit: [textedit-inline.png](visual-placement-screenshots/textedit-inline.png)
- Chrome textarea: [chrome-textarea.png](visual-placement-screenshots/chrome-textarea.png)
- Chrome contenteditable: [chrome-contenteditable.png](visual-placement-screenshots/chrome-contenteditable.png)
- Chrome editor-like: [chrome-editor-like.png](visual-placement-screenshots/chrome-editor-like.png)
- Chrome Monaco-like: [chrome-monaco-like.png](visual-placement-screenshots/chrome-monaco-like.png)
- Chrome ProseMirror-like: [chrome-prosemirror-like.png](visual-placement-screenshots/chrome-prosemirror-like.png)
- Chrome chat-like composer: [chrome-chat-like.png](visual-placement-screenshots/chrome-chat-like.png)
- Codex: [codex-inline.png](visual-placement-screenshots/codex-inline.png)
- Obsidian: [obsidian.png](visual-placement-screenshots/obsidian.png)
- Apple Notes title: [notes-title.png](visual-placement-screenshots/notes-title.png)
- Apple Notes body: [notes-body.png](visual-placement-screenshots/notes-body.png)
- Apple Notes checklist: [notes-checklist.png](visual-placement-screenshots/notes-checklist.png)

## Implementation Queue

### 1. Tighten continuation-only output gates

- Objective: block assistant stems, generic pivots, second sentences, invented markdown, and answer-like continuations before display.
- Files likely involved: `CompletionOutputCleaner.swift`, `CompletionQualityEvalTests.swift`, `CompletionOutputCleanerTests.swift`.
- Tests to add/update: assistant-stem, second-sentence, markdown-structure, prompt-answer cases.
- Proof required: targeted Swift tests and quality eval.
- Risk level: low.
- Expected score impact: +4.
- Status: completed in this loop.

### 2. Rank cleaned candidates before display

- Objective: select the safest useful candidate from multiple model outputs and trace candidate score metadata.
- Files likely involved: `CompletionCandidateRanker.swift`, `CompletionOutputCleaner.swift`, `LocalCompletionEngine.swift`, `MLXModelRuntime.swift`.
- Tests to add/update: candidate metadata and rank-before-display tests.
- Proof required: targeted Swift tests and trace replay metadata.
- Risk level: medium.
- Expected score impact: +2.
- Status: completed in this loop.

### 3. Fail closed in uncertain fields and structures

- Objective: suppress unknown AX fields, markdown code contexts, terminal sentence boundaries, and fresh-install unproven app support.
- Files likely involved: `AXFieldClassifier.swift`, `CompletionActivationPolicy.swift`, `SuggestionTriggerPolicy.swift`, `DisabledAppSelection.swift`, `AppDelegate.swift`.
- Tests to add/update: unknown field, markdown code, sentence boundary, missing defaults tests.
- Proof required: targeted Swift tests.
- Risk level: medium.
- Expected score impact: +2.
- Status: completed in this loop.

### 4. Make accepted-and-kept survival-based

- Objective: stop treating insertion verification as accepted-and-kept; record survival checkpoints and retention clearing.
- Files likely involved: `AppDelegate.swift`, `AcceptanceSurvivalChecker.swift`, `RawAutocompleteTraceLog.swift`.
- Tests to add/update: survival checker state tests and trace analyzer checks.
- Proof required: app-target tests, trace eval, and later real dogfood traces.
- Risk level: medium.
- Expected score impact: +2.
- Status: completed for 2s/10s/30s checkpoints in this loop; 10-minute/send-save remains.

### 5. Run a current raw opt-in local dogfood audit

- Objective: measure wrong-topic, assistant-voice, too-long, repetition, accepted-and-kept, deletion, and typed-over rates from current local model output.
- Files likely involved: `script/check_trace_eval.sh`, `docs/product/manual-smoke-runs.md`, `docs/product/proof-manifest.json`.
- Tests to add/update: trace self-tests if new counters are added.
- Proof required: current bounded trace slices and dogfood labels.
- Risk level: high because raw text must be explicitly opt-in and local only.
- Expected score impact: +6 to +8.
- Status: remaining manual proof.

## Codex Execution Goal

Raise suggestion quality from 79/100 to the proof-capped ceiling by enforcing continuation-only behavior, stricter structure and field suppression, candidate ranking metadata, and survival-based accepted-and-kept tracking without widening app compatibility or enabling cloud inference.

## Stop Conditions

- Stop at 100/100 only when current real-model, current-build proof closes every category.
- Stop below 100 if the only remaining work requires manual dogfood, screenshots, raw-content opt-in, or human labeling.
- Stop immediately if an implementation would broaden risky app support, store raw typed text without opt-in, or count mock fallback as quality proof.

## Remaining Gaps

- No current labeled wrong-topic or assistant-voice dogfood set.
- Accepted-and-kept now uses survival checks but not the research's full 10-minute/send-save horizon.
- Raw-content quality audit requires explicit local opt-in.
- Prompt/chat no-submit and visual proof still need current manual rows before broad claims.
- Mock fallback remains useful for development but cannot count as beta-ready quality evidence.
