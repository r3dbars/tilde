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

    @Test("Suppresses same suggestion updates that change the first visible word")
    func suppressesSameSuggestionFirstWordChanges() {
        let policy = SuggestionReplacementPolicy()
        let decision = policy.decision(
            currentVisibleText: " instant",
            proposedVisibleText: " calm and steady",
            currentSuggestionID: "same",
            proposedSuggestionID: "same",
            currentAgeMilliseconds: 9_000,
            currentScore: 1.20,
            proposedScore: 1.80
        )

        #expect(!decision.shouldPresent)
        #expect(decision.reason == .changedFirstWord)
        #expect(decision.metadata["replacementSuppressionReason"] == "changed-first-word")
        #expect(decision.metadata["replacementCurrentAgeMs"] == "9000")
        #expect(decision.metadata["replacementScoreMargin"] == "0.60")
    }

    @Test("Allows same request to correct the provisional first word")
    func allowsProvisionalSameRequestFirstWordCorrection() {
        let policy = SuggestionReplacementPolicy(firstWordCorrectionGraceMilliseconds: 350)
        let decision = policy.decision(
            currentVisibleText: " instant",
            proposedVisibleText: " calm and steady",
            currentSuggestionID: "same",
            proposedSuggestionID: "same",
            currentAgeMilliseconds: 300,
            currentScore: 1.20,
            proposedScore: 1.23
        )

        #expect(decision.shouldPresent)
        #expect(decision.reason == nil)
        #expect(decision.usedFirstWordCorrectionGrace)
        #expect(decision.metadata["replacementCurrentAgeMs"] == "300")
        #expect(decision.metadata["replacementScoreMargin"] == "0.03")
        #expect(decision.metadata["replacementUsedFirstWordCorrectionGrace"] == "true")
    }

    @Test("Allows one correction at the grace boundary")
    func allowsOneCorrectionAtGraceBoundary() {
        let policy = SuggestionReplacementPolicy(firstWordCorrectionGraceMilliseconds: 350)
        let decision = policy.decision(
            currentVisibleText: " instant",
            proposedVisibleText: " calm and steady",
            currentSuggestionID: "same",
            proposedSuggestionID: "same",
            currentAgeMilliseconds: 350,
            currentScore: 1.20,
            proposedScore: 1.23
        )

        #expect(decision.shouldPresent)
        #expect(decision.usedFirstWordCorrectionGrace)
    }

    @Test("Suppresses the first correction after the grace boundary")
    func suppressesCorrectionAfterGraceBoundary() {
        let policy = SuggestionReplacementPolicy(firstWordCorrectionGraceMilliseconds: 350)
        let decision = policy.decision(
            currentVisibleText: " instant",
            proposedVisibleText: " calm and steady",
            currentSuggestionID: "same",
            proposedSuggestionID: "same",
            currentAgeMilliseconds: 351,
            currentScore: 1.20,
            proposedScore: 1.80
        )

        #expect(!decision.shouldPresent)
        #expect(decision.reason == .changedFirstWord)
        #expect(!decision.usedFirstWordCorrectionGrace)
    }

    @Test("Suppresses repeated same-request first-word corrections")
    func suppressesRepeatedSameRequestFirstWordCorrections() {
        let policy = SuggestionReplacementPolicy(firstWordCorrectionGraceMilliseconds: 350)
        let decision = policy.decision(
            currentVisibleText: " calm and steady",
            proposedVisibleText: " clear and direct",
            currentSuggestionID: "same",
            proposedSuggestionID: "same",
            currentAgeMilliseconds: 100,
            currentScore: 1.23,
            proposedScore: 1.40,
            firstWordCorrectionGraceAlreadyUsed: true
        )

        #expect(!decision.shouldPresent)
        #expect(decision.reason == .changedFirstWord)
        #expect(!decision.usedFirstWordCorrectionGrace)
    }

    @Test("Does not let a different request change the provisional first word")
    func suppressesDifferentRequestFirstWordCorrectionDuringGrace() {
        let policy = SuggestionReplacementPolicy(firstWordCorrectionGraceMilliseconds: 350)
        let decision = policy.decision(
            currentVisibleText: " instant",
            proposedVisibleText: " calm and steady",
            currentSuggestionID: "old",
            proposedSuggestionID: "new",
            currentAgeMilliseconds: 300,
            currentScore: 1.20,
            proposedScore: 1.80
        )

        #expect(!decision.shouldPresent)
        #expect(decision.reason == .changedFirstWord)
    }

    @Test("Allows stale replacements that keep the first visible word")
    func allowsStaleReplacementWhenFirstWordIsStable() {
        let policy = SuggestionReplacementPolicy()
        let decision = policy.decision(
            currentVisibleText: " instant",
            proposedVisibleText: " instant and reliable",
            currentSuggestionID: "old",
            proposedSuggestionID: "new",
            currentAgeMilliseconds: 2_100,
            currentScore: 1.20,
            proposedScore: 1.25
        )

        #expect(decision.shouldPresent)
        #expect(decision.metadata["replacementCurrentAgeMs"] == "2100")
    }

    @Test("Allows replacement after user typing invalidates the current suggestion")
    func allowsReplacementAfterUserTypingInvalidatesCurrentSuggestion() {
        let policy = SuggestionReplacementPolicy()
        let decision = policy.decision(
            currentVisibleText: " instant",
            proposedVisibleText: " calm and steady",
            currentSuggestionID: "old",
            proposedSuggestionID: "new",
            currentAgeMilliseconds: 120,
            currentScore: 1.20,
            proposedScore: 0.90,
            currentSuggestionInvalidatedByUserTyping: true
        )

        #expect(decision.shouldPresent)
        #expect(decision.reason == nil)
        #expect(decision.metadata["replacementDecision"] == "present")
        #expect(decision.metadata["replacementSuppressionReason"] == nil)
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
