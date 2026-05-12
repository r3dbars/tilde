# Claude Code Guide

`mlx-swift-lm` patches live here.

Current patches should be checked against:

- `Package.swift`
- `Package.resolved`
- `Sources/AutocompleteLabApp/Runtime/MLXModelRuntime.swift`

Rules:

- Keep patches minimal and version-aware.
- Do not assume upstream internals are stable.
- Re-run runtime factory or model-runtime tests after changing patch expectations.
- Note any upstream replacement path in product or runtime docs.
