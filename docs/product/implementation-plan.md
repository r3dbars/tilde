# Implementation Plan

## Product Rule

This should feel like one Mac app.

The user should not start Ollama, llama.cpp, Python download scripts, or any
model server during the product flow. The app owns the runtime, the model
folder, readiness checks, and mock-fallback blocking.

Autocomplete Lab is still an experiment, not a committed Transcripted feature.

## Current Runtime Target

The live beta target is Qwen3.5 4B 4-bit through MLX:

```text
~/Library/Application Support/AutocompleteLab/Models/Qwen35FourB/MLX/Qwen3.5-4B-4bit
```

Qwen3.5 9B, Qwen3, and Gemma 4 variants stay available for local trials, but
the beta package should prove readiness against the preferred Qwen3.5 4B asset.

## Fast Path

1. Keep the Swift/AppKit menu bar app tiny.
2. Keep core suggestion logic tested and AppKit-free.
3. Use the app-owned MLX runtime for real suggestions.
4. Block suggestions until the preferred local runtime is ready.
5. Show short suggestions near the caret.
6. Let `Tab` accept one word.
7. Let the key above `Tab` accept the whole visible suggestion.
8. Let `Esc` dismiss and quiet the field.
9. Verify insertion and block fields/apps after trust failures.
10. Export only redacted local reports for beta review.

## Redacted Telemetry Architecture

Default telemetry is a local redacted trace:

```text
~/Library/Logs/AutocompleteLab/traces.jsonl
```

It may store counts, lengths, timings, app bundle IDs, field kind, render mode,
insertion mode, request mode, model name, experiment arm, HMAC fingerprints, and
accepted-and-kept survival classes.

It must not store typed text, prompts, raw model output, accepted text,
screenshots, document names, URLs, recipients, or subject lines by default.

Raw debug tracing is a separate local opt-in file:

```text
~/Library/Logs/AutocompleteLab/raw-traces.jsonl
```

Screenshots are local, per-app, and debug-only. Beta reports should use the
redacted Diagnostics export.

## Latency Target

- debounce typing: 15ms current beta default,
- visible output: 1-3 words by default,
- generation cap: 9 tokens current beta default,
- reasoning: off,
- supported gate: p95 first-visible at or below 750ms,
- caveated gate: p95 first-visible at or below 1000ms.

Longer suggestions belong only in explicit experiments.

## Beta Readiness Rule

Before inviting testers, run:

```bash
./script/beta_readiness.sh
```

That gate must pass smoke tests, manual app proof, trace eval self-tests,
runtime readiness, release packaging, and private-beta packet checks.

Stop if the app uses mock output, asks testers to manage a model server, or
shows suggestions in blocked field kinds.

## Test Rule

Every meaningful behavior change gets an automated test, script self-test, or
build/run verification.

Use the fast local loop:

```bash
./script/smoke_test.sh
```

Use trace proof before changing compatibility status:

```bash
./script/check_trace_eval.sh
```
