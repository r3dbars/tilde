# Transcripted Autocomplete Lab

A standalone lab for testing a Co-Typist-style Mac autocomplete experience.

This is intentionally separate from Transcripted. The goal is to learn fast without adding risk or clutter to the main app.

## The Bet

Transcripted helps people get thoughts out.

This app explores the next step: helping people keep typing in a few proven writing apps without opening a prompt box.

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
- default model target: Qwen3.5 4B on Apple Silicon / 16 GB
- starts with suggestions paused and suggestion-capable apps blocked until explicitly enabled

Target apps for the first pass:

- TextEdit
- Notes title, body, and checklist surfaces
- Obsidian disposable notes
- Chrome local text fields and local editor fixtures
- Codex, Claude Code, and Claude prompt fields only after no-submit proof

Mail is diagnostics-only until compose insertion is proven safe.

## Model Decision

Run the MVP on Qwen3.5 4B through MLX.

The first supported hardware target is Apple Silicon with 16 GB RAM. The app should not expose a broad model picker yet. The product question is whether the typing experience feels useful, so the model layer should stay boring: local, warm, short completions, and tuned for speed.

Users should never need to start a model server. The model runtime is owned by the app. Any Ollama or llama.cpp run is only a private benchmark tool, not part of the product experience.

Current lab build:

- uses the app-owned MLX runtime when the Qwen3.5 4B asset is ready
- keeps suggestions off while the model is missing, warming, invalid, or failed
- treats mock fallback as development-only and not beta-ready
- exposes privacy/runtime toggles from the menu bar
- keeps typed text local

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
