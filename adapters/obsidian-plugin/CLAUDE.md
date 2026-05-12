# Claude Code Guide

The Obsidian adapter prototype lives here.

Start with:

- `manifest.json`
- `main.ts`
- `README.md`

Rules:

- Use Obsidian editor APIs and CodeMirror decorations.
- Do not mutate Obsidian DOM outside CodeMirror.
- Keep local model execution in the macOS app.
- Focus on native-looking ghost text in the editor before broad Obsidian support.
