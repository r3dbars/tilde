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
            acceptedText: " keep ",
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

    @Test("Next word accept allows a synthetic trailing space after the final visible word")
    func nextWordAcceptAllowsSyntheticTrailingSpaceAfterFinalVisibleWord() throws {
        let decision = policy.decision(
            action: .acceptNextWord,
            acceptedText: " keep ",
            visibleText: " keep"
        )

        let proof = try #require(allowedProof(from: decision))
        #expect(proof.scope == .nextWordPrefix)
        #expect(!proof.acceptedTextMatchesVisible)
        #expect(proof.acceptedTextIsVisiblePrefix)
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

@Suite("Acceptance safety policy")
struct AcceptanceSafetyPolicyTests {
    private let policy = AcceptanceSafetyPolicy()

    @Test("No-submit profiles allow one visible word")
    func noSubmitProfilesAllowOneVisibleWord() {
        let decision = policy.decision(
            action: .acceptNextWord,
            acceptedText: " keep ",
            visibleText: " keep it small",
            profile: noSubmitProfile()
        )

        #expect(decision == .allowed)
    }

    @Test("No-submit profiles block full visible accept")
    func noSubmitProfilesBlockFullVisibleAccept() {
        let decision = policy.decision(
            action: .acceptAllVisible,
            acceptedText: " keep it small",
            visibleText: " keep it small",
            profile: noSubmitProfile()
        )

        #expect(decision == .blocked(.noSubmitProfileDisallowsFullAcceptance))
    }

    @Test("No-submit profiles block multiword accepted text")
    func noSubmitProfilesBlockMultiwordAcceptedText() {
        let decision = policy.decision(
            action: .acceptNextWord,
            acceptedText: " keep going",
            visibleText: " keep going",
            profile: noSubmitProfile()
        )

        #expect(decision == .blocked(.noSubmitProfileRequiresSingleWord))
    }

    @Test("Acceptance safety blocks control text")
    func acceptanceSafetyBlocksControlText() {
        #expect(policy.decision(
            action: .acceptNextWord,
            acceptedText: " keep\n",
            visibleText: " keep\n",
            profile: standardProfile()
        ) == .blocked(.acceptedTextContainsNewline))

        #expect(policy.decision(
            action: .acceptNextWord,
            acceptedText: " keep\t",
            visibleText: " keep\t",
            profile: standardProfile()
        ) == .blocked(.acceptedTextContainsTab))
    }

    @Test("Acceptance safety requires accepted text to be visible")
    func acceptanceSafetyRequiresAcceptedTextToBeVisible() {
        let decision = policy.decision(
            action: .acceptNextWord,
            acceptedText: " ship",
            visibleText: " keep it small",
            profile: standardProfile()
        )

        #expect(decision == .blocked(.acceptedTextNotVisible))
    }

    @Test("Profile support flags block unsupported acceptance actions")
    func profileSupportFlagsBlockUnsupportedAcceptanceActions() {
        #expect(policy.decision(
            action: .acceptNextWord,
            acceptedText: " keep",
            visibleText: " keep",
            profile: standardProfile(supportsOneWordAcceptance: false)
        ) == .blocked(.profileDisallowsOneWordAcceptance))

        #expect(policy.decision(
            action: .acceptAllVisible,
            acceptedText: " keep",
            visibleText: " keep",
            profile: standardProfile(supportsFullAcceptance: false)
        ) == .blocked(.profileDisallowsFullAcceptance))
    }

    @Test("Standard profiles allow full visible accept")
    func standardProfilesAllowFullVisibleAccept() {
        let decision = policy.decision(
            action: .acceptAllVisible,
            acceptedText: " keep it small",
            visibleText: " keep it small",
            profile: standardProfile()
        )

        #expect(decision == .allowed)
    }

    private func noSubmitProfile() -> CompatibilityProfile {
        standardProfile(
            supportsFullAcceptance: false,
            requiresNoSubmitAcceptanceProof: true
        )
    }

    private func standardProfile(
        supportsOneWordAcceptance: Bool = true,
        supportsFullAcceptance: Bool = true,
        requiresNoSubmitAcceptanceProof: Bool = false
    ) -> CompatibilityProfile {
        CompatibilityProfile(
            bundleIdentifier: "com.example.Editor",
            displayName: "Editor",
            supportLevel: .yellow,
            supportReason: "Test profile.",
            renderMode: .inlineAdjacent,
            insertionMode: .keyEvents,
            supportsOneWordAcceptance: supportsOneWordAcceptance,
            supportsFullAcceptance: supportsFullAcceptance,
            requiresNoSubmitAcceptanceProof: requiresNoSubmitAcceptanceProof,
            notes: "Test profile."
        )
    }
}
