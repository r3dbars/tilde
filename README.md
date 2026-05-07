# Transcripted Autocomplete Lab

A standalone Mac lab for testing whether quiet autocomplete makes writing
easier.

This is intentionally separate from Transcripted. The goal is to learn fast
without adding risk or clutter to the main app.

## The Bet

Transcripted helps people get thoughts out.

This app tests the next step: helping people keep typing everywhere without
opening a prompt box.

The magic feeling we are testing:

> You keep writing, and the next useful words quietly appear.

## First MVP

- menu bar Mac app
- reads the active text field through Accessibility
- shows a small suggestion near the cursor
- `Tab` accepts one word
- backtick/tilde accepts the whole visible suggestion
- `Esc` dismisses
- local-only by default
- app-owned MLX runtime
- preferred beta model: Qwen3.5 4B 4-bit
- starts with a small app allowlist

Target apps for the first private beta:

- TextEdit
- Notes
- Chrome local textareas
- Obsidian or another CodeMirror editor
- one Electron writing app for dogfood
- Mail as diagnostics-only

## Model Decision

Run the beta path on Qwen3.5 4B 4-bit through the app-owned MLX runtime.

The expected preferred asset is:

```text
~/Library/Application Support/AutocompleteLab/Models/Qwen35FourB/MLX/Qwen3.5-4B-4bit
```

Users should never need to start a model server. Ollama, llama.cpp, and local
Python download helpers are development tools only, not the product experience.
If the app falls back to mock output, it is not beta-ready.

## Privacy Promise

By default, Autocomplete Lab does not upload typed text, prompts, model output,
accepted text, screenshots, document names, URLs, recipients, or subject lines.

The default trace is redacted and local. Raw text and screenshots are explicit
local debug opt-ins.

Controls live in the menu bar and Diagnostics:

- `Disable <App Name>` turns suggestions off for the current app.
- `Pause Tracing` stops redacted trace writes.
- `Export Report` creates a redacted local report.
- `Delete Traces` removes local trace files.

More detail: `docs/product/privacy-and-controls.md`.

## Readiness

Before a private beta:

```bash
./script/beta_readiness.sh
```

Use these docs as the product gate:

- `docs/product/private-beta-plan.md`
- `docs/product/beta-readiness-checklist.md`
- `docs/product/compatibility-matrix.md`
- `docs/product/eval-and-tracing.md`

## What We Are Not Building Yet

- not a Transcripted feature yet
- not a full Co-Typist clone
- not personalization
- not cloud-first
- not broad app compatibility
- not a polished release

## Success Test

Give it to 4 people for 10 days and ask:

- Did it help?
- Did it interrupt you?
- Did `Tab` feel natural?
- Where did it break?
- Would you miss it if it disappeared?

If the answer is yes and trust stays intact, then we can decide whether it
deserves another beta.
