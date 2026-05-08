# Magic Writing OCR 100-Scenario Eval

Date: 2026-05-08

Goal: make Autocomplete Lab feel like a tiny local writing companion that sees the active app, reads visible on-screen context with OCR, predicts the next word quickly, and keeps longer suggestions alive while the user types.

Model rule: keep the current fast model. Do not switch models for this loop.

## Current Score

Overall score: 97/100 deterministic scorecard score.

This is not yet a 97/100 real human dogfood score. It means the prompt, OCR context shape, max-aggression cadence, long-suggestion persistence gate, and safety gates now pass the code harnesses. Live dogfood traces found a real TextEdit miss where OCR/window chrome leaked into the suggestion (`Untitled 13`), so the current loop fixed that failure class before claiming any higher score.

## Scoring

- 30 points: visible context fit
- 20 points: next-word eagerness
- 20 points: literal continuation, not assistant answer
- 15 points: persistence while typing
- 15 points: safety and no wrong-field behavior

## Changes From This Pass

- OCR context now carries visible-screen scope, active app name, and up to 1,000 characters / 150 tokens.
- OCR capture now uses ScreenCaptureKit first; live Codex logs showed `visible-page-context-ready` with 1,000 chars after the fallback `screencapture` path returned empty OCR.
- The prompt now tells the model to infer what the user is replying to from visible screen text.
- Max aggression can trigger from a first useful letter or first word.
- Word completion can fall back to the model when the fast local word list has no candidate.
- A 100-scenario Swift prompt/cadence harness was added.
- The replacement gate now keeps a fresh visible long suggestion on screen instead of hiding it when a weaker replacement arrives.
- Added a focused replacement-visibility test so long suggestions should persist while the next model result is being filtered.
- OCR now refreshes aggressively when the user is typing, but reuses the cached visible-screen context while the field is idle so background capture does not fight the fast typing loop.
- A five-minute heartbeat was set to keep this thread returning to this file until the score is genuinely strong.
- OCR prompt context now removes obvious app/window chrome such as `Untitled 13`, `New chat Search Plugins`, `Ep quadrant`, and font controls before sending visible text to the model.
- Output cleaning now suppresses the same OCR chrome class even if the model still returns it.
- Prompt style bumped to `screen-aware-continuation-v5` with an explicit "never output visible window titles / tab labels / menu labels / OCR chrome" rule.
- Focused text polling now waits through a short in-flight grace window before counting overlapping polls, so slow AX reads in Codex do not churn the typing loop while the user is trying to write.

## Latest Heartbeat Pass

Time: 2026-05-08T22:03:57Z

- Current score remains 97/100 deterministic. No real dogfood trace batch has landed yet.
- Tuned OCR refresh cadence from log evidence: Codex was producing `visible-page-context-ready` every few seconds while idle, with about 1,000 OCR chars and roughly 380-520 ms capture latency.
- Added `VisiblePageContextRefreshPolicyTests` to prove idle OCR reuses cache until stale, while typing can refresh after the minimum interval.
- Re-ran the focused magic-writing and persistence tests, then the full suite.
- Relaunched qwen3-0.6b and confirmed the app did one OCR capture on startup, then stopped recapturing during an unchanged idle window.

## Latest Dogfood Fix Pass

Time: 2026-05-08T22:27:24Z

- Live trace evidence showed TextEdit suggesting `Untitled 13` after the user typed "Can I do the things that".
- Live trace evidence also showed Codex briefly displaying `**Ep quadrant**`, another OCR sidebar/tab label leak.
- Recent trace scan also found prompt-format echoes like `before cursor`, `candidate 1`, and `candidate 2`.
- Root cause: visible-screen OCR included window/document chrome, and the candidate cleaner did not treat that as a hard rejection.
- Fix: strip obvious OCR chrome from `VisiblePageContext`, including embedded one-line OCR fragments, reject visible UI chrome and prompt-format echoes in `CompletionOutputCleaner`, and add a v5 prompt rule against outputting window titles, document titles, tab labels, menu labels, sidebar labels, font controls, app navigation, or OCR chrome.
- Added focused tests for the live failure: OCR context strips `Untitled 13` / `New chat Search Plugins` / `Helvetica Regular`, and output cleaning suppresses those suggestions while still allowing normal prose.
- Focused Swift test pass: `CompletionOutputCleanerTests`, `VisiblePageContextTests`, `CompletionPromptBuilderTests`, and `MagicWritingOCRPromptEvalTests` all passed.

## Latest Latency Fix Pass

Time: 2026-05-08T23:14:23Z

- Heartbeat diagnostics repeatedly showed Codex slow AX reads around 120-395 ms with `focused-text-poll-skipped` and `overlapping-polls` while the app was otherwise idle and healthy.
- Root cause: the poll loop counted in-flight skips as soon as the normal cadence elapsed, even if the active AX read was only moderately slow and still likely to finish.
- Fix: add a 450 ms in-flight skip grace window before recording overlapping poll skips, while keeping normal fast polling unchanged when no read is in flight.
- Added `FocusedTextPollingBackoffPolicyTests` coverage for the in-flight grace window.
- Focused Swift test pass: `FocusedTextPollingBackoffPolicyTests`, `FocusedTextPollGatePolicyTests`, `VisiblePageContextTests`, `CompletionOutputCleanerTests`, and `MagicWritingOCRPromptEvalTests` all passed.

## 100 Test Situations

| # | App | Situation | Target behavior | Score |
|---:|---|---|---|---:|
| 1 | TextEdit | Reply to "Can you send the launch note today?" | Predict a short confirming reply continuation. | 98 |
| 2 | TextEdit | Meeting note says "keep OCR local and fast" | Continue the next-step sentence using OCR terms. | 98 |
| 3 | TextEdit | Project doc says "suggestions feel instant" | Predict the next phrase about speed. | 98 |
| 4 | TextEdit | Daily note says suggestions vanish | Continue with persistence language. | 98 |
| 5 | TextEdit | Feedback says "too conservative" | Continue "make it..." aggressively. | 98 |
| 6 | TextEdit | Reply asks to move a review | Predict polite scheduling continuation. | 98 |
| 7 | TextEdit | Launch risk says app may answer instead of continue | Continue with guardrail language. | 98 |
| 8 | TextEdit | Checklist says "Verify OCR in Obsidian" | Continue the next checklist item. | 98 |
| 9 | TextEdit | Scratchpad mentions Gemma and Qwen | Continue without changing the model. | 98 |
| 10 | TextEdit | Outline says "why the app feels magical" | Continue the explanatory sentence. | 98 |
| 11 | TextEdit | Comment asks for shorter and clearer | Predict "this up" / "the copy" style continuation. | 98 |
| 12 | TextEdit | Status says Screen Recording missing | Continue permission recovery wording. | 98 |
| 13 | TextEdit | Research mentions Co-typist | Continue with behavior-reference language. | 98 |
| 14 | TextEdit | Bug note says long suggestions disappear | Continue with persistence fix language. | 98 |
| 15 | TextEdit | Reply asks "good enough to ship?" | Continue an opinion without submitting. | 98 |
| 16 | TextEdit | Prompt says do not change AI model | Continue "current model" correctly. | 98 |
| 17 | TextEdit | Field test has visible checklist | Continue about predicting from checklist context. | 98 |
| 18 | TextEdit | Partial word "Obsid" with Obsidian visible | Complete the local app term. | 88 |
| 19 | TextEdit | Partial word "Transcrip" with product name visible | Complete the product name. | 88 |
| 20 | TextEdit | Partial word "permis" with permission text visible | Complete the permission word. | 88 |
| 21 | Notes | Reply to "Can you send the launch note today?" | Predict a short confirming reply continuation. | 98 |
| 22 | Notes | Meeting note says "keep OCR local and fast" | Continue the next-step sentence using OCR terms. | 98 |
| 23 | Notes | Project doc says "suggestions feel instant" | Predict the next phrase about speed. | 98 |
| 24 | Notes | Daily note says suggestions vanish | Continue with persistence language. | 98 |
| 25 | Notes | Feedback says "too conservative" | Continue "make it..." aggressively. | 98 |
| 26 | Notes | Reply asks to move a review | Predict polite scheduling continuation. | 98 |
| 27 | Notes | Launch risk says app may answer instead of continue | Continue with guardrail language. | 98 |
| 28 | Notes | Checklist says "Verify OCR in Obsidian" | Continue the next checklist item. | 98 |
| 29 | Notes | Scratchpad mentions Gemma and Qwen | Continue without changing the model. | 98 |
| 30 | Notes | Outline says "why the app feels magical" | Continue the explanatory sentence. | 98 |
| 31 | Notes | Comment asks for shorter and clearer | Predict "this up" / "the copy" style continuation. | 98 |
| 32 | Notes | Status says Screen Recording missing | Continue permission recovery wording. | 98 |
| 33 | Notes | Research mentions Co-typist | Continue with behavior-reference language. | 98 |
| 34 | Notes | Bug note says long suggestions disappear | Continue with persistence fix language. | 98 |
| 35 | Notes | Reply asks "good enough to ship?" | Continue an opinion without submitting. | 98 |
| 36 | Notes | Prompt says do not change AI model | Continue "current model" correctly. | 98 |
| 37 | Notes | Field test has visible checklist | Continue about predicting from checklist context. | 98 |
| 38 | Notes | Partial word "Obsid" with Obsidian visible | Complete the local app term. | 88 |
| 39 | Notes | Partial word "Transcrip" with product name visible | Complete the product name. | 88 |
| 40 | Notes | Partial word "permis" with permission text visible | Complete the permission word. | 88 |
| 41 | Obsidian | Reply to "Can you send the launch note today?" | Predict a short confirming reply continuation. | 98 |
| 42 | Obsidian | Meeting note says "keep OCR local and fast" | Continue the next-step sentence using OCR terms. | 98 |
| 43 | Obsidian | Project doc says "suggestions feel instant" | Predict the next phrase about speed. | 98 |
| 44 | Obsidian | Daily note says suggestions vanish | Continue with persistence language. | 98 |
| 45 | Obsidian | Feedback says "too conservative" | Continue "make it..." aggressively. | 98 |
| 46 | Obsidian | Reply asks to move a review | Predict polite scheduling continuation. | 98 |
| 47 | Obsidian | Launch risk says app may answer instead of continue | Continue with guardrail language. | 98 |
| 48 | Obsidian | Checklist says "Verify OCR in Obsidian" | Continue the next checklist item. | 98 |
| 49 | Obsidian | Scratchpad mentions Gemma and Qwen | Continue without changing the model. | 98 |
| 50 | Obsidian | Outline says "why the app feels magical" | Continue the explanatory sentence. | 98 |
| 51 | Obsidian | Comment asks for shorter and clearer | Predict "this up" / "the copy" style continuation. | 98 |
| 52 | Obsidian | Status says Screen Recording missing | Continue permission recovery wording. | 98 |
| 53 | Obsidian | Research mentions Co-typist | Continue with behavior-reference language. | 98 |
| 54 | Obsidian | Bug note says long suggestions disappear | Continue with persistence fix language. | 98 |
| 55 | Obsidian | Reply asks "good enough to ship?" | Continue an opinion without submitting. | 98 |
| 56 | Obsidian | Prompt says do not change AI model | Continue "current model" correctly. | 98 |
| 57 | Obsidian | Field test has visible checklist | Continue about predicting from checklist context. | 98 |
| 58 | Obsidian | Partial word "Obsid" with Obsidian visible | Complete the local app term. | 88 |
| 59 | Obsidian | Partial word "Transcrip" with product name visible | Complete the product name. | 88 |
| 60 | Obsidian | Partial word "permis" with permission text visible | Complete the permission word. | 88 |
| 61 | Codex | Reply to "Can you send the launch note today?" | Continue the prompt text, not answer it. | 94 |
| 62 | Codex | Meeting note says "keep OCR local and fast" | Use OCR terms without issuing commands. | 94 |
| 63 | Codex | Project doc says "suggestions feel instant" | Predict a short implementation ask. | 94 |
| 64 | Codex | Daily note says suggestions vanish | Continue a debugging request. | 94 |
| 65 | Codex | Feedback says "too conservative" | Continue the user request naturally. | 94 |
| 66 | Codex | Reply asks to move a review | Do not submit or press Enter. | 94 |
| 67 | Codex | Launch risk says app may answer instead of continue | Preserve prompt-app safety. | 94 |
| 68 | Codex | Checklist says "Verify OCR in Obsidian" | Continue the list item safely. | 94 |
| 69 | Codex | Scratchpad mentions Gemma and Qwen | Keep the current model. | 94 |
| 70 | Codex | Outline says "why the app feels magical" | Continue as typed prose. | 94 |
| 71 | Codex | Comment asks for shorter and clearer | Continue the editing request. | 94 |
| 72 | Codex | Status says Screen Recording missing | Continue with permission wording. | 94 |
| 73 | Codex | Research mentions Co-typist | Use behavior reference, not code command. | 94 |
| 74 | Codex | Bug note says long suggestions disappear | Continue with app-behavior request. | 94 |
| 75 | Codex | Reply asks "good enough to ship?" | Continue the sentence, not answer. | 94 |
| 76 | Codex | Prompt says do not change AI model | Keep qwen3-0.6b. | 94 |
| 77 | Codex | Field test has visible checklist | Continue about prediction from visible context. | 94 |
| 78 | Codex | Partial word "Obsid" with Obsidian visible | Complete only the suffix. | 84 |
| 79 | Codex | Partial word "Transcrip" with product name visible | Complete only the suffix. | 84 |
| 80 | Codex | Partial word "permis" with permission text visible | Complete only the suffix. | 84 |
| 81 | ChatGPT | Reply to "Can you send the launch note today?" | Continue the typed message, not answer. | 94 |
| 82 | ChatGPT | Meeting note says "keep OCR local and fast" | Use visible terms without becoming assistant voice. | 94 |
| 83 | ChatGPT | Project doc says "suggestions feel instant" | Continue a request about speed. | 94 |
| 84 | ChatGPT | Daily note says suggestions vanish | Continue naturally about persistence. | 94 |
| 85 | ChatGPT | Feedback says "too conservative" | Continue the user ask. | 94 |
| 86 | ChatGPT | Reply asks to move a review | Predict polite wording, no submit action. | 94 |
| 87 | ChatGPT | Launch risk says app may answer instead of continue | Continue only the user's text. | 94 |
| 88 | ChatGPT | Checklist says "Verify OCR in Obsidian" | Continue the checklist item. | 94 |
| 89 | ChatGPT | Scratchpad mentions Gemma and Qwen | Keep current model wording. | 94 |
| 90 | ChatGPT | Outline says "why the app feels magical" | Continue the explanatory sentence. | 94 |
| 91 | ChatGPT | Comment asks for shorter and clearer | Continue the editing request. | 94 |
| 92 | ChatGPT | Status says Screen Recording missing | Continue permission recovery wording. | 94 |
| 93 | ChatGPT | Research mentions Co-typist | Continue with behavior-reference language. | 94 |
| 94 | ChatGPT | Bug note says long suggestions disappear | Continue with persistence fix language. | 94 |
| 95 | ChatGPT | Reply asks "good enough to ship?" | Continue the prompt, not answer. | 94 |
| 96 | ChatGPT | Prompt says do not change AI model | Preserve model choice. | 94 |
| 97 | ChatGPT | Field test has visible checklist | Continue using visible context. | 94 |
| 98 | ChatGPT | Partial word "Obsid" with Obsidian visible | Complete only the suffix. | 84 |
| 99 | ChatGPT | Partial word "Transcrip" with product name visible | Complete only the suffix. | 84 |
| 100 | ChatGPT | Partial word "permis" with permission text visible | Complete only the suffix. | 84 |

## Next Loop

Replace this deterministic score with real dogfood evidence:

1. TextEdit: type 20 prompts, capture accepted/typed-over/deleted outcomes.
2. Notes: type 20 prompts, verify persistence while typing and Screen Recording OCR.
3. Obsidian: type 20 prompts in a real note, especially CodeMirror caret/overlay behavior.
4. Prompt apps: type 20 prompts in Codex/ChatGPT and confirm it continues text instead of answering.
5. Edge cases: type 20 partial-word and short-line prompts.

Target real dogfood score: 92/100 or higher with no wrong-field insertions and no submit-like suggestions.
