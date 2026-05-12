# Claude Code Guide

Experimental editor adapters live here.

Adapter map:

- `browser-extension/`: WebExtension prototype.
- `obsidian-plugin/`: Obsidian/CodeMirror prototype.

Rules:

- Keep adapters small and easy to delete.
- Treat the macOS app as runtime and policy owner.
- Do not move local model execution into adapters.
- Do not persist typed text in adapter code.
