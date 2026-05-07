# Implementation Plan

## Product Rule

This should feel like one Mac app.

The user should not start Ollama, llama.cpp, or any model server. Qwen3.5 4B is the MVP model target. MLX is the app-owned runtime.

## Fast Path

1. Build a Swift/AppKit menu bar app.
2. Add a tested core suggestion model.
3. Show mock suggestions near the caret.
4. Add tested accept/dismiss behavior.
5. Add event-tap key capture for `Tab`, backtick, and `Esc`.
6. Add Accessibility insertion.
7. Bootstrap the embedded Qwen3.5 4B MLX runtime, keeping LiteRT-LM as the fallback candidate.
8. Install or repair the app-owned MLX model from Settings when it is missing.
9. Swap the mock engine for the real local engine.

## Latency Target

- debounce typing: 150-250ms
- model output: 1-3 visible words
- generation cap: 9 tokens by default
- prompt context cap: about 900 characters before the cursor
- reasoning: off
- target useful feel: under 700ms
- stretch target: under 300ms after warmup
- default-model proof: `./script/model_latency_report.py --default-model-proof`

## Test Rule

Every slice should have at least one automated test or a build/run verification.

Core behavior gets Swift unit tests. Mac plumbing gets build verification first, then targeted integration checks where possible.

Use `./script/smoke_test.sh` as the fast local loop.
