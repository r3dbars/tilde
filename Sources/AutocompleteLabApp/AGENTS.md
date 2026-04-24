# AutocompleteLabApp Guide

This target owns the macOS app.

- Keep AppKit code out of the core target.
- Prefer small controllers over one giant delegate.
- The user should see one app, not runtime plumbing.
