# Claude Code Guide

Pure Swift experiment helpers live here.

Use this folder for:

- eval plans
- quality scoring
- deterministic assignment
- offline model-quality comparisons

Rules:

- Keep it AppKit-free.
- Do not store raw user text.
- Treat small samples as directional.
- Write results into docs only after separating harness scores from real-app dogfood.
