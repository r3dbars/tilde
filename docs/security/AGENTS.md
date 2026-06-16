# Security Docs Guide

Security (not privacy/no-leak) posture lives here.

- `threat-model.md` is the source of truth for trust boundaries, the adversary model, and ranked
  findings (CRITICAL/HIGH/MEDIUM/LOW with file:line).
- Privacy/no-leak guarantees are proven by the sentinel tests and `docs/product/proof-manifest.json`;
  link to them, do not duplicate them here.
- When you change insertion, app-identity, tracing, capture, event-tap, or model-asset behavior,
  update the matching finding and its status.
- Never paste raw typed text, prompts, model output, or screenshots into these docs.
