import Testing
import AutocompleteLabCore
@testable import AutocompleteLabApp
@testable import AutocompleteLabResearch

@Suite("Proof-only accept command")
struct ProofOnlyAcceptCommandTests {
    @Test("Accept command is opt-in and argument scoped")
    func acceptCommandIsOptInAndArgumentScoped() {
        #expect(ProofOnlyAcceptCommand.argument == "--proof-only-accept-next-word")
        #expect(ProofOnlyAcceptCommand.isRequested(arguments: ["SteadyType", "--proof-only-accept-next-word"]))
        #expect(!ProofOnlyAcceptCommand.isRequested(arguments: ["SteadyType"]))

        let key = ProofOnlyAcceptCommand.enabledEnvironmentKey
        #expect(!ProofOnlyAcceptCommand.isEnabled(environment: [:]))
        #expect(ProofOnlyAcceptCommand.isEnabled(environment: [key: "1"]))
        #expect(ProofOnlyAcceptCommand.isEnabled(environment: [key: "true"]))
        #expect(ProofOnlyAcceptCommand.isEnabled(environment: [key: "YES"]))
        #expect(ProofOnlyAcceptCommand.isEnabled(environment: [key: "on"]))
        #expect(!ProofOnlyAcceptCommand.isEnabled(environment: [key: "0"]))
        #expect(ProofOnlyAcceptCommand.run(environment: [:]) == 64)
    }

    @Test("Recent proof suggestion restore is tightly scoped")
    func recentProofSuggestionRestoreIsTightlyScoped() {
        let policy = ProofOnlyAcceptRecentSuggestionPolicy()
        let input = restoreInput()

        #expect(policy.decision(for: input) == .allow)

        #expect(policy.decision(for: restoreInput(proofModeEnabled: false)) == .block(.proofModeDisabled))
        #expect(policy.decision(for: restoreInput(hasVisibleSuggestion: true)) == .block(.alreadyVisible))
        #expect(policy.decision(for: restoreInput(suggestionBundleIdentifier: "md.obsidian")) == .block(.wrongSuggestionApp))
        #expect(policy.decision(for: restoreInput(currentProfileBundleIdentifier: "md.obsidian")) == .block(.wrongProfile))
        #expect(policy.decision(for: restoreInput(fieldClassification: nil)) == .block(.wrongFieldClassification))
        #expect(policy.decision(for: restoreInput(ageMilliseconds: nil)) == .block(.missingAge))
        #expect(policy.decision(for: restoreInput(ageMilliseconds: 15_001)) == .block(.stale))
        #expect(policy.decision(for: restoreInput(invalidatedByUserKeyDown: true)) == .block(.invalidatedByUserKeyDown))
        #expect(policy.decision(for: restoreInput(lastSnapshotMatchesShownText: false)) == .block(.focusedTextChanged))
        #expect(policy.decision(for: restoreInput(suggestionText: "   ")) == .block(.missingAcceptedText))
    }

    @Test("Recent proof suggestion grace is clamped")
    func recentProofSuggestionGraceIsClamped() {
        let key = ProofOnlyAcceptRecentSuggestionPolicy.recentSuggestionGraceEnvironmentKey

        #expect(ProofOnlyAcceptRecentSuggestionPolicy.recentSuggestionGraceMilliseconds(environment: [:]) == 5_000)
        #expect(ProofOnlyAcceptRecentSuggestionPolicy.recentSuggestionGraceMilliseconds(environment: [key: "12000"]) == 12_000)
        #expect(ProofOnlyAcceptRecentSuggestionPolicy.recentSuggestionGraceMilliseconds(environment: [key: "-1"]) == 0)
        #expect(ProofOnlyAcceptRecentSuggestionPolicy.recentSuggestionGraceMilliseconds(environment: [key: "999999"]) == 15_000)
        #expect(ProofOnlyAcceptRecentSuggestionPolicy.recentSuggestionGraceMilliseconds(environment: [key: "nope"]) == 5_000)
    }

    private func restoreInput(
        proofModeEnabled: Bool = true,
        hasVisibleSuggestion: Bool = false,
        suggestionBundleIdentifier: String? = ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
        currentProfileBundleIdentifier: String? = ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
        fieldClassification: AXFieldClassification? = ClaudeCodeTerminalHostProofPolicy.proofFieldClassification,
        ageMilliseconds: Int? = 5_000,
        invalidatedByUserKeyDown: Bool = false,
        suggestionText: String = " make this feel instant",
        lastSnapshotMatchesShownText: Bool = true
    ) -> ProofOnlyAcceptRecentSuggestionPolicy.RestoreInput {
        ProofOnlyAcceptRecentSuggestionPolicy.RestoreInput(
            proofModeEnabled: proofModeEnabled,
            hasVisibleSuggestion: hasVisibleSuggestion,
            suggestionBundleIdentifier: suggestionBundleIdentifier,
            currentProfileBundleIdentifier: currentProfileBundleIdentifier,
            fieldClassification: fieldClassification,
            ageMilliseconds: ageMilliseconds,
            invalidatedByUserKeyDown: invalidatedByUserKeyDown,
            suggestionText: suggestionText,
            lastSnapshotMatchesShownText: lastSnapshotMatchesShownText
        )
    }
}
