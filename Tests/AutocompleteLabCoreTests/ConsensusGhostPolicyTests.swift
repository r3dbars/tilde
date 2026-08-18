import Testing
@testable import AutocompleteLabCore

@Suite("Consensus ghost confidence policy")
struct ConsensusGhostPolicyTests {
    @Test("A confidence cliff before a new word shortens at the stable prefix")
    func shortensAtWordBoundary() {
        let tokens = [
            CompletionTokenEvidence(text: " I", probability: 0.9),
            CompletionTokenEvidence(text: " think", probability: 0.8),
            CompletionTokenEvidence(text: " we", probability: 0.1),
        ]
        #expect(ConsensusGhostPolicy.visibleWordBudget(tokens: tokens, currentVisibleWords: 6) == 2)
    }

    @Test("A cliff inside a split token does not count the partial word")
    func dropsPartialTrailingWord() {
        let tokens = [
            CompletionTokenEvidence(text: " comp", probability: 0.9),
            CompletionTokenEvidence(text: "lete", probability: 0.1),
        ]
        #expect(ConsensusGhostPolicy.visibleWordBudget(tokens: tokens, currentVisibleWords: 4) == 1)
    }

    @Test("Strong trace and unavailable trace preserve the current ghost")
    func standsDown() {
        #expect(ConsensusGhostPolicy.visibleWordBudget(tokens: [], currentVisibleWords: 5) == nil)
        let strong = [
            CompletionTokenEvidence(text: " sounds", probability: 0.8),
            CompletionTokenEvidence(text: " good", probability: 0.7),
        ]
        #expect(ConsensusGhostPolicy.visibleWordBudget(tokens: strong, currentVisibleWords: 2) == nil)
    }

    @Test("Threshold is bounded and policy never lengthens")
    func boundedThreshold() {
        let tokens = [CompletionTokenEvidence(text: " hello", probability: 0.1)]
        #expect(ConsensusGhostPolicy.visibleWordBudget(tokens: tokens, currentVisibleWords: 1) == nil)
        #expect(ConsensusGhostPolicy.visibleWordBudget(tokens: tokens, currentVisibleWords: 3, threshold: 2) == 1)
    }
}
