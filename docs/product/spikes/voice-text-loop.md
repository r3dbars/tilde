# Dormant Voice-Context Seam

Status: isolated core research, off by default, not wired into the app, and not
part of the SteadyType product surface.

This short record remains because source and tests link to it. The seam lets a
bounded, explicitly provided list of recent spoken snippets participate in the
existing local n-gram predictor. It adds no audio capture, Transcripted
dependency, network path, or app-runtime integration.

## What Exists

- `RecentSpokenTranscriptProviding`
- `RecentSpokenContextPolicy`, disabled by default
- `VoiceContextPhrasePredictor`
- deterministic fixtures and core tests

The implementation lives in
`Sources/AutocompleteLabCore/Engine/VoiceContextPhrasePredictor.swift`; tests
live in `Tests/AutocompleteLabCoreTests/VoiceContextPhrasePredictorTests.swift`.

## Product Decision

Do not graduate this seam while the product mandate is a lightweight core
writing assistant. Any future proposal must first define an explicit local
opt-in, retention and deletion behavior, redacted diagnostics, app-owned data
transport, and proof that sensitive or prompt fields cannot consume the data.

Until then, the provider stays absent in the live app and the policy stays off.
