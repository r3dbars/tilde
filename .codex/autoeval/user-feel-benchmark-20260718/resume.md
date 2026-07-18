# Autoeval Resume: SteadyType user-feel benchmark

- Status: blocked
- Current best: unmodified `99dc4fcb`; post-change benchmark not run
- Primary metric: p50/p95 pause-to-suggestion latency, eligible-pause suggestion-visible rate, suggestion stability, and completion/acceptance quality
- Guardrails: synthetic fixtures only; aggregate metadata only; Tab, Shift-Tab, Escape, secure-field suppression, focus, and insertion behavior must not regress
- Scoring command: `swift run --jobs 1 SteadyTypeReplayEval --fixture docs/evals/typing-replay-fixture.jsonl --engine batch --model gemma-4-e4b-it-optiq --variant both --prompt-format chat-instruct --max-cases 3 --seed 0`
- Editable surface: `TypingReplayEval.swift`, replay CLI plumbing, and aggregate report rendering only; one knob per attempt
- Frozen surface: synthetic fixture corpus, evaluator/scoring rules, privacy gates, keyboard/focus/insertion behavior, and heavyweight Swift proof slot
- Planned knobs: scorecard added but unmeasured; `maxTokens=12` not run; `contextCharacters=240` not run; `fewShotSource=none` not run; `suffix=on` not run
- Last attempt: focused test compile canceled by serialized merger hold at `logs/focused-typing-replay-tests-2.log`; no assertions ran
- Next attempt: after explicit heavyweight-slot release, run focused replay tests, then the fixed batch baseline and each knob once with repeated noisy winners
- Noise rule: repeat noisy runs with the same fixed corpus and command; no raw text or model output in artifacts
