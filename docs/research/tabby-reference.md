# Tabby Reference Notes

Source: <https://github.com/fujacob/tabby>

License observed: AGPL-3.0, per Tabby's GitHub repository license metadata and README license section.

Use status: public reference only. No Tabby code is copied into this repo.

## Observed Facts

- Tabby is a macOS menu bar app for local-first autocomplete across text fields.
- Its public README describes ghost text near the caret, Tab chunk acceptance, local inference, optional screen/OCR context, and Accessibility/Input Monitoring/Screen Recording permissions.
- Its architecture doc separates lifecycle, UI, OS/runtime services, shared models, and pure support rules.
- Its suggestion loop is roughly: resolve focused field, watch input, gate suggestion requests, run local inference, render ghost text, reconcile live typing, and insert accepted text.
- Its runtime path currently documents Apple Foundation Models and local GGUF models through llama.cpp / llama.swift.

## SteadyType Fit

- Keep the app-owned local runtime path. SteadyType already uses app-owned local model plumbing, so Tabby's GGUF path is a reference, not a migration target.
- Keep pure policy files for deterministic behavior. SteadyType already does this heavily in `AutocompleteLabCore`; new behavior should keep landing there first.
- Treat OCR and visible-screen context as useful but noisy. Sanitize prompt-shaped, terminal-shaped, and UI-chrome text before it reaches the completion prompt.
- Keep acceptance boring and safe: Tab accepts the next word, full accept stays separate, and target-change guards stay strict.

## Non-Fit

- Broad terminal suppression does not directly fit SteadyType because Claude Code and Codex prompt surfaces are explicit proof targets here.
- Tabby's longer ghost-text chunking is a product reference only. SteadyType should stay shorter and calmer until accepted-and-kept data proves otherwise.
- Tabby's AGPL-3.0 code should not be copied into this repo unless the license implications are intentionally accepted.
