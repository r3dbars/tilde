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

        let report = plan.readinessReport(for: .ready(candidate: .mock))

        #expect(report.stage == .runtimeUnavailable)
        #expect(report.summary == "runtime unavailable (MLX); fallback: ready (mock)")
        #expect(report.detail == "MLX runtime is not linked yet")
        #expect(report.action == .none)
        #expect(!report.isReady)
        #expect(plan.readinessSummary(for: .ready(candidate: .mock)) == report.summary)
    }

    @Test("Runtime readiness report separates download and repair states")
    func runtimeReadinessReportSeparatesAssetStates() {
        let missingPlan = RuntimeBootstrapPlan(
            assetState: .missing(expectedPath: "/tmp/gemma"),
            nativeRuntimeAvailable: false
        )
        let missingReport = missingPlan.readinessReport(for: .ready(candidate: .mock))

        #expect(missingReport.stage == .downloadNeeded)
        #expect(missingReport.summary == "download needed (Gemma 4 26B A4B); fallback: ready (mock)")
        #expect(missingReport.detail == "Expected MLX model folder at /tmp/gemma")
        #expect(missingReport.action == .revealModelFolder)

        let invalidPlan = RuntimeBootstrapPlan(
            assetState: .invalid(path: "/tmp/gemma", reason: "missing config.json"),
            nativeRuntimeAvailable: false
        )
        let invalidReport = invalidPlan.readinessReport(for: .ready(candidate: .mock))

        #expect(invalidReport.stage == .repairNeeded)
        #expect(invalidReport.summary == "model folder needs repair; fallback: ready (mock)")
        #expect(invalidReport.detail == "/tmp/gemma: missing config.json")
        #expect(invalidReport.action == .revealModelFolder)
    }

    @Test("Runtime readiness report marks native runtime ready")
    func runtimeReadinessReportMarksNativeReady() {
        let plan = RuntimeBootstrapPlan(
            assetState: .available(path: "/tmp/gemma"),
            nativeRuntimeAvailable: true
        )
        let report = plan.readinessReport(for: .ready(candidate: .mlx))

        #expect(report.stage == .ready)
        #expect(report.summary == "ready (MLX)")
        #expect(report.action == .none)
        #expect(report.isReady)
    }

    @Test("Gemma 4 asset manifest is MLX first")
    func gemma4AssetManifestIsMLXFirst() {
        let manifest = LocalModelAssetManifest.gemma4A4BMLX

        #expect(manifest.model == .gemma4A4B)
        #expect(manifest.runtimeCandidate == .mlx)
        #expect(manifest.cacheDirectoryName.contains("Gemma4A4B"))
        #expect(manifest.requiredFileNames.contains("config.json"))
        #expect(manifest.requiredModelFileExtension == "safetensors")
        #expect(manifest.requiresVisionLanguageFactory)
    }

    @Test("MLX model asset validation expects a Hugging Face directory")
    func mlxAssetValidationExpectsDirectory() {
        let manifest = LocalModelAssetManifest.gemma4A4BMLX

        #expect(manifest.validatedDirectoryState(
            path: "/tmp/gemma",
            isDirectory: false,
            childFileNames: [],
            modelBytes: 0
        ) == .invalid(path: "/tmp/gemma", reason: "expected a model directory"))

        #expect(manifest.validatedDirectoryState(
            path: "/tmp/gemma",
            isDirectory: true,
            childFileNames: ["tokenizer.json", "model.safetensors"],
            modelBytes: 2_000_000
        ) == .invalid(path: "/tmp/gemma", reason: "missing config.json"))

        #expect(manifest.validatedDirectoryState(
            path: "/tmp/gemma",
            isDirectory: true,
            childFileNames: ["config.json", "tokenizer.json"],
            modelBytes: 2_000_000
        ) == .invalid(path: "/tmp/gemma", reason: "missing tokenizer_config.json"))

        #expect(manifest.validatedDirectoryState(
            path: "/tmp/gemma",
            isDirectory: true,
            childFileNames: ["config.json", "tokenizer.json", "tokenizer_config.json"],
            modelBytes: 2_000_000
        ) == .invalid(path: "/tmp/gemma", reason: "missing .safetensors weights"))

        #expect(manifest.validatedDirectoryState(
            path: "/tmp/gemma",
            isDirectory: true,
            childFileNames: ["config.json", "tokenizer.json", "tokenizer_config.json", "model.safetensors"],
            modelBytes: 16 * 1024 * 1024 * 1024
        ) == .available(path: "/tmp/gemma"))
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
                CompletionLatencySample(candidate: .mlx, milliseconds: 1_100, tokenCount: 8),
                CompletionLatencySample(candidate: .mlx, milliseconds: 1_000, tokenCount: 8)
            ]
        )

        #expect(!benchmark.passesAutocompleteTarget())
    }
}
