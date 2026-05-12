# Claude Code Guide

Pure autocomplete behavior lives here.

Start map:

- `Session/`: live suggestion lifecycle, keyboard decisions, cooldowns, suppression, and acceptance checks.
- `Engine/`: prompt building, completion engines, output cleanup, ranking, and word memory.
- `Geometry/`: caret, bounds, placement, screenshots, and coordinate conversion policies.
- `Configuration/`: defaults, privacy, compatibility, browser host, and insertion-mode policies.
- `Tracing/`: privacy filters, trace events, analyzers, reports, and proof metadata.
- `Compatibility/`: app profiles and support routing.
- `Text/`: cursor splitting, replacement, and diagnostic redaction.
- `Runtime/`: runtime value types, readiness guidance, caches, and benchmark shapes.
- `Suggestions/`: suggestion and acceptance value types.
- `Experiments/`: deterministic eval and experiment helpers.

Rules:

- No AppKit, Accessibility, MLX bindings, file dialogs, screenshots, or process management here.
- Preserve Unicode correctly.
- Keep privacy policy explicit and test every behavior change.
- Treat support claims as policy plus proof, not optimism.
