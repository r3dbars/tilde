# SteadyType

![SteadyType cover](Assets/GitHub/steadytype-cover.png)

SteadyType is a small Mac app for quiet writing suggestions near your cursor.

It watches the active text field, shows a short suggestion, and only inserts text when you accept it. The question for this beta is simple: does this make writing feel easier, or does it get in the way?

Current dogfood stance: suggestions are default-on for normal text fields, with
hard blocks kept for secure and high-risk system surfaces. If a specific app
has bad placement or insertion, pause that app, capture a screenshot, and add a
small compatibility fix.

## What It Does

- runs as a macOS menu bar app
- reads the focused text field through Accessibility
- shows a small suggestion near the cursor
- uses `Tab` to accept one word
- uses `Shift-Tab` to accept the whole visible suggestion
- uses `Esc` to dismiss
- runs local-first by default
- tries generic Accessibility support by default, then lets you pause bad apps

## Current Dogfood Scope

The first supported targets still have the best proof:

- TextEdit
- Apple Notes
- Obsidian
- Chrome local textarea/contenteditable practice fixtures
- Codex
- Claude desktop
- Claude Code in supported terminal hosts

Everything else uses a generic Accessibility path unless it is hard-denied or a
field is classified as unsafe. Prompt and terminal apps stay one-word and
fail-closed where possible; screenshots from bad apps become the adapter queue.

## Privacy

SteadyType is local-first. Typed text, prompts, model output, accepted text, screenshots, document names, URLs, recipients, and subject lines are not uploaded by default.

Diagnostics are local and redacted unless a tester explicitly opts into a short-lived raw or screenshot trace for debugging.

## Personal Capture

Personal Capture is a local, opt-in Justin dogfood loop. It writes daily
Markdown on this Mac so the app can learn from real writing and accepted-kept
suggestions. It is not telemetry, not a beta requirement, and not enabled for
customers or testers by default.

When enabled, it also writes local Suggestion Episode JSONL and a daily
scorecard. Those files connect what was typed, what SteadyType suggested, what
the user did, model/prompt version, placement, latency, and kept checkpoints.

Useful docs:

- [Beta privacy](PRIVACY-BETA.md)
- [Known limitations](KNOWN-LIMITATIONS.md)
- [Diagnostic export](DIAGNOSTIC-EXPORT.md)
- [Personal Capture](docs/product/personal-capture.md)
- [Daily Driver Phrase Mode](docs/product/daily-driver-phrase-mode.md)
- [Uninstall and delete data](UNINSTALL-DELETE-DATA.md)

## Runtime

The app owns the model runtime. Testers should not need to start Ollama, llama.cpp, Python, or any other server.

The current local runtime path uses MLX on Apple Silicon and downloads one pinned default model revision once. The beta gate checks the local checksum receipt before calling the model ready.

## What This Is Not

- not part of another product yet
- not a cloud-first writing assistant
- not personalization
- not a broad compatibility claim
- not a full release

## Development

```bash
swift test
./script/check_test_coverage_manifest.sh
./script/build_and_run.sh --verify
```

Full private beta validation lives in:

```bash
./script/beta_readiness.sh
```

The repo also includes smoke tests, privacy checks, runtime checks, proof manifests, and visual placement evidence under `script/` and `docs/product/`.
