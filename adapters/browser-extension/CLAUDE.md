# Claude Code Guide

The browser extension prototype lives here.

Start with:

- `manifest.json`
- `background.js`
- `content.js`
- `README.md`

Rules:

- Use content scripts for DOM text surface access.
- Use native messaging only to reach the local macOS app/runtime.
- Start with allowlisted pages.
- Never send password, secure, hidden-field, or unrelated page text.
- Keep payloads tiny: caret context, field metadata, and geometry.
