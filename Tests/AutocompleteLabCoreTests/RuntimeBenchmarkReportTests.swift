import Testing
@testable import AutocompleteLabCore

@Suite("Runtime benchmark")
struct RuntimeBenchmarkReportTests {
    @Test("Benchmark averages and p95 latency")
    func benchmarkAveragesAndP95Latency() {
        let benchmark = CompletionRuntimeBenchmark(
            candidate: .mlx,
            samples: [
                CompletionLatencySample(candidate: .mlx, milliseconds: 32, tokenCount: 8),
                CompletionLatencySample(candidate: .mlx, milliseconds: 44, tokenCount: 8),
                CompletionLatencySample(candidate: .mlx, milliseconds: 48, tokenCount: 8)
            ]
        )

        #expect(benchmark.averageLatencyMilliseconds == 41)
        #expect(benchmark.p95LatencyMilliseconds == 48)
        #expect(benchmark.passesAutocompleteTarget())
    }

    @Test("Benchmark with no samples does not pass target")
    func emptyBenchmarkDoesNotPassTarget() {
        let benchmark = CompletionRuntimeBenchmark(candidate: .mlx, samples: [])

        #expect(benchmark.averageLatencyMilliseconds == nil)
        #expect(benchmark.p95LatencyMilliseconds == nil)
        #expect(!benchmark.passesAutocompleteTarget())
    }

    @Test("MVP runtime decision keeps runtime app owned")
    func mvpRuntimeDecisionKeepsRuntimeAppOwned() {
        let decision = EmbeddedRuntimeDecision.mvp

        #expect(decision.preferredCandidate == .mlx)
        #expect(decision.fallbackCandidate == .unavailable)
        #expect(!decision.allowsUserManagedServer)
    }
}
