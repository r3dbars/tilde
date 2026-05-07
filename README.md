# Transcripted Autocomplete Lab

A standalone lab for testing a Co-Typist-style Mac autocomplete experience.

This is intentionally separate from Transcripted. The goal is to learn fast without adding risk or clutter to the main app.

## The Bet

Transcripted helps people get thoughts out.

This app explores the next step: helping people keep typing everywhere without opening a prompt box.

The magic feeling we are testing:

> You keep writing, and the next useful words quietly appear.

## First MVP

- menu bar Mac app
- reads the active text field through Accessibility
- shows a small floating suggestion near the cursor
- `Tab` accepts one word
- backtick/tilde accepts the whole visible suggestion
- `Esc` dismisses
- local-only by default
- default model target: Qwen3.5 4B on Apple Silicon
- starts with a small app allowlist

Target apps for the first pass:

- TextEdit
- Notes
- Obsidian
- Mail

## Model Decision

Run the MVP on Qwen3.5 4B.

The first beta target is macOS 26 on Apple Silicon. The app should not expose a broad model picker yet. The product question is whether the typing experience feels useful, so the model layer should stay boring: local, warm, short completions, and tuned for speed.

Users should never need to start a model server. The model runtime is owned by the app. If a local server is used during development, it is only a private benchmark tool, not part of the product experience.

## What We Are Not Building Yet

- not a Transcripted feature yet
- not a full Co-Typist clone
- not personalization
- not cloud-first
- not broad app compatibility
- not a polished release

## Success Test

Give it to 3-5 people for a week and ask:

- Did it help?
- Did it interrupt you?
- Did `Tab` feel natural?
- Where did it break?
- Would you miss it if it disappeared?

If the answer is yes, then we can decide whether it graduates into Transcripted.
