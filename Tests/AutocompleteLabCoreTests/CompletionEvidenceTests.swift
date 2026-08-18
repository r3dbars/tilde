import Testing
@testable import AutocompleteLabCore

@Suite("Completion uncertainty evidence")
struct CompletionEvidenceTests {
    @Test("Probabilities are bounded and content stays explicit")
    func clampsProbabilities() {
        let token = CompletionTokenEvidence(
            text: " hello",
            probability: 1.4,
            alternatives: [
                .init(text: " hey", probability: -0.2),
                .init(text: " hi", probability: 0.3),
            ]
        )
        #expect(token.text == " hello")
        #expect(token.probability == 1)
        #expect(token.alternatives[0].probability == 0)
        #expect(token.alternatives[1].probability == 0.3)
    }

    @Test("Empty traces explicitly mean uncertainty is unavailable")
    func emptyTrace() {
        let evidence = CompletionEvidence(suggestion: nil, tokens: [])
        #expect(!evidence.hasUncertainty)
    }
}
