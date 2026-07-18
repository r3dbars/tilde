import Testing
@testable import AutocompleteLabCore

@Suite("Good and fast enough policy")
struct GoodAndFastEnoughPolicyTests {
    private let score = DisplayScore(
        utility: 0.70,
        styleFit: 0.40,
        contextFit: 0.35,
        userAffinity: 0.25,
        risk: 0.10,
        repetition: 0.05,
        instability: 0.05
    )

    @Test("combines confidence and display scoring for a healthy candidate")
    func combinesConfidenceAndDisplayScoringForAHealthyCandidate() {
        let decision = GoodAndFastEnoughPolicy().decision(
            suggestion: CompletionSuggestion(text: " for the meeting", maxVisibleWords: 4),
            mode: .phraseContinuation,
            textBeforeCursor: "Can you send the notes",
            supportLevel: .green,
            score: score,
            displayScorePolicy: DisplayScorePolicy(),
            latencyMilliseconds: 180
        )

        #expect(decision.shouldDisplay)
        #expect(decision.confidence.canDisplay)
        #expect(decision.metadata["displayScoreDecision"] == "display")
        #expect(decision.metadata["completionConfidenceBucket"] == "high")
        #expect(decision.latencyBudgetMilliseconds == 2_000)
    }

    @Test("one latency ceiling suppresses an otherwise good candidate")
    func oneLatencyCeilingSuppressesAnOtherwiseGoodCandidate() {
        let decision = GoodAndFastEnoughPolicy().decision(
            suggestion: CompletionSuggestion(text: " for the meeting", maxVisibleWords: 4),
            mode: .phraseContinuation,
            textBeforeCursor: "Can you send the notes",
            supportLevel: .green,
            score: score,
            displayScorePolicy: DisplayScorePolicy(),
            latencyMilliseconds: 1_201,
            latencyBudgetMilliseconds: 1_200
        )

        #expect(!decision.shouldDisplay)
        #expect(decision.decision.trace.score == score)
        #expect(decision.metadata["displayScoreSuppressionReason"] == "too-slow-to-display")
        #expect(decision.metadata["modelDisplayLatencyBudgetMilliseconds"] == "1200")
        #expect(decision.metadata["modelLatencyForBudgetMilliseconds"] == "1201")
    }

    @Test("confidence safety remains a separate veto inside the unified decision")
    func confidenceSafetyRemainsASeparateVetoInsideTheUnifiedDecision() {
        let decision = GoodAndFastEnoughPolicy().decision(
            suggestion: CompletionSuggestion(text: " let me know if I can help", maxVisibleWords: 8),
            mode: .phraseContinuation,
            textBeforeCursor: "Can you send the notes",
            supportLevel: .yellow,
            score: score,
            displayScorePolicy: DisplayScorePolicy(),
            latencyMilliseconds: 180
        )

        #expect(!decision.shouldDisplay)
        #expect(decision.metadata["displayScoreSuppressionReason"] == "low-confidence")
        #expect(decision.confidence.reasons.contains("generic-or-assistant-like"))
    }

    @Test("raw evaluation exposes a slow low-confidence candidate")
    func rawEvaluationBypassesProductHeuristics() {
        let decision = GoodAndFastEnoughPolicy().decision(
            suggestion: CompletionSuggestion(text: " let me know if I can help", maxVisibleWords: 8),
            mode: .phraseContinuation,
            textBeforeCursor: "Can you send the notes",
            supportLevel: .yellow,
            score: DisplayScore(
                utility: 0,
                styleFit: 0,
                contextFit: 0,
                userAffinity: 0,
                risk: 1,
                repetition: 1,
                instability: 1
            ),
            displayScorePolicy: DisplayScorePolicy(),
            latencyMilliseconds: 5_000,
            latencyBudgetMilliseconds: 1,
            bypassProductHeuristics: true
        )

        #expect(decision.shouldDisplay)
        #expect(decision.metadata["rawSuggestionEvaluation"] == "true")
    }

    @Test("fallback stays on the same core decision surface")
    func fallbackStaysOnTheSameCoreDecisionSurface() {
        let decision = GoodAndFastEnoughPolicy().fallbackDecision(
            supportStatus: .unsupported,
            isEnabled: true,
            hasCurrentApp: false
        )

        #expect(decision.availability == .unavailable)
        #expect(decision.reason == .noCurrentApp)
    }
}
