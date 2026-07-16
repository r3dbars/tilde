import Testing
@testable import AutocompleteLabCore
@testable import AutocompleteLabResearch

@Suite("Beta acceptance scorecard")
struct BetaAcceptanceScorecardTests {
    /// Builds a summary carrying only the fields the scorecard reads. Everything else uses the
    /// summary's own defaults.
    private func makeSummary(
        presentedCount: Int,
        acceptRate: Double,
        acceptedAndKeptRateShown: Double,
        usefulRate: Double = 0,
        p50: Int? = 100,
        p95: Int? = 300,
        acceptRateByApp: [String: Double] = [:],
        acceptedAndKeptRateByApp: [String: Double] = [:],
        usefulRateByApp: [String: Double] = [:],
        suppressedByReason: [String: Int] = [:],
        presentedByApp: [String: Int] = [:],
        actionableSuppressedByApp: [String: Int] = [:]
    ) -> AutocompleteTraceSummary {
        AutocompleteTraceSummary(
            totalEvents: presentedCount,
            presentedCount: presentedCount,
            acceptedCount: 0,
            typedThroughCount: 0,
            typedOverCount: 0,
            ignoredCount: 0,
            insertionFailureCount: 0,
            acceptedAndKeptRateShown: acceptedAndKeptRateShown,
            acceptRate: acceptRate,
            usefulRate: usefulRate,
            p50LatencyMilliseconds: p50,
            p90LatencyMilliseconds: nil,
            p95LatencyMilliseconds: p95,
            acceptRateByApp: acceptRateByApp,
            acceptedAndKeptRateByApp: acceptedAndKeptRateByApp,
            usefulRateByApp: usefulRateByApp,
            suppressedByReason: suppressedByReason,
            presentedByApp: presentedByApp,
            actionableSuppressedByApp: actionableSuppressedByApp,
            topMisses: []
        )
    }

    @Test("Healthy app accepts and keeps at a good rate")
    func healthyApp() {
        let summary = makeSummary(
            presentedCount: 100,
            acceptRate: 0.40,
            acceptedAndKeptRateShown: 0.30,
            p95: 300,
            acceptRateByApp: ["com.apple.TextEdit": 0.40],
            acceptedAndKeptRateByApp: ["com.apple.TextEdit": 0.30],
            usefulRateByApp: ["com.apple.TextEdit": 0.45],
            presentedByApp: ["com.apple.TextEdit": 100]
        )

        let scorecard = BetaAcceptanceScorecard(summary: summary)

        #expect(scorecard.rows.count == 1)
        #expect(scorecard.rows[0].verdict == .healthy)
        #expect(abs(scorecard.rows[0].keptGivenAccepted - 0.75) < 0.0001)
        #expect(scorecard.overallVerdict == .healthy)
    }

    @Test("Low accept rate reads as noisy")
    func noisyApp() {
        let verdict = BetaAcceptanceScorecard.appVerdict(
            shown: 100,
            acceptRate: 0.05,
            acceptedAndKeptRate: 0.04,
            thresholds: .beta
        )

        #expect(verdict == .noisy)
    }

    @Test("Accepted-then-deleted reads as low quality")
    func lowQualityApp() {
        // Accepted often, but only a quarter of accepts survive -> kept-given-accepted 0.25.
        let verdict = BetaAcceptanceScorecard.appVerdict(
            shown: 100,
            acceptRate: 0.40,
            acceptedAndKeptRate: 0.10,
            thresholds: .beta
        )

        #expect(verdict == .lowQuality)
    }

    @Test("Too few shown suggestions reads as insufficient data")
    func insufficientData() {
        let summary = makeSummary(
            presentedCount: 5,
            acceptRate: 0.80,
            acceptedAndKeptRateShown: 0.80,
            presentedByApp: ["com.example.app": 5]
        )

        let scorecard = BetaAcceptanceScorecard(summary: summary)

        #expect(scorecard.rows[0].verdict == .insufficientData)
        #expect(scorecard.overallVerdict == .insufficientData)
    }

    @Test("Latency over budget makes the overall verdict slow even with good quality")
    func slowOverridesQuality() {
        let summary = makeSummary(
            presentedCount: 100,
            acceptRate: 0.50,
            acceptedAndKeptRateShown: 0.40,
            p95: 900,
            acceptRateByApp: ["com.apple.TextEdit": 0.50],
            acceptedAndKeptRateByApp: ["com.apple.TextEdit": 0.40],
            presentedByApp: ["com.apple.TextEdit": 100]
        )

        let scorecard = BetaAcceptanceScorecard(summary: summary)

        #expect(scorecard.overallVerdict == .slow)
        // The per-app row still reports its quality verdict (latency is judged overall only).
        #expect(scorecard.rows[0].verdict == .healthy)
    }

    @Test("Rows are sorted by shown count and markdown surfaces verdicts and suppression reasons")
    func sortingAndMarkdown() {
        let summary = makeSummary(
            presentedCount: 150,
            acceptRate: 0.30,
            acceptedAndKeptRateShown: 0.20,
            p95: 300,
            acceptRateByApp: ["com.apple.TextEdit": 0.40, "com.example.noisy": 0.02],
            acceptedAndKeptRateByApp: ["com.apple.TextEdit": 0.30, "com.example.noisy": 0.01],
            usefulRateByApp: ["com.apple.TextEdit": 0.45, "com.example.noisy": 0.03],
            suppressedByReason: ["low-score": 40, "cooldown": 10],
            presentedByApp: ["com.apple.TextEdit": 100, "com.example.noisy": 50]
        )

        let scorecard = BetaAcceptanceScorecard(summary: summary)

        // Sorted by shown descending.
        #expect(scorecard.rows.map(\.appBundleIdentifier) == ["com.apple.TextEdit", "com.example.noisy"])
        #expect(scorecard.rows[0].verdict == .healthy)
        #expect(scorecard.rows[1].verdict == .noisy)

        // Suppression reasons sorted by count descending.
        #expect(scorecard.topSuppressionReasons.map(\.reason) == ["low-score", "cooldown"])

        let markdown = scorecard.markdown
        #expect(markdown.contains("## Beta Acceptance Scorecard"))
        #expect(markdown.contains("com.apple.TextEdit: healthy"))
        #expect(markdown.contains("com.example.noisy: noisy"))
        #expect(markdown.contains("low-score: 40"))
    }
}
