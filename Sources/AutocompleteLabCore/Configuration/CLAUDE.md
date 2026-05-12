# Claude Code Guide

Configuration and product-default policies live here.

Start with:

- `ModelPolicy.swift`
- `SuggestionPrivacyPolicy.swift`
- `TracePrivacyPolicy.swift`
- `CompatibilityProfile.swift`
- `HostCompatibilityPolicy.swift`
- browser, terminal, clipboard, and fallback policy files.

Rules:

- Keep defaults explicit and local-first.
- Do not expose broad model picking during the MVP.
- Keep risky hosts fail-closed until proof exists.
- Add tests for every default, override, allowlist, or blocklist change.
