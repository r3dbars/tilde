# Claude Code Guide

Spike docs and their proof-of-concept notes live here.

A spike is a deliberately throwaway-friendly experiment: a short design doc plus
the smallest code that proves or kills the idea.

Start with:

- `voice-text-loop.md` — fusing dictation (Transcripted) with inline prediction.

Rules:

- Keep language plain and tie the idea back to the typing loop.
- Every spike doc ends with a **graduate or discard** call.
- Keep PoC code behind a flag/protocol seam and isolated to a few files; the doc
  must list what to delete to discard it.
- Do not weaken privacy. Spoken text is at least as sensitive as typed text:
  on-device, opt-in, and covered by the same redaction and sentinel proofs.
- Pending proof stays pending. Do not imply a surface is supported because a
  spike worked in a unit test.
