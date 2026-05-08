# Transcripted Autocomplete Lab

A standalone lab for testing a Co-Typist-style Mac autocomplete experience.

This is intentionally separate from Transcripted. The goal is to learn fast without adding risk or clutter to the main app.

## The Bet

Transcripted helps people get thoughts out.

This app explores the next step: helping people keep typing in a few proven writing contexts without opening a prompt box.

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
- starts with a small app allowlist

Target apps for the first pass:

- TextEdit
- Notes
- Obsidian
- Chrome text fields

Diagnostics-only until same-slice one-word no-submit proof exists:

- Codex prompt fields

Claude desktop is limited to one-word proof-gated acceptance; full accept stays
off until separate no-submit proof exists.

Mail is diagnostics-only until compose insertion is proven safe. Claude Code
CLI sessions are also diagnostics-only for now because the live typing surface
is a terminal host, not the background-only `com.anthropic.claude-code` bundle.

## Model Decision

Run the MVP on Qwen3.5 4B through MLX.

The first supported hardware target is Apple Silicon with 16 GB RAM. The app should not expose a broad model picker yet. The product question is whether the typing experience feels useful, so the model layer should stay boring: local, warm, short completions, and tuned for speed.

Users should never need to start a model server. The model runtime is owned by the app. Any Ollama or llama.cpp run is only a private benchmark tool, not part of the product experience.

## Permissions And Local-First Behavior

Accessibility is required so the app can see the focused text field, find the cursor, and insert text only when the user accepts a suggestion. The app should explain this before opening System Settings.

Screen Recording is not required for normal autocomplete. It is only for optional local placement diagnostics when screenshot proof is explicitly enabled.

Suggestions run locally after the model is installed. Installing the default model downloads files from Hugging Face once. Redacted diagnostics stay on the Mac unless the user chooses to share an exported privacy bundle.

The user can pause suggestions, block the current app, delete local traces, and remove local model files from the model folder.

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
