# Implementation Plan

## Product Rule

This should feel like one Mac app.

The user should not start Ollama, llama.cpp, or any model server. Gemma 4 E2B is the MVP model target, but the runtime must be owned by the app.

## Fast Path

1. Build a Swift/AppKit menu bar app.
2. Add a tested core suggestion model.
3. Show mock suggestions near the caret.
4. Add tested accept/dismiss behavior.
5. Add Accessibility insertion.
6. Benchmark embedded Gemma 4 E2B runtime options.
7. Swap the mock engine for the real local engine.

## Latency Target

- debounce typing: 150-250ms
- model output: 2-8 words
- generation cap: 8-16 tokens
- reasoning: off
- target useful feel: under 700ms
- stretch target: under 300ms after warmup

## Test Rule

Every slice should have at least one automated test or a build/run verification.

Core behavior gets Swift unit tests. Mac plumbing gets build verification first, then targeted integration checks where possible.
