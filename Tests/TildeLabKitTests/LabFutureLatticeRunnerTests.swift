import Testing
@testable import TildeLabKit

@Suite("Future Lattice feasibility")
struct LabFutureLatticeRunnerTests {
    @Test("Exact prefix matching normalizes Unicode and stops at the first mismatch")
    func exactPrefix() {
        #expect(LabFutureLatticeAnalyzer.exactPrefixCharacters("  café now", "cafe\u{301} later") == 5)
        #expect(LabFutureLatticeAnalyzer.exactPrefixCharacters("send x deck", "send a deck") == 5)
    }

    @Test("Nested K metrics count exact coverage, diversity, readiness, and compute")
    func nestedMetrics() {
        let candidates = [
            candidate(0, "schedule it tomorrow", latency: 100, ready: 100),
            candidate(1, "send the budget", latency: 120, ready: 220),
            candidate(2, "share that file", latency: 130, ready: 230),
            candidate(3, "forward the deck", latency: 140, ready: 240),
        ]
        let situation = (
            golden: "send the deck",
            reviewed: ["send the deck", "share that file"],
            candidates: candidates
        )

        let k1 = LabFutureLatticeAnalyzer.metric(
            candidateCount: 1,
            minimumUsefulCharacters: 6,
            situations: [situation]
        )
        let k4 = LabFutureLatticeAnalyzer.metric(
            candidateCount: 4,
            minimumUsefulCharacters: 6,
            situations: [situation]
        )

        #expect(k1.goldenCoverageCount == 0)
        #expect(k4.goldenCoverageCount == 1)
        #expect(k4.reviewedCoverageCount == 1)
        #expect(k4.medianUniqueCandidates == 4)
        #expect(k4.medianDistinctFirstTwoContentWordPaths == 4)
        #expect(k4.readinessP50Milliseconds == 240)
        #expect(k4.summedRequestLatencyMilliseconds == 490)
        #expect(k4.computeMultiplierVersusK1 == 4.9)
    }

    @Test("Function words do not create fake diversity")
    func contentPaths() {
        #expect(LabFutureLatticeAnalyzer.firstTwoContentWordPath("I will send the deck") == "send deck")
        #expect(LabFutureLatticeAnalyzer.firstTwoContentWordPath("the and to") == nil)
    }

    private func candidate(
        _ index: Int,
        _ text: String,
        latency: Int,
        ready: Int
    ) -> LabFutureLatticeCandidate {
        LabFutureLatticeCandidate(
            index: index,
            text: text,
            requestLatencyMilliseconds: latency,
            readyMilliseconds: ready,
            decodedTokens: 3
        )
    }
}
