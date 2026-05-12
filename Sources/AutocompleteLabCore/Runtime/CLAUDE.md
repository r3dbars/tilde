# Claude Code Guide

Runtime policy value types live here.

Start with:

- `RuntimeBootstrapPlan.swift`
- `RuntimeReadinessGuidance.swift`
- `RuntimeSessionCachePolicy.swift`
- `RuntimeStaticPromptCache.swift`
- `CompletionRuntimeBenchmark.swift`
- `MockModelRuntime.swift`

Rules:

- Do not start external model servers from core.
- Keep concrete MLX bindings in `Sources/AutocompleteLabApp/Runtime`.
- Benchmarks should focus on autocomplete latency and readiness.
- Add tests when changing cache, bootstrap, mock, or guidance behavior.
