import Testing
@testable import AutocompleteLabCore

@Suite("Runtime benchmark report")
struct RuntimeBenchmarkReportTests {
    @Test("Gemma 4 E2B plan prefers LiteRT-LM with MLX fallback")
    func gemmaPlanPrefersLiteRTLM() {
        let plan = RuntimeBenchmarkPlan.gemma4E2B()

        #expect(plan.model == .gemma4E2B)
        #expect(plan.warmupCount == 3)
        #expect(plan.sampleCount == 10)
        #expect(plan.targetLatencyMilliseconds == 700)
        #expect(plan.stretchLatencyMilliseconds == 300)
        #expect(plan.generatedTokenCount == 16)
        #expect(plan.candidates.map(\.candidate) == [.liteRTLM, .mlx])
        #expect(plan.candidates.first?.modelIdentifier == "gemma-4-E2B-it-litert-lm")
    }

    @Test("Report recommends preferred runtime when it passes target")
    func reportRecommendsPreferredPassingRuntime() {
        let plan = RuntimeBenchmarkPlan.gemma4E2B()
        let report = RuntimeBenchmarkReport(
            plan: plan,
            results: [
                RuntimeBenchmarkCandidateResult(
                    candidate: .liteRTLM,
                    availability: .available,
                    samples: [
                        CompletionLatencySample(candidate: .liteRTLM, milliseconds: 280, tokenCount: 8),
                        CompletionLatencySample(candidate: .liteRTLM, milliseconds: 340, tokenCount: 8)
                    ]
                ),
                RuntimeBenchmarkCandidateResult(
                    candidate: .mlx,
                    availability: .available,
                    samples: [
                        CompletionLatencySample(candidate: .mlx, milliseconds: 260, tokenCount: 8),
                        CompletionLatencySample(candidate: .mlx, milliseconds: 270, tokenCount: 8)
                    ]
                )
            ]
        )

        #expect(report.recommendedCandidate == .liteRTLM)
        #expect(report.result(for: .liteRTLM)?.targetEvaluation(plan: plan) == .target)
        #expect(report.summary.contains("recommendation=LiteRT-LM"))
    }

    @Test("Report falls back to MLX when LiteRT-LM is unavailable")
    func reportFallsBackToMLX() {
        let plan = RuntimeBenchmarkPlan.gemma4E2B()
        let report = RuntimeBenchmarkReport(
            plan: plan,
            results: [
                RuntimeBenchmarkCandidateResult(
                    candidate: .liteRTLM,
                    availability: .unavailable("LiteRT-LM checkout not found")
                ),
                RuntimeBenchmarkCandidateResult(
                    candidate: .mlx,
                    availability: .available,
                    samples: [
                        CompletionLatencySample(candidate: .mlx, milliseconds: 240, tokenCount: 8),
                        CompletionLatencySample(candidate: .mlx, milliseconds: 250, tokenCount: 8)
                    ]
                )
            ]
        )

        #expect(report.recommendedCandidate == .mlx)
        #expect(report.result(for: .liteRTLM)?.targetEvaluation(plan: plan) == .notRun)
        #expect(report.result(for: .mlx)?.targetEvaluation(plan: plan) == .stretch)
        #expect(report.summary.contains("LiteRT-LM: unavailable"))
    }

    @Test("Report gives no recommendation when all candidates are missing or slow")
    func reportRequiresPassingCandidate() {
        let plan = RuntimeBenchmarkPlan.gemma4E2B()
        let report = RuntimeBenchmarkReport(
            plan: plan,
            results: [
                RuntimeBenchmarkCandidateResult(
                    candidate: .liteRTLM,
                    availability: .unavailable("model package missing")
                ),
                RuntimeBenchmarkCandidateResult(
                    candidate: .mlx,
                    availability: .available,
                    samples: [
                        CompletionLatencySample(candidate: .mlx, milliseconds: 900, tokenCount: 8),
                        CompletionLatencySample(candidate: .mlx, milliseconds: 920, tokenCount: 8)
                    ]
                )
            ]
        )

        #expect(report.recommendedCandidate == nil)
        #expect(report.result(for: .mlx)?.targetEvaluation(plan: plan) == .tooSlow)
        #expect(report.summary.contains("recommendation=none"))
    }
}
