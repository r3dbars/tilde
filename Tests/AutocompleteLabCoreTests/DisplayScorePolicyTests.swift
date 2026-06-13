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
        #expect(decision.metadata["displayScoreThreshold"] == "1.10")
        #expect(decision.metadata["displayScoreUtility"] == "0.70")
        #expect(decision.metadata["displayScoreStyleFit"] == "0.40")
        #expect(decision.metadata["displayScoreContextFit"] == "0.35")
        #expect(decision.metadata["displayScoreUserAffinity"] == "0.25")
        #expect(decision.metadata["displayScoreRisk"] == "0.10")
        #expect(decision.metadata["displayScoreRepetition"] == "0.05")
        #expect(decision.metadata["displayScoreInstability"] == "0.05")
        #expect(decision.metadata["displayScoreLearningRestraint"] == "0.00")
        #expect(decision.metadata["displayScoreFinal"] == "1.50")
        #expect(decision.metadata["displayScoreEffectiveFinal"] == "1.50")
        #expect(decision.metadata["displayScoreLearningRestraintScale"] == "1.00")
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

    @Test("type-through credit can carry a survivor over the display threshold")
    func typeThroughCreditCanCarrySurvivorOverDisplayThreshold() {
        let policy = DisplayScorePolicy()
        let baseScore = DisplayScore(
            utility: 0.55,
            styleFit: 0.30,
            contextFit: 0.25,
            userAffinity: 0.10,
            risk: 0.05,
            repetition: 0.05,
            instability: 0.05
        )
        let creditedScore = DisplayScore(
            utility: 0.55,
            styleFit: 0.30,
            contextFit: 0.25,
            userAffinity: 0.10,
            risk: 0.05,
            repetition: 0.05,
            instability: 0.05,
            typeThroughSurvivalCount: 3,
            typeThroughConfidenceCredit: 0.12
        )

        let baseDecision = policy.decision(for: baseScore, mode: .phraseContinuation)
        let creditedDecision = policy.decision(for: creditedScore, mode: .phraseContinuation)

        #expect(!baseDecision.shouldDisplay)
        #expect(baseDecision.metadata["displayScoreSuppressionReason"] == "below-threshold")
        #expect(creditedDecision.shouldDisplay)
        #expect(creditedDecision.metadata["displayScoreTypeThroughSurvivals"] == "3")
        #expect(creditedDecision.metadata["displayScoreTypeThroughCredit"] == "0.12")
    }

    @Test("type-through credit does not bypass safety vetoes")
    func typeThroughCreditDoesNotBypassSafetyVetoes() {
        let policy = DisplayScorePolicy()
        let decision = policy.decision(
            for: DisplayScore(
                utility: 1.00,
                styleFit: 1.00,
                contextFit: 1.00,
                userAffinity: 1.00,
                risk: 0.90,
                repetition: 0.00,
                instability: 0.00,
                typeThroughSurvivalCount: 10,
                typeThroughConfidenceCredit: 0.30
            ),
            mode: .phraseContinuation
        )

        #expect(!decision.shouldDisplay)
        #expect(decision.metadata["displayScoreSuppressionReason"] == "high-risk")
    }

    @Test("one brain preview keeps default behavior behind the flag")
    func oneBrainPreviewKeepsDefaultBehaviorBehindTheFlag() {
        let policy = DisplayScorePolicy()
        let score = DisplayScore(
            utility: 1.00,
            styleFit: 1.00,
            contextFit: 1.00,
            userAffinity: 1.00,
            risk: 0.00,
            repetition: 0.90,
            instability: 0.00
        )

        let currentDecision = policy.decision(for: score, mode: .phraseContinuation)
        let previewDecision = policy.decision(
            for: score,
            mode: .phraseContinuation,
            suppressionBrain: .oneBrainPreview
        )

        #expect(!currentDecision.shouldDisplay)
        #expect(currentDecision.metadata["displayScoreSuppressionReason"] == "high-repetition")
        #expect(previewDecision.shouldDisplay)
        #expect(previewDecision.metadata["displayScoreDecision"] == "display")
        #expect(DisplayScoreSuppressionBrain.fromEnvironment([:]) == .current)
        #expect(DisplayScoreSuppressionBrain.fromEnvironment([
            DisplayScoreSuppressionBrain.environmentFlag: "1"
        ]) == .oneBrainPreview)
    }

    @Test("one brain preview keeps high risk as a hard safety veto")
    func oneBrainPreviewKeepsHighRiskAsHardSafetyVeto() {
        let policy = DisplayScorePolicy()
        let score = DisplayScore(
            utility: 1.00,
            styleFit: 1.00,
            contextFit: 1.00,
            userAffinity: 1.00,
            risk: 0.90,
            repetition: 0.90,
            instability: 0.00
        )

        let decision = policy.decision(
            for: score,
            mode: .phraseContinuation,
            suppressionBrain: .oneBrainPreview
        )

        #expect(!decision.shouldDisplay)
        #expect(decision.metadata["displayScoreSuppressionReason"] == "high-risk")
    }

    @Test("one brain preview emits one binding scored penalty reason")
    func oneBrainPreviewEmitsOneBindingScoredPenaltyReason() {
        let policy = DisplayScorePolicy()
        let learnedRestraintDecision = policy.decision(
            for: DisplayScore(
                utility: 0.70,
                styleFit: 0.40,
                contextFit: 0.35,
                userAffinity: 0.25,
                risk: 0.10,
                repetition: 0.05,
                instability: 0.05,
                learningRestraint: 0.75,
                acceptedAndKeptProbability: 0.17,
                acceptedAndKeptSampleCount: 4
            ),
            mode: .phraseContinuation,
            suppressionBrain: .oneBrainPreview
        )
        let noSinglePenaltyDecision = policy.decision(
            for: DisplayScore(
                utility: 0.35,
                styleFit: 0.20,
                contextFit: 0.20,
                userAffinity: 0.05,
                risk: 0.10,
                repetition: 0.10,
                instability: 0.10
            ),
            mode: .phraseContinuation,
            suppressionBrain: .oneBrainPreview
        )

        #expect(!learnedRestraintDecision.shouldDisplay)
        #expect(learnedRestraintDecision.metadata["displayScoreSuppressionReason"] == "learned-restraint")
        #expect(learnedRestraintDecision.metadata.filter { $0.key == "displayScoreSuppressionReason" }.count == 1)
        #expect(!noSinglePenaltyDecision.shouldDisplay)
        #expect(noSinglePenaltyDecision.metadata["displayScoreSuppressionReason"] == "below-threshold")
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
        #expect(policy.threshold(for: .phraseContinuation) == 1.10)
        #expect(policy.threshold(for: .sentenceContinuation) == 1.25)
        #expect(wordDecision.shouldDisplay)
        #expect(wordDecision.metadata["displayScoreThreshold"] == "0.60")
        #expect(!phraseDecision.shouldDisplay)
        #expect(phraseDecision.metadata["displayScoreSuppressionReason"] == "below-threshold")
        #expect(phraseDecision.metadata["displayScoreThreshold"] == "1.10")
        #expect(!sentenceDecision.shouldDisplay)
        #expect(sentenceDecision.metadata["displayScoreSuppressionReason"] == "below-threshold")
        #expect(sentenceDecision.metadata["displayScoreThreshold"] == "1.25")
    }

    @Test("threshold adjustment makes display policy less eager without weakening safety gates")
    func thresholdAdjustmentMakesDisplayPolicyLessEagerWithoutWeakeningSafetyGates() {
        let policy = DisplayScorePolicy()
        let adjusted = policy.adjustingThresholds(by: 0.30)
        let score = DisplayScore(
            utility: 0.70,
            styleFit: 0.40,
            contextFit: 0.20,
            userAffinity: 0.10,
            risk: 0.05,
            repetition: 0.05,
            instability: 0.05
        )

        let originalDecision = policy.decision(for: score, mode: .phraseContinuation)
        let adjustedDecision = adjusted.decision(for: score, mode: .phraseContinuation)

        #expect(originalDecision.shouldDisplay)
        #expect(!adjustedDecision.shouldDisplay)
        #expect(adjustedDecision.metadata["displayScoreSuppressionReason"] == "below-threshold")
        #expect(abs(adjusted.threshold(for: .wordCompletion) - 0.90) < 0.0001)
        #expect(abs(adjusted.threshold(for: .phraseContinuation) - 1.40) < 0.0001)
        #expect(adjusted.threshold(for: .sentenceContinuation) == 1.55)
        #expect(adjusted.highRiskThreshold == policy.highRiskThreshold)
        #expect(adjusted.highRepetitionThreshold == policy.highRepetitionThreshold)
        #expect(adjusted.highInstabilityThreshold == policy.highInstabilityThreshold)
    }

    @Test("low accepted and kept probability suppresses only after enough evidence")
    func lowAcceptedAndKeptProbabilitySuppressesOnlyAfterEnoughEvidence() {
        let policy = DisplayScorePolicy(minimumAcceptedAndKeptSamples: 4)
        let scoreWithoutEnoughEvidence = DisplayScore(
            utility: 0.80,
            styleFit: 0.60,
            contextFit: 0.55,
            userAffinity: 0.20,
            risk: 0.05,
            repetition: 0.05,
            instability: 0.05,
            acceptedAndKeptProbability: 0.01,
            acceptedAndKeptSampleCount: 3,
            acceptedAndKeptUtilityAdjustment: -0.04
        )
        let scoreWithEnoughEvidence = DisplayScore(
            utility: 0.80,
            styleFit: 0.60,
            contextFit: 0.55,
            userAffinity: 0.20,
            risk: 0.05,
            repetition: 0.05,
            instability: 0.05,
            acceptedAndKeptProbability: 0.01,
            acceptedAndKeptSampleCount: 4,
            acceptedAndKeptUtilityAdjustment: -0.04
        )

        let earlyDecision = policy.decision(
            for: scoreWithoutEnoughEvidence,
            mode: .phraseContinuation
        )
        let learnedDecision = policy.decision(
            for: scoreWithEnoughEvidence,
            mode: .phraseContinuation
        )

        #expect(earlyDecision.shouldDisplay)
        #expect(!learnedDecision.shouldDisplay)
        #expect(learnedDecision.metadata["displayScoreSuppressionReason"] == "low-accepted-and-kept-probability")
        #expect(learnedDecision.metadata["displayScoreAcceptedAndKeptProbability"] == "0.01")
        #expect(learnedDecision.metadata["displayScoreAcceptedAndKeptSamples"] == "4")
        #expect(learnedDecision.metadata["displayScoreAcceptedAndKeptThreshold"] == "0.30")
        #expect(learnedDecision.metadata["displayScoreAcceptedAndKeptUtilityAdjustment"] == "-0.04")
    }

    @Test("low kept restraint can suppress before the hard probability gate")
    func lowKeptRestraintCanSuppressBeforeHardProbabilityGate() {
        let policy = DisplayScorePolicy(minimumAcceptedAndKeptSamples: 6)
        let freshScore = DisplayScore(
            utility: 0.70,
            styleFit: 0.40,
            contextFit: 0.35,
            userAffinity: 0.25,
            risk: 0.10,
            repetition: 0.05,
            instability: 0.05,
            acceptedAndKeptProbability: 0.34,
            acceptedAndKeptSampleCount: 0,
            acceptedAndKeptUtilityAdjustment: 0
        )
        let lowKeptScore = DisplayScore(
            utility: 0.70,
            styleFit: 0.40,
            contextFit: 0.35,
            userAffinity: 0.25,
            risk: 0.10,
            repetition: 0.05,
            instability: 0.05,
            learningRestraint: 0.75,
            acceptedAndKeptProbability: 0.17,
            acceptedAndKeptSampleCount: 4,
            acceptedAndKeptUtilityAdjustment: -0.04
        )

        let freshDecision = policy.decision(for: freshScore, mode: .phraseContinuation)
        let lowKeptDecision = policy.decision(for: lowKeptScore, mode: .phraseContinuation)

        #expect(freshDecision.shouldDisplay)
        #expect(!lowKeptDecision.shouldDisplay)
        #expect(lowKeptDecision.metadata["displayScoreSuppressionReason"] == "below-threshold")
        #expect(lowKeptDecision.metadata["displayScoreLearningRestraint"] == "0.75")
        #expect(lowKeptDecision.metadata["displayScoreEffectiveFinal"] == "0.75")
        #expect(lowKeptDecision.metadata["displayScoreAcceptedAndKeptSamples"] == "4")
    }

    @Test("learning restraint can be loosened or tightened by tuning")
    func learningRestraintCanBeLoosenedOrTightenedByTuning() {
        let loosePolicy = DisplayScorePolicy().withLearningRestraint(
            acceptedAndKeptProbabilityMultiplier: 0,
            learningRestraintScoreScale: 0,
            minimumAcceptedAndKeptSamples: Int.max / 4
        )
        let looseScore = DisplayScore(
            utility: 0.70,
            styleFit: 0.40,
            contextFit: 0.35,
            userAffinity: 0.25,
            risk: 0.10,
            repetition: 0.05,
            instability: 0.05,
            learningRestraint: 0.75,
            acceptedAndKeptProbability: 0.01,
            acceptedAndKeptSampleCount: 100
        )

        let looseDecision = loosePolicy.decision(for: looseScore, mode: .phraseContinuation)

        #expect(looseDecision.shouldDisplay)
        #expect(looseDecision.metadata["displayScoreFinal"] == "0.75")
        #expect(looseDecision.metadata["displayScoreEffectiveFinal"] == "1.50")
        #expect(looseDecision.metadata["displayScoreLearningRestraintScale"] == "0.00")
        #expect(looseDecision.metadata["displayScoreAcceptedAndKeptThreshold"] == "0.00")

        let strictPolicy = DisplayScorePolicy().withLearningRestraint(
            acceptedAndKeptProbabilityMultiplier: 1.25,
            learningRestraintScoreScale: 1.25,
            minimumAcceptedAndKeptSamples: 3
        )
        let strictScore = DisplayScore(
            utility: 0.90,
            styleFit: 0.50,
            contextFit: 0.30,
            userAffinity: 0.25,
            risk: 0.05,
            repetition: 0.05,
            instability: 0.05,
            learningRestraint: 0.60,
            acceptedAndKeptProbability: 0.50,
            acceptedAndKeptSampleCount: 3
        )

        let strictDecision = strictPolicy.decision(for: strictScore, mode: .phraseContinuation)

        #expect(!strictDecision.shouldDisplay)
        #expect(strictDecision.metadata["displayScoreFinal"] == "1.20")
        #expect(strictDecision.metadata["displayScoreEffectiveFinal"] == "1.05")
        #expect(strictDecision.metadata["displayScoreLearningRestraintScale"] == "1.25")
        #expect(strictDecision.metadata["displayScoreAcceptedAndKeptThreshold"] == "0.38")
        #expect(strictDecision.metadata["displayScoreSuppressionReason"] == "below-threshold")
    }

    @Test("profile-aware kept probability stays stricter in AI chat after evidence")
    func profileAwareKeptProbabilityStaysStricterInAIChatAfterEvidence() {
        let policy = DisplayScorePolicy(minimumAcceptedAndKeptSamples: 6)
        let score = DisplayScore(
            utility: 0.80,
            styleFit: 0.60,
            contextFit: 0.55,
            userAffinity: 0.20,
            risk: 0.05,
            repetition: 0.05,
            instability: 0.05,
            acceptedAndKeptProbability: 0.31,
            acceptedAndKeptSampleCount: 6,
            acceptedAndKeptUtilityAdjustment: 0
        )
        let scoreWithoutEnoughEvidence = DisplayScore(
            utility: 0.80,
            styleFit: 0.60,
            contextFit: 0.55,
            userAffinity: 0.20,
            risk: 0.05,
            repetition: 0.05,
            instability: 0.05,
            acceptedAndKeptProbability: 0.31,
            acceptedAndKeptSampleCount: 5,
            acceptedAndKeptUtilityAdjustment: 0
        )

        let genericDecision = policy.decision(
            for: score,
            mode: .phraseContinuation
        )
        let earlyAIChatDecision = policy.decision(
            for: scoreWithoutEnoughEvidence,
            mode: .phraseContinuation,
            behaviorProfileID: .aiChat
        )
        let learnedAIChatDecision = policy.decision(
            for: score,
            mode: .phraseContinuation,
            behaviorProfileID: .aiChat
        )

        #expect(genericDecision.shouldDisplay)
        #expect(genericDecision.metadata["displayScoreAcceptedAndKeptThreshold"] == "0.30")
        #expect(earlyAIChatDecision.shouldDisplay)
        #expect(earlyAIChatDecision.metadata["displayScoreAcceptedAndKeptThreshold"] == "0.34")
        #expect(!learnedAIChatDecision.shouldDisplay)
        #expect(learnedAIChatDecision.metadata["displayScoreBehaviorProfile"] == "ai_chat")
        #expect(learnedAIChatDecision.metadata["displayScoreAcceptedAndKeptThreshold"] == "0.34")
        #expect(learnedAIChatDecision.metadata["displayScoreSuppressionReason"] == "low-accepted-and-kept-probability")
    }

    @Test("profile-aware kept probability is stricter for sentence-like prose")
    func profileAwareKeptProbabilityIsStricterForSentenceLikeProse() {
        let policy = DisplayScorePolicy()
        let score = DisplayScore(
            utility: 0.90,
            styleFit: 0.65,
            contextFit: 0.55,
            userAffinity: 0.20,
            risk: 0.05,
            repetition: 0.05,
            instability: 0.05,
            acceptedAndKeptProbability: 0.20,
            acceptedAndKeptSampleCount: 6,
            acceptedAndKeptUtilityAdjustment: 0
        )

        let genericDecision = policy.decision(
            for: score,
            mode: .sentenceContinuation
        )
        let docsDecision = policy.decision(
            for: score,
            mode: .sentenceContinuation,
            behaviorProfileID: .docsProse
        )

        #expect(genericDecision.shouldDisplay)
        #expect(genericDecision.metadata["displayScoreAcceptedAndKeptThreshold"] == "0.18")
        #expect(!docsDecision.shouldDisplay)
        #expect(docsDecision.metadata["displayScoreBehaviorProfile"] == "docs_prose")
        #expect(docsDecision.metadata["displayScoreAcceptedAndKeptThreshold"] == "0.22")
        #expect(docsDecision.metadata["displayScoreSuppressionReason"] == "low-accepted-and-kept-probability")
    }
}
