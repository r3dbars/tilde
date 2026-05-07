import Testing
@testable import AutocompleteLabCore

@Suite("Suggestion replacement policy")
struct SuggestionReplacementPolicyTests {
    @Test("Allows first visible suggestion")
    func allowsFirstVisibleSuggestion() {
        let policy = SuggestionReplacementPolicy()
        let decision = policy.decision(
            currentVisibleText: nil,
            proposedVisibleText: " make this",
            currentSuggestionID: nil,
            proposedSuggestionID: "next",
            currentAgeMilliseconds: nil,
            currentScore: nil,
            proposedScore: 1.2
        )

        #expect(decision.shouldPresent)
        #expect(decision.metadata["replacementDecision"] == "present")
    }

    @Test("Allows same suggestion updates")
    func allowsSameSuggestionUpdates() {
        let policy = SuggestionReplacementPolicy()
        let decision = policy.decision(
            currentVisibleText: " make this",
            proposedVisibleText: " make this work",
            currentSuggestionID: "same",
            proposedSuggestionID: "same",
            currentAgeMilliseconds: 100,
            currentScore: 1.0,
            proposedScore: 1.1
        )

        #expect(decision.shouldPresent)
    }

    @Test("Suppresses low margin replacements while visible text is fresh")
    func suppressesLowMarginFreshReplacements() {
        let policy = SuggestionReplacementPolicy(
            minimumFreshLifetimeMilliseconds: 1_200,
            staleLifetimeMilliseconds: 2_000,
            minimumScoreMargin: 0.35
        )
        let decision = policy.decision(
            currentVisibleText: " make this",
            proposedVisibleText: " make that",
            currentSuggestionID: "old",
            proposedSuggestionID: "new",
            currentAgeMilliseconds: 600,
            currentScore: 1.20,
            proposedScore: 1.30
        )

        #expect(!decision.shouldPresent)
        #expect(decision.reason == .freshVisibleSuggestion)
        #expect(decision.metadata["replacementSuppressionReason"] == "fresh-visible-suggestion")
        #expect(decision.metadata["replacementCurrentAgeMs"] == "600")
        #expect(decision.metadata["replacementScoreMargin"] == "0.10")
    }

    @Test("Allows fresh replacements only when the score win is clear")
    func allowsFreshClearScoreWins() {
        let policy = SuggestionReplacementPolicy(minimumScoreMargin: 0.35)
        let decision = policy.decision(
            currentVisibleText: " make this",
            proposedVisibleText: " make this work",
            currentSuggestionID: "old",
            proposedSuggestionID: "new",
            currentAgeMilliseconds: 500,
            currentScore: 1.00,
            proposedScore: 1.40
        )

        #expect(decision.shouldPresent)
        #expect(decision.metadata["replacementScoreMargin"] == "0.40")
    }

    @Test("Suppresses mid lifetime replacements without a clear score win")
    func suppressesMidLifetimeLowMarginReplacements() {
        let policy = SuggestionReplacementPolicy(
            minimumFreshLifetimeMilliseconds: 1_200,
            staleLifetimeMilliseconds: 2_000,
            minimumScoreMargin: 0.35
        )
        let decision = policy.decision(
            currentVisibleText: " make this",
            proposedVisibleText: " make this better",
            currentSuggestionID: "old",
            proposedSuggestionID: "new",
            currentAgeMilliseconds: 1_500,
            currentScore: 1.20,
            proposedScore: 1.30
        )

        #expect(!decision.shouldPresent)
        #expect(decision.reason == .lowScoreMargin)
        #expect(decision.metadata["replacementSuppressionReason"] == "low-score-margin")
    }

    @Test("Allows stale visible text to be replaced after two seconds")
    func allowsStaleVisibleTextReplacement() {
        let policy = SuggestionReplacementPolicy(
            minimumFreshLifetimeMilliseconds: 1_200,
            staleLifetimeMilliseconds: 2_000,
            minimumScoreMargin: 0.35
        )
        let decision = policy.decision(
            currentVisibleText: " make this",
            proposedVisibleText: " make this better",
            currentSuggestionID: "old",
            proposedSuggestionID: "new",
            currentAgeMilliseconds: 2_100,
            currentScore: 1.20,
            proposedScore: 1.25
        )

        #expect(decision.shouldPresent)
        #expect(decision.metadata["replacementCurrentAgeMs"] == "2100")
    }
}
