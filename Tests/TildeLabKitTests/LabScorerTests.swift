import Foundation
import Testing
@testable import TildeLabKit

@Suite("Tilde Lab scoring")
struct LabScorerTests {
    @Test("A matching continuation earns useful credit and saved keystrokes")
    func usefulContinuation() {
        let result = LabScorer.score(
            scenario: scenario(),
            repetition: 0,
            suggestion: " revised budget before noon",
            latencyMilliseconds: 120,
            workerIndex: 1
        )
        #expect(result.outcome == .useful)
        #expect(result.exactMatchAt3)
        #expect(result.exactContinuationMatched)
        #expect(result.answerMatchKind == .exactPrediction)
        #expect(result.keystrokesSaved > 0)
        #expect(result.netKeystrokesSaved == result.grossKeystrokesSaved - 1)
    }

    @Test("A matching first word does not make a divergent reply acceptable")
    func firstWordIsDiagnosticNotSemanticAcceptance() {
        let value = LabScenario(
            id: "reply.partial",
            category: "reply.answer",
            typedContext: "That ",
            expectation: LabExpectation(
                shouldSuggest: true,
                goldenContinuation: "works for me."
            )
        )
        let result = LabScorer.score(
            scenario: value,
            repetition: 0,
            suggestion: "works perfectly on my end."
        )
        #expect(result.outcome == .wrong)
        #expect(result.exactMatchAt1)
        #expect(!result.exactContinuationMatched)
        #expect(result.answerMatchKind == .none)
        #expect(result.grossKeystrokesSaved == "works".count)
        #expect(result.netKeystrokesSaved == "works".count - 2)
    }

    @Test("A bad display costs net keystrokes instead of averaging away")
    func badDisplayCost() {
        let result = LabScorer.score(
            scenario: scenario(),
            repetition: 0,
            suggestion: " unrelated interruption"
        )
        #expect(result.outcome == .wrong)
        #expect(result.grossKeystrokesSaved == 0)
        #expect(result.dismissalKeystrokes == 1)
        #expect(result.netKeystrokesSaved == -1)
    }

    @Test("A forbidden factual substitution is wrong even when the first word matches")
    func forbiddenFact() {
        let result = LabScorer.score(
            scenario: scenario(),
            repetition: 0,
            suggestion: " revised budget before tomorrow"
        )
        #expect(result.outcome == .wrong)
        #expect(result.forbiddenTermViolation)
    }

    @Test("Required keywords cannot rescue an answer that misses the accepted continuation")
    func requiredTermsAreNotEnough() {
        let value = LabScenario(
            id: "reply.strict-prefix",
            category: "reply.commit",
            typedContext: "I can ",
            expectation: LabExpectation(
                shouldSuggest: true,
                goldenContinuation: "send the budget before noon",
                acceptablePrefixes: ["send the budget"],
                requiredTerms: ["budget", "noon"]
            )
        )
        let result = LabScorer.score(
            scenario: value,
            repetition: 0,
            suggestion: "mention budget and noon without answering"
        )
        #expect(result.requiredTermsSatisfied)
        #expect(!result.acceptablePrefixMatched)
        #expect(result.outcome == .wrong)
    }

    @Test("Speaking in a silence case is unwanted")
    func unwantedSuggestion() {
        let quiet = LabScenario(
            id: "silence.test",
            category: "silence.sensitive",
            typedContext: "I am ",
            expectation: LabExpectation(shouldSuggest: false)
        )
        let result = LabScorer.score(
            scenario: quiet,
            repetition: 0,
            suggestion: " sorry to hear that"
        )
        #expect(result.outcome == .unwanted)
    }

    @Test("A meaning-level alternative is useful without pretending to match the recorded text")
    func acceptableSemanticAlternative() {
        let value = LabScenario(
            id: "reply.alternative",
            category: "reply.answer",
            typedContext: "I can ",
            expectation: LabExpectation(
                shouldSuggest: true,
                goldenContinuation: "send the revised budget this afternoon",
                acceptableContinuations: ["share the updated budget this afternoon"],
                requiredTerms: ["budget", "afternoon"],
                maximumWords: 8
            )
        )
        let result = LabScorer.score(
            scenario: value,
            repetition: 0,
            suggestion: "share the updated budget this afternoon"
        )
        #expect(result.acceptableContinuationMatched)
        #expect(result.outcome == .useful)
        #expect(result.answerMatchKind == .acceptableAlternative)
        #expect(!result.exactContinuationMatched)
        #expect(result.netKeystrokesSaved == 0)
        let aggregate = LabScorer.aggregate([result], elapsedSeconds: 1)
        #expect(aggregate.usefulnessRate == 1)
        #expect(aggregate.exactPredictionRate == 0)
        #expect(aggregate.acceptableAlternativeRate == 1)
    }

    @Test("A short accepted path need not contain facts that occur later in the full reply")
    func partialAcceptedPath() {
        let value = LabScenario(
            id: "reply.partial-path",
            category: "reply.commit",
            typedContext: "I can ",
            expectation: LabExpectation(
                shouldSuggest: true,
                goldenContinuation: "send the budget to Maya before noon",
                acceptableContinuations: ["share the updated budget with Maya before noon"],
                requiredTerms: ["budget", "Maya", "noon"]
            )
        )

        let exactPrefix = LabScorer.score(
            scenario: value,
            repetition: 0,
            suggestion: "send the budget"
        )
        #expect(exactPrefix.outcome == .useful)
        #expect(exactPrefix.answerMatchKind == .exactPrediction)
        #expect(!exactPrefix.requiredTermsSatisfied)

        let alternativePrefix = LabScorer.score(
            scenario: value,
            repetition: 1,
            suggestion: "share the updated"
        )
        #expect(alternativePrefix.outcome == .useful)
        #expect(alternativePrefix.answerMatchKind == .acceptableAlternative)
        #expect(!alternativePrefix.requiredTermsSatisfied)
    }

    @Test("Loose word overlap cannot turn a changed fact into an accepted alternative")
    func overlapDoesNotHideChangedFact() {
        let value = LabScenario(
            id: "reply.changed-fact",
            category: "reply.commit",
            typedContext: "I can ",
            expectation: LabExpectation(
                shouldSuggest: true,
                goldenContinuation: "send the budget to Maya by Friday",
                acceptableContinuations: ["deliver the budget to Maya by Friday"]
            )
        )
        let result = LabScorer.score(
            scenario: value,
            repetition: 0,
            suggestion: "deliver the budget to Noah by Friday"
        )
        #expect(result.outcome == .wrong)
        #expect(!result.acceptableContinuationMatched)
        #expect(result.answerMatchKind == .none)
    }

    @Test("Any timeout withholds the aggregate score")
    func incompleteRun() {
        let successful = LabScorer.score(
            scenario: scenario(),
            repetition: 0,
            suggestion: " revised budget before noon"
        )
        let timeout = LabScorer.failure(
            scenario: scenario(),
            repetition: 1,
            outcome: .timeout,
            workerIndex: 0
        )
        let aggregate = LabScorer.aggregate([successful, timeout], elapsedSeconds: 1)
        #expect(!aggregate.complete)
        #expect(aggregate.replyScore == nil)
        #expect(aggregate.qualityScore == nil)
        #expect(aggregate.promotionEligible == false)
        #expect(aggregate.promotionGateFailures.contains("incomplete-run"))
    }

    @Test("The model quality score is quality-only and does not require silence or latency cases")
    func modelOutputQualityScore() {
        let useful = LabScorer.score(
            scenario: scenario(),
            repetition: 0,
            suggestion: "revised budget before noon",
            modelRequested: true
        )
        let wrong = LabScorer.score(
            scenario: scenario(),
            repetition: 1,
            suggestion: "unrelated interruption",
            modelRequested: true
        )
        let scoring = LabScoringConfiguration(
            policyVersion: LabScoringConfiguration.modelOutputQualityPolicy
        )

        let aggregate = LabScorer.aggregate([useful, wrong], elapsedSeconds: 1, scoring: scoring)

        #expect(aggregate.usefulnessRate == 0.5)
        #expect(aggregate.qualityScore == 50)
        #expect(aggregate.promotionEligible == nil)
    }

    @Test("A perfect V3 run passes every fixed promotion gate")
    func perfectV3Promotion() {
        let results = [
            scored(id: "reply.a", category: "reply.answer", pair: "pair-answer-0", shouldSuggest: true, suggestion: "answer now"),
            scored(id: "reply.b", category: "reply.answer", pair: "pair-answer-0", shouldSuggest: true, suggestion: "answer now"),
            scored(id: "quiet.a", category: "silence.ordinary.no-request", pair: "pair-quiet-0", shouldSuggest: false, suggestion: nil),
            scored(id: "quiet.b", category: "silence.ordinary.no-request", pair: "pair-quiet-0", shouldSuggest: false, suggestion: nil),
            scored(id: "sensitive.a", category: "silence.sensitive.medical", pair: "pair-sensitive-0", shouldSuggest: false, suggestion: nil, modelRequested: false),
            scored(id: "sensitive.b", category: "silence.sensitive.medical", pair: "pair-sensitive-0", shouldSuggest: false, suggestion: nil, modelRequested: false),
        ]
        let aggregate = LabScorer.aggregate(results, elapsedSeconds: 1)

        #expect(aggregate.qualityScore == 100)
        #expect(aggregate.ordinaryRestraintRate == 1)
        #expect(aggregate.sensitiveRestraintRate == 1)
        #expect(aggregate.counterfactualPairPassRate == 1)
        #expect(aggregate.promotionEligible == true)
        #expect(aggregate.promotionGateFailures.isEmpty)
    }

    @Test("A zero behavioral component is harshly capped without flattening the score")
    func weakLinkScore() {
        let results = [
            scored(id: "reply.a", category: "reply.answer", pair: "pair-answer-0", shouldSuggest: true, suggestion: "answer now"),
            scored(id: "reply.b", category: "reply.answer", pair: "pair-answer-0", shouldSuggest: true, suggestion: "answer now"),
            scored(id: "quiet.a", category: "silence.ordinary.no-request", pair: "pair-quiet-0", shouldSuggest: false, suggestion: "unwanted words"),
            scored(id: "quiet.b", category: "silence.ordinary.no-request", pair: "pair-quiet-0", shouldSuggest: false, suggestion: "unwanted words"),
            scored(id: "sensitive.a", category: "silence.sensitive.medical", pair: "pair-sensitive-0", shouldSuggest: false, suggestion: nil, modelRequested: false),
            scored(id: "sensitive.b", category: "silence.sensitive.medical", pair: "pair-sensitive-0", shouldSuggest: false, suggestion: nil, modelRequested: false),
        ]
        let aggregate = LabScorer.aggregate(results, elapsedSeconds: 1)

        #expect(aggregate.usefulnessRate == 1)
        #expect(aggregate.exactPredictionRate == 1)
        #expect(aggregate.acceptableAlternativeRate == 0)
        #expect(aggregate.ordinaryRestraintRate == 0)
        #expect(aggregate.qualityScore == 25)
        #expect(aggregate.promotionEligible == false)
    }

    private func scenario() -> LabScenario {
        LabScenario(
            id: "reply.budget",
            category: "reply.commit",
            typedContext: "I can send the ",
            expectation: LabExpectation(
                shouldSuggest: true,
                goldenContinuation: "revised budget before noon",
                requiredTerms: ["budget", "noon"],
                forbiddenTerms: ["tomorrow"]
            )
        )
    }

    private func scored(
        id: String,
        category: String,
        pair: String,
        shouldSuggest: Bool,
        suggestion: String?,
        modelRequested: Bool = true
    ) -> LabCaseResult {
        let value = LabScenario(
            id: id,
            category: category,
            tags: [pair],
            typedContext: "I ",
            expectation: LabExpectation(
                shouldSuggest: shouldSuggest,
                goldenContinuation: shouldSuggest ? "answer now" : nil,
                acceptablePrefixes: shouldSuggest ? ["answer now"] : [],
                requiredTerms: shouldSuggest ? ["answer"] : [],
                maximumWords: 4
            )
        )
        return LabScorer.score(
            scenario: value,
            repetition: 0,
            suggestion: suggestion,
            policySuppressed: !modelRequested,
            modelRequested: modelRequested,
            latencyMilliseconds: modelRequested ? 100 : nil,
            decisionReason: modelRequested ? (suggestion == nil ? .emptyOutput : .shown) : .sensitiveScene
        )
    }
}
