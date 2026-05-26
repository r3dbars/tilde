# TypeAhead-Inspired Implementation Plan

Date: 2026-05-26

Goal: adapt useful public TypeAhead lessons without copying UI, copy,
branding, trade dress, code, assets, or broad claims.

## Product Bets

1. Make silence understandable.
2. Keep `Tab` safe: one word only.
3. Keep full accept separate.
4. Keep support proof-gated.
5. Keep privacy proof local and visible.

## Shipped This Pass

### Plain Silence Explanations

Problem:

Internal block reasons like `blockedFieldKind` are useful for traces, but bad
for a beta tester. TypeAhead's public docs show the need for clear failure
states, but I did not find an in-app "why no suggestion?" proof surface.

Change:

- Add `SuggestionSilenceExplanationPolicy`.
- Map activation blocks to calm user-facing reasons:
  - search fields stay quiet,
  - URL and address fields stay quiet,
  - forms stay quiet,
  - secure field,
  - surface needs proof first,
  - unknown field needs proof first,
  - waiting for more context,
  - word still forming,
  - sensitive text detected.
- Use the plain reason in the app decision text.
- Keep raw trace reason codes unchanged.

Files:

- `Sources/AutocompleteLabCore/Session/SuggestionSilenceExplanationPolicy.swift`
- `Tests/AutocompleteLabCoreTests/SuggestionSilenceExplanationPolicyTests.swift`
- `Sources/AutocompleteLabApp/App/AppDelegate.swift`

## Next Small Pass

### Field Status Reason Tooltip

Show the same silence explanation in the field badge tooltip, not just the
diagnostics text.

Candidate files:

- `Sources/AutocompleteLabApp/UI/FieldStatusIndicatorController.swift`
- `Sources/AutocompleteLabApp/App/AppDelegate.swift`
- `Tests/AutocompleteLabAppTests/FieldStatusIndicator...`

Proof:

- app tests for tooltip/accessibility label state,
- manual TextEdit and Chrome fixture pass.

### Runtime/Privacy Proof Card

TypeAhead's strongest wedge is "local." SteadyType should show current proof
without broad claims:

- runtime: local MLX ready/missing/repairing,
- model revision/checksum receipt state,
- redacted trace mode,
- raw trace off/on,
- network proof command reference.

Candidate files:

- `Sources/AutocompleteLabApp/UI/SettingsWindowController.swift`
- `Sources/AutocompleteLabApp/UI/DiagnosticsWindowController.swift`
- `docs/product/privacy-and-controls.md`

Proof:

- settings snapshot tests,
- `./script/check_current_build_privacy_export.sh`,
- `./script/check_runtime_network_egress.py`.

### Non-Annoyance Persistence

Keep a suggestion stable long enough for a human to accept, but hide fast when
typing clearly moves on.

Candidate files:

- `Sources/AutocompleteLabCore/Session/VisibleSuggestionPersistencePolicy.swift`
- `Sources/AutocompleteLabCore/Session/SuggestionTypingProgressPolicy.swift`
- `Sources/AutocompleteLabCore/Session/TypingBurstPolicy.swift`

Proof:

- unit tests for stale-vs-stable suggestions,
- trace replay with typed-over and accepted-kept slices.

## Explicit Avoids

- Do not switch `Tab` to full accept.
- Do not claim broad browser or Google Docs support.
- Do not add cloud fallback.
- Do not add default personalization.
- Do not add TypeAhead-like landing-page copy or visuals.
- Do not make speed, legal, medical, or compliance claims without current proof.
