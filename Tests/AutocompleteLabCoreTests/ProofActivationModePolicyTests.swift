import Testing
@testable import AutocompleteLabCore
@testable import AutocompleteLabResearch

@Suite("Proof activation mode policy")
struct ProofActivationModePolicyTests {
    private let policy = ProofActivationModePolicy()

    @Test("Falls back to word completion when phrase proof is disabled")
    func fallsBackToWordCompletionWhenPhraseProofIsDisabled() {
        let result = policy.adjustedDecision(
            original: .allow(.phraseContinuation),
            wordFallback: .allow(.wordCompletion),
            disablesPhraseContinuation: true,
            disablesWordCompletion: false
        )

        #expect(result == .allow(.wordCompletion))
    }

    @Test("Keeps phrase continuation when word completion is disabled")
    func keepsPhraseContinuationWhenWordCompletionIsDisabled() {
        let result = policy.adjustedDecision(
            original: .allow(.phraseContinuation),
            wordFallback: .allow(.wordCompletion),
            disablesPhraseContinuation: true,
            disablesWordCompletion: true
        )

        #expect(result == .allow(.phraseContinuation))
    }

    @Test("Keeps original decision without a word fallback")
    func keepsOriginalDecisionWithoutWordFallback() {
        let result = policy.adjustedDecision(
            original: .allow(.phraseContinuation),
            wordFallback: .block(.unfinishedWord),
            disablesPhraseContinuation: true,
            disablesWordCompletion: false
        )

        #expect(result == .allow(.phraseContinuation))
    }

    @Test("Keeps original word completion")
    func keepsOriginalWordCompletion() {
        let result = policy.adjustedDecision(
            original: .allow(.wordCompletion),
            wordFallback: .allow(.wordCompletion),
            disablesPhraseContinuation: true,
            disablesWordCompletion: false
        )

        #expect(result == .allow(.wordCompletion))
    }
}
