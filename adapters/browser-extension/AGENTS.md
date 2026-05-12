# Browser Extension Adapter

This folder is for a WebExtension prototype that can render autocomplete inside browser text surfaces.

- Use content scripts for DOM access.
- Use native messaging only to reach the local macOS app/runtime.
- Start with allowlisted pages while testing.
- Keep all request payloads tiny: text around the caret, field metadata, and geometry.
- Never send password, secure, or hidden-field text.
