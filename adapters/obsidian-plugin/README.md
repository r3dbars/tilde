# Obsidian Adapter

Obsidian uses CodeMirror. That means the reliable path is a real editor extension, not the macOS Accessibility overlay.

This prototype registers a CodeMirror view plugin, renders ghost text as a widget decoration at the cursor, and accepts the next word with `Tab`.

It currently uses a local mock suggestion. The next step is to call the macOS app through a local bridge so the app still owns model runtime, privacy rules, and settings.
