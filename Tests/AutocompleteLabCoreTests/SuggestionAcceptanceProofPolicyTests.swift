import Testing
@testable import AutocompleteLabCore

@Suite("Suggestion acceptance proof policy")
struct SuggestionAcceptanceProofPolicyTests {
    private let policy = SuggestionAcceptanceProofPolicy()

    @Test("Full visible accept must exactly match visible text")
    func fullVisibleAcceptMustExactlyMatchVisibleText() throws {
        let decision = policy.decision(
            action: .acceptAllVisible,
            acceptedText: " keep it small",
            visibleText: " keep it small"
        )

        let proof = try #require(allowedProof(from: decision))
        #expect(proof.scope == .fullVisible)
        #expect(proof.acceptedTextMatchesVisible)
        #expect(proof.acceptedTextIsVisiblePrefix)
    }

    @Test("Full visible accept blocks mismatched text")
    func fullVisibleAcceptBlocksMismatchedText() {
        let decision = policy.decision(
            action: .acceptAllVisible,
            acceptedText: " keep it small today",
            visibleText: " keep it small"
        )

        #expect(decision == .blocked(.fullVisibleMismatch))
    }

    @Test("Next word accept proves the accepted text is the visible prefix")
    func nextWordAcceptProvesVisiblePrefix() throws {
        let decision = policy.decision(
            action: .acceptNextWord,
            acceptedText: " keep",
            visibleText: " keep it small"
        )

        let proof = try #require(allowedProof(from: decision))
        #expect(proof.scope == .nextWordPrefix)
        #expect(!proof.acceptedTextMatchesVisible)
        #expect(proof.acceptedTextIsVisiblePrefix)
        #expect(proof.traceMetadata["acceptedVisibleScope"] == "nextWordPrefix")
        #expect(proof.traceMetadata["acceptedTextMatchesVisible"] == "false")
        #expect(proof.traceMetadata["acceptedTextIsVisiblePrefix"] == "true")
    }

    @Test("Next word accept blocks non-prefix text")
    func nextWordAcceptBlocksNonPrefixText() {
        let decision = policy.decision(
            action: .acceptNextWord,
            acceptedText: " ship",
            visibleText: " keep it small"
        )

        #expect(decision == .blocked(.nextWordMismatch))
    }

    @Test("Acceptance proof requires visible text")
    func acceptanceProofRequiresVisibleText() {
        let decision = policy.decision(
            action: .acceptAllVisible,
            acceptedText: " keep it small",
            visibleText: nil
        )

        #expect(decision == .blocked(.missingVisibleText))
    }

    @Test("Trace metadata is shape only")
    func traceMetadataIsShapeOnly() throws {
        let secretVisibleText = " private project codename"
        let decision = policy.decision(
            action: .acceptAllVisible,
            acceptedText: secretVisibleText,
            visibleText: secretVisibleText
        )

        let proof = try #require(allowedProof(from: decision))
        let metadata = proof.traceMetadata

        #expect(metadata["acceptanceProof"] == "passed")
        #expect(metadata["acceptedVisibleScope"] == "fullVisible")
        #expect(metadata["acceptedTextMatchesVisible"] == "true")
        #expect(metadata["acceptedTextIsVisiblePrefix"] == "true")
        #expect(metadata["acceptedChars"] == String(secretVisibleText.count))
        #expect(metadata["visibleChars"] == String(secretVisibleText.count))
        #expect(!metadata.values.contains(secretVisibleText))
    }

    private func allowedProof(
        from decision: SuggestionAcceptanceProofDecision
    ) -> SuggestionAcceptanceProof? {
        guard case let .allowed(proof) = decision else {
            return nil
        }

        return proof
    }
}
