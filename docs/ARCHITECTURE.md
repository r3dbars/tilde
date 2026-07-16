# Architecture

SteadyType is one macOS menu bar app with an app-owned local model runtime. Its
core loop is intentionally small:

1. Read the focused editable field and caret through Accessibility.
2. Build a bounded completion request.
3. Apply pure safety, compatibility, and presentation policies.
4. Generate a local suggestion and show it near the caret.
5. Insert only after an explicit `Tab` or `Shift-Tab`, then verify the target.
6. Dismiss on `Esc`, continued typing, focus changes, or a failed guard.

## Package Boundaries

- `Sources/AutocompleteLabCore/` contains deterministic policy and value types.
  It must not depend on AppKit, Accessibility, screenshots, process control, or
  MLX effects.
- `Sources/AutocompleteLabApp/` owns app startup, native macOS effects, UI,
  Accessibility, keyboard capture, insertion, redaction, and the MLX runtime.
- `Sources/AutocompleteTraceReplay/` replays already-redacted traces locally.
- `Sources/SteadyTypeTextEventHelper/` is a narrow app-owned helper.

The internal target names retain `AutocompleteLab` for package compatibility;
the product is SteadyType.

## Safety And Privacy Boundaries

- Secure and sensitive fields are blocked before compatibility fallback is
  considered.
- Unknown apps may use the conservative generic Accessibility path, but that is
  not a support claim. Support requires current app-specific proof.
- Prompt, send, terminal, and hosted browser surfaces remain guarded or blocked
  until their exact layout has no-submit and insertion proof.
- Diagnostics are local and redacted by default. Raw text and screenshots are
  time-limited, explicit debug opt-ins.
- Model install or repair may contact the model host. Normal inference is local
  and does not require a user-run server.

## Sources Of Truth

- Privacy: [`PRIVACY-BETA.md`](../PRIVACY-BETA.md)
- Compatibility policy and proof: [`compatibility-matrix.md`](product/compatibility-matrix.md)
  and [`proof-manifest.json`](product/proof-manifest.json)
- Security boundaries: [`threat-model.md`](security/threat-model.md)
- Build and release process: [`DEVELOPMENT.md`](DEVELOPMENT.md)

Automated proof, current manual proof, and a shipped release are separate facts.
Do not use one as evidence for another.
