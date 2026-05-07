import Testing
@testable import AutocompleteLabCore

@Suite("Display score policy")
struct DisplayScorePolicyTests {
    @Test("displays suggestions that clear the mode threshold")
    func displaysSuggestionsThatClearThreshold() {
        let policy = DisplayScorePolicy()
        let score = DisplayScore(
            utility: 0.70,
            styleFit: 0.40,
            contextFit: 0.35,
            userAffinity: 0.25,
            risk: 0.10,
            repetition: 0.05,
            instability: 0.05
        )

        let decision = policy.decision(for: score, mode: .phraseContinuation)

        #expect(abs(score.rawScore - 1.50) < 0.0001)
        #expect(abs(score.finalScore - 1.50) < 0.0001)
        #expect(decision.shouldDisplay)
        #expect(decision.metadata["displayScoreDecision"] == "display")
        #expect(decision.metadata["displayScoreMode"] == "phraseContinuation")
        #expect(decision.metadata["displayScoreThreshold"] == "1.00")
        #expect(decision.metadata["displayScoreUtility"] == "0.70")
        #expect(decision.metadata["displayScoreStyleFit"] == "0.40")
        #expect(decision.metadata["displayScoreContextFit"] == "0.35")
        #expect(decision.metadata["displayScoreUserAffinity"] == "0.25")
        #expect(decision.metadata["displayScoreRisk"] == "0.10")
        #expect(decision.metadata["displayScoreRepetition"] == "0.05")
        #expect(decision.metadata["displayScoreInstability"] == "0.05")
        #expect(decision.metadata["displayScoreFinal"] == "1.50")
    }

    @Test("suppresses high risk even when the final score is high")
    func suppressesHighRiskEvenWhenFinalScoreIsHigh() {
        let policy = DisplayScorePolicy()
        let score = DisplayScore(
            utility: 1.00,
            styleFit: 1.00,
            contextFit: 1.00,
            userAffinity: 1.00,
            risk: 0.90,
            repetition: 0.00,
            instability: 0.00
        )

        let decision = policy.decision(for: score, mode: .phraseContinuation)

        #expect(abs(score.finalScore - 3.10) < 0.0001)
        #expect(!decision.shouldDisplay)
        #expect(decision.metadata["displayScoreDecision"] == "suppress")
        #expect(decision.metadata["displayScoreSuppressionReason"] == "high-risk")
        #expect(decision.metadata["displayScoreRisk"] == "0.90")
    }

    @Test("suppresses high repetition and high instability")
    func suppressesHighRepetitionAndHighInstability() {
        let policy = DisplayScorePolicy()

        let repeatedDecision = policy.decision(
            for: DisplayScore(
                utility: 1.00,
                styleFit: 1.00,
                contextFit: 1.00,
                userAffinity: 1.00,
                risk: 0.00,
                repetition: 0.90,
                instability: 0.00
            ),
            mode: .phraseContinuation
        )
        let unstableDecision = policy.decision(
            for: DisplayScore(
                utility: 1.00,
                styleFit: 1.00,
                contextFit: 1.00,
                userAffinity: 1.00,
                risk: 0.00,
                repetition: 0.00,
                instability: 0.90
            ),
            mode: .phraseContinuation
        )

        #expect(!repeatedDecision.shouldDisplay)
        #expect(repeatedDecision.metadata["displayScoreSuppressionReason"] == "high-repetition")
        #expect(repeatedDecision.metadata["displayScoreRepetition"] == "0.90")
        #expect(!unstableDecision.shouldDisplay)
        #expect(unstableDecision.metadata["displayScoreSuppressionReason"] == "high-instability")
        #expect(unstableDecision.metadata["displayScoreInstability"] == "0.90")
    }

    @Test("word phrase and sentence modes use different thresholds")
    func wordPhraseAndSentenceModesUseDifferentThresholds() {
        let policy = DisplayScorePolicy()
        let score = DisplayScore(
            utility: 0.45,
            styleFit: 0.20,
            contextFit: 0.20,
            userAffinity: 0.10,
            risk: 0.05,
            repetition: 0.05,
            instability: 0.05
        )

        let wordDecision = policy.decision(for: score, mode: .wordCompletion)
        let phraseDecision = policy.decision(for: score, mode: .phraseContinuation)
        let sentenceDecision = policy.decision(for: score, mode: .sentenceContinuation)

        #expect(abs(score.finalScore - 0.80) < 0.0001)
        #expect(policy.threshold(for: .wordCompletion) == 0.60)
        #expect(policy.threshold(for: .phraseContinuation) == 1.00)
        #expect(policy.threshold(for: .sentenceContinuation) == 1.20)
        #expect(wordDecision.shouldDisplay)
        #expect(wordDecision.metadata["displayScoreThreshold"] == "0.60")
        #expect(!phraseDecision.shouldDisplay)
        #expect(phraseDecision.metadata["displayScoreSuppressionReason"] == "below-threshold")
        #expect(phraseDecision.metadata["displayScoreThreshold"] == "1.00")
        #expect(!sentenceDecision.shouldDisplay)
        #expect(sentenceDecision.metadata["displayScoreSuppressionReason"] == "below-threshold")
        #expect(sentenceDecision.metadata["displayScoreThreshold"] == "1.20")
    }
}
