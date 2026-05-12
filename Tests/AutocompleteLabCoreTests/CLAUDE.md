# Claude Code Guide

Core-target tests live here.

Use this folder for:

- session and keyboard policy
- insertion and acceptance safety
- text splitting and redaction
- geometry and placement
- completion engine behavior
- trace analysis and proof metadata
- compatibility and configuration defaults

Rules:

- Tests should be deterministic and AppKit-free where possible.
- Add Unicode and sensitive-field cases when changing text or privacy policy.
- Keep proof-gate failures explicit instead of weakening assertions to pass.
