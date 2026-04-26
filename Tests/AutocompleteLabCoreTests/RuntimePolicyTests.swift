import Testing
@testable import AutocompleteLabCore

@Suite("Runtime policy")
struct RuntimePolicyTests {
    @Test("MVP runtime is embedded and does not allow user-managed servers")
    func mvpRuntimeIsEmbedded() {
        let decision = EmbeddedRuntimeDecision.mvp

        #expect(decision.preferredCandidate == .mlx)
        #expect(decision.fallbackCandidate == .liteRTLM)
        #expect(decision.allowsUserManagedServer == false)
    }

    @Test("Runtime states have short status summaries")
    func runtimeStatesHaveShortStatusSummaries() {
        #expect(CompletionRuntimeCandidate.mlx.displayName == "MLX")
        #expect(LocalRuntimeState.warming(candidate: .mlx).statusSummary == "warming MLX")
        #expect(LocalRuntimeState.ready(candidate: .mock).statusSummary == "ready (mock)")
        #expect(LocalRuntimeState.ready(candidate: .mock).isReady)
        #expect(!LocalRuntimeState.unavailable(reason: "not downloaded").isReady)
    }

    @Test("Runtime bootstrap falls back to mock until native MLX and asset are ready")
    func runtimeBootstrapFallsBackToMockUntilNativeReady() {
        let missingPlan = RuntimeBootstrapPlan(
            assetState: .missing(expectedPath: "/tmp/gemma"),
            nativeRuntimeAvailable: true
        )

        #expect(missingPlan.activeCandidate == .mock)
        #expect(missingPlan.fallbackReason == "missing model asset at /tmp/gemma")

        let unlinkedPlan = RuntimeBootstrapPlan(
            assetState: .available(path: "/tmp/gemma"),
            nativeRuntimeAvailable: false
        )

        #expect(unlinkedPlan.activeCandidate == .mock)
        #expect(unlinkedPlan.fallbackReason == "MLX runtime is not linked yet")

        let readyPlan = RuntimeBootstrapPlan(
            assetState: .available(path: "/tmp/gemma"),
            nativeRuntimeAvailable: true
        )

        #expect(readyPlan.activeCandidate == .mlx)
        #expect(readyPlan.fallbackReason == nil)
    }

    @Test("Runtime readiness summary explains mock fallback")
    func runtimeReadinessSummaryExplainsFallback() {
        let plan = RuntimeBootstrapPlan(
            assetState: .available(path: "/tmp/gemma"),
            nativeRuntimeAvailable: false
        )

        #expect(plan.readinessSummary(for: .ready(candidate: .mock)) == "ready (mock); fallback: MLX runtime is not linked yet")
    }

    @Test("Gemma asset manifest is MLX first")
    func gemmaAssetManifestIsMLXFirst() {
        let manifest = LocalModelAssetManifest.gemma4E2BMLX

        #expect(manifest.model == .gemma4E2B)
        #expect(manifest.runtimeCandidate == .mlx)
        #expect(manifest.cacheDirectoryName.contains("Gemma4E2B"))
    }

    @Test("Benchmark passes when average latency is under target")
    func benchmarkPassesUnderTarget() {
        let benchmark = CompletionRuntimeBenchmark(
            candidate: .liteRTLM,
            samples: [
                CompletionLatencySample(candidate: .liteRTLM, milliseconds: 240, tokenCount: 5),
                CompletionLatencySample(candidate: .liteRTLM, milliseconds: 320, tokenCount: 7)
            ]
        )

        #expect(benchmark.averageLatencyMilliseconds == 280)
        #expect(benchmark.passesAutocompleteTarget())
    }

    @Test("Benchmark fails when average latency is too slow")
    func benchmarkFailsWhenTooSlow() {
        let benchmark = CompletionRuntimeBenchmark(
            candidate: .mlx,
            samples: [
                CompletionLatencySample(candidate: .mlx, milliseconds: 900, tokenCount: 8),
                CompletionLatencySample(candidate: .mlx, milliseconds: 800, tokenCount: 8)
            ]
        )

        #expect(!benchmark.passesAutocompleteTarget())
    }
}
