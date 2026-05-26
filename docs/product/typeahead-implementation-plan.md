# TypeAhead-Informed Implementation Plan

Reviewed: 2026-05-26

## Product Bet

Do not chase "works everywhere." Win on trust.

TypeAhead's public positioning shows the appeal of a native-feeling Mac autocomplete loop. The safer SteadyType move is a smaller loop with stronger proof:

- short suggestions,
- one-word `Tab`,
- clear dismiss/pause,
- local-first runtime,
- visible reasons when SteadyType stays quiet,
- narrow app support until proof says otherwise.

## Shipped In This Pass

1. Added a pure policy for human silence explanations.
2. Wired activation-policy blocks to show plain user-facing reasons in Settings/menu status.
3. Kept raw trace `reason` stable while adding separate `silenceExplanation` metadata.
4. Split "no editable text field" from "secure field" in app status.
5. Changed default visible suggestion length from 8 words to 3 words.
6. Updated product docs to say 1-3 words by default.
7. Added a Settings privacy proof line for app-owned local model use, raw-text default-off, and redacted Privacy Bundles.
8. Fixed the TextEdit real-app smoke helper path so AX-based synthetic proof seeding no longer calls a missing function.

## Next Best Follow-Ups

1. Show the silence explanation as a tooltip on the field status indicator.
2. Add a bounded real TextEdit trace proving default suggestions are 1-3 words.
3. Refresh the stale TextEdit model-latency proof; the live proof still failed on app focus / missing model timing.
4. Refresh scorecards after a current build/smoke pass.
5. Leave browser production fields, prompt apps, and chat apps blocked or proof-only.

## Do Not Do Yet

- Do not add broad browser support.
- Do not build true inline ghost text.
- Do not add cloud fallback.
- Do not market personalization.
- Do not raise beta readiness without current proof gates.
