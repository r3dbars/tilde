# Claude Code Guide

Security review notes live here.

Start with:

- `threat-model.md`: trust surface, assets, adversaries (forged local app / local same-user
  process / network MITM), and the ranked findings table (F1–F6) with fix status.

Rules:

- Keep it short and decision-oriented; separate proven/fixed from recommended-not-done.
- This is the *security* surface; privacy no-leak guarantees stay in the sentinel tests and
  `docs/product/proof-manifest.json`.
- Update the relevant finding whenever insertion, identity, tracing/capture, the event tap, or
  model-asset handling changes, and add a regression test with the fix.
- Do not paste private typed text, prompts, model output, or raw screenshots into docs.
