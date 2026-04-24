import Testing
@testable import AutocompleteLabCore

@Suite("Runtime policy")
struct RuntimePolicyTests {
    @Test("MVP runtime is embedded and does not allow user-managed servers")
    func mvpRuntimeIsEmbedded() {
        let decision = EmbeddedRuntimeDecision.mvp

        #expect(decision.preferredCandidate == .liteRTLM)
        #expect(decision.fallbackCandidate == .mlx)
        #expect(decision.allowsUserManagedServer == false)
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
