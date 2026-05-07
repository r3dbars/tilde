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
        #expect(report.detail == "This build is missing its local model engine. A separate model server will not fix it.")
        #expect(report.action == .none)
        #expect(!report.isReady)
        #expect(!report.allowsSuggestions)
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
        #expect(missingReport.summary == "download needed (Qwen3.5 4B); fallback: ready (mock)")
        #expect(missingReport.detail == "The local model is not installed yet. Expected folder: /tmp/gemma")
        #expect(missingReport.action == .installModel)

        let invalidPlan = RuntimeBootstrapPlan(
            assetState: .invalid(path: "/tmp/gemma", reason: "missing config.json"),
            nativeRuntimeAvailable: false
        )
        let invalidReport = invalidPlan.readinessReport(for: .ready(candidate: .mock))

        #expect(invalidReport.stage == .repairNeeded)
        #expect(invalidReport.summary == "model folder needs repair; fallback: ready (mock)")
        #expect(invalidReport.detail == "The local model folder is incomplete: missing config.json. Folder: /tmp/gemma")
        #expect(invalidReport.action == .repairModel)

        let unsupportedSourcePlan = RuntimeBootstrapPlan(
            preferredAsset: .qwen35NineBMLX,
            assetState: .missing(expectedPath: "/tmp/qwen9"),
            nativeRuntimeAvailable: false
        )
        #expect(unsupportedSourcePlan.readinessReport(for: .ready(candidate: .mock)).action == .revealModelFolder)
    }

    @Test("Runtime readiness guidance gives stage-specific setup actions")
    func runtimeReadinessGuidanceGivesStageSpecificSetupActions() {
        #expect(RuntimeReadinessAction.cancelModelInstall.displayName == "Cancel Model Install")
        let missing = RuntimeReadinessGuidance(
            report: RuntimeReadinessReport(
                stage: .downloadNeeded,
                summary: "download needed",
                action: .installModel
            )
        )
        let repair = RuntimeReadinessGuidance(
            report: RuntimeReadinessReport(
                stage: .repairNeeded,
                summary: "repair needed",
                action: .repairModel
            )
        )
        let warming = RuntimeReadinessGuidance(
            report: RuntimeReadinessReport(
                stage: .warming,
                summary: "warming",
                action: .wait
            )
        )
        let failed = RuntimeReadinessGuidance(
            report: RuntimeReadinessReport(
                stage: .failed,
                summary: "failed",
                action: .retry
            )
        )
        let ready = RuntimeReadinessGuidance(
            report: RuntimeReadinessReport(
                stage: .ready,
                summary: "ready",
                action: .none,
                isReady: true
            )
        )

        #expect(missing.actionTitle == "Install Model")
        #expect(missing.isActionEnabled)
        #expect(missing.message.contains("You do not need Ollama or a model server"))
        #expect(repair.actionTitle == "Repair Model")
        #expect(repair.isActionEnabled)
        #expect(repair.message.contains("local model files look incomplete"))
        #expect(warming.actionTitle == "Warming...")
        #expect(!warming.isActionEnabled)
        #expect(failed.actionTitle == "Retry Model")
        #expect(failed.isActionEnabled)
        #expect(ready.actionTitle == "Ready")
        #expect(!ready.isActionEnabled)
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
        #expect(report.allowsSuggestions)
    }

    @Test("Runtime production readiness requires native preferred runtime")
    func runtimeProductionReadinessRequiresNativePreferredRuntime() {
        let readyPlan = RuntimeBootstrapPlan(
            assetState: .available(path: "/tmp/gemma"),
            nativeRuntimeAvailable: true
        )
        #expect(readyPlan.isProductionReady(runtimeState: .ready(candidate: .mlx)))

        let mockFallbackPlan = RuntimeBootstrapPlan(
            assetState: .missing(expectedPath: "/tmp/gemma"),
            nativeRuntimeAvailable: true
        )
        #expect(!mockFallbackPlan.isProductionReady(runtimeState: .ready(candidate: .mock)))

        let warmingPlan = RuntimeBootstrapPlan(
            assetState: .available(path: "/tmp/gemma"),
            nativeRuntimeAvailable: true
        )
        #expect(!warmingPlan.isProductionReady(runtimeState: .warming(candidate: .mlx)))
    }

    @Test("Runtime readiness blocks suggestions while warming or failed")
    func runtimeReadinessBlocksSuggestionsUntilReady() {
        let plan = RuntimeBootstrapPlan(
            assetState: .available(path: "/tmp/gemma"),
            nativeRuntimeAvailable: true
        )

        #expect(!plan.readinessReport(for: .warming(candidate: .mlx)).allowsSuggestions)
        #expect(!plan.readinessReport(for: .failed(candidate: .mlx, reason: "boom")).allowsSuggestions)
        #expect(plan.readinessReport(for: .ready(candidate: .mlx)).allowsSuggestions)
    }

    @Test("Qwen3.5 4B asset manifest is MLX first")
    func qwen35FourBAssetManifestIsMLXFirst() {
        let manifest = LocalModelAssetManifest.preferredMLX

        #expect(manifest.model == .qwen35FourB)
        #expect(manifest.runtimeCandidate == .mlx)
        #expect(manifest.cacheDirectoryName.contains("Qwen35FourB"))
        #expect(manifest.source?.repoID == "mlx-community/Qwen3.5-4B-MLX-4bit")
        #expect(manifest.source?.allowPatterns.contains("*.safetensors") == true)
        #expect(manifest.source?.estimatedBytes == 3_030_000_000)
        #expect(manifest.requiredFileNames.contains("config.json"))
        #expect(manifest.requiredModelFileExtension == "safetensors")
        #expect(!manifest.requiresVisionLanguageFactory)
    }

    @Test("Named MLX manifests support local model trials")
    func namedMLXManifestsSupportLocalModelTrials() {
        #expect(LocalModelAssetManifest.mlxManifest(named: nil) == .qwen35FourBMLX)
        #expect(LocalModelAssetManifest.mlxManifest(named: "") == .qwen35FourBMLX)
        #expect(LocalModelAssetManifest.mlxManifest(named: "qwen35-4b") == .qwen35FourBMLX)
        #expect(LocalModelAssetManifest.mlxManifest(named: " Qwen3.5-9B ") == .qwen35NineBMLX)
        #expect(LocalModelAssetManifest.mlxManifest(named: "gemma-4-e4b") == .gemma4E4BMLX)
        #expect(LocalModelAssetManifest.mlxManifest(named: "gemma-4-e4b-4bit") == .gemma4E4BMLX)
        #expect(LocalModelAssetManifest.mlxManifest(named: "gemma-4-e4b-it-optiq") == .gemma4E4BItOptiQMLX)
        #expect(LocalModelAssetManifest.mlxManifest(named: "gemma-4-e4b-it-optiq-4bit") == .gemma4E4BItOptiQMLX)
        #expect(LocalModelAssetManifest.mlxManifest(named: "gemma-4-26b") == .gemma4A4BMLX)
        #expect(LocalModelAssetManifest.mlxManifest(named: "unknown") == .qwen35FourBMLX)
    }

    @Test("MLX model asset validation expects a Hugging Face directory")
    func mlxAssetValidationExpectsDirectory() {
        let manifest = LocalModelAssetManifest.preferredMLX

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
            modelBytes: 3 * 1024 * 1024 * 1024
        ) == .available(path: "/tmp/gemma"))
    }

    @Test("Benchmark passes when average latency is under target")
    func benchmarkPassesUnderTarget() {
        let benchmark = CompletionRuntimeBenchmark(
            candidate: .liteRTLM,
            samples: [
                CompletionLatencySample(candidate: .liteRTLM, milliseconds: 40, tokenCount: 3),
                CompletionLatencySample(candidate: .liteRTLM, milliseconds: 50, tokenCount: 4)
            ]
        )

        #expect(benchmark.averageLatencyMilliseconds == 45)
        #expect(benchmark.p95LatencyMilliseconds == 50)
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

    @Test("Benchmark fails when p95 latency is too slow")
    func benchmarkFailsWhenP95IsTooSlow() {
        let benchmark = CompletionRuntimeBenchmark(
            candidate: .mlx,
            samples: [
                CompletionLatencySample(candidate: .mlx, milliseconds: 10, tokenCount: 1),
                CompletionLatencySample(candidate: .mlx, milliseconds: 10, tokenCount: 1),
                CompletionLatencySample(candidate: .mlx, milliseconds: 90, tokenCount: 1)
            ]
        )

        #expect(benchmark.averageLatencyMilliseconds == 36)
        #expect(benchmark.p95LatencyMilliseconds == 90)
        #expect(!benchmark.passesAutocompleteTarget())
    }
}
