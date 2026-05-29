import AutocompleteLabCore
import Testing
@testable import AutocompleteLabApp

@Suite("Suggestion replacement visibility policy")
struct SuggestionReplacementVisibilityPolicyTests {
    private let policy = SuggestionReplacementVisibilityPolicy()

    @Test("Presents proposed suggestions when replacement is allowed")
    func presentsProposedWhenReplacementIsAllowed() {
        let decision = SuggestionReplacementDecision(shouldPresent: true)

        #expect(policy.action(for: decision, hasVisibleSuggestion: true) == .presentProposed)
    }

    @Test("Keeps current suggestion visible when a fresh replacement is suppressed")
    func keepsCurrentSuggestionVisibleWhenFreshReplacementIsSuppressed() {
        let decision = SuggestionReplacementDecision(
            shouldPresent: false,
            reason: .freshVisibleSuggestion,
            currentAgeMilliseconds: 240,
            scoreMargin: 0.10
        )

        #expect(policy.action(for: decision, hasVisibleSuggestion: true) == .keepCurrentVisible)
    }

    @Test("Hides invalidated current suggestion when a replacement is suppressed")
    func hidesInvalidatedCurrentSuggestionWhenReplacementIsSuppressed() {
        let decision = SuggestionReplacementDecision(
            shouldPresent: false,
            reason: .freshVisibleSuggestion,
            currentAgeMilliseconds: 240,
            scoreMargin: 0.10
        )

        #expect(policy.action(
            for: decision,
            hasVisibleSuggestion: true,
            currentSuggestionInvalidatedByUserTyping: true
        ) == .hide)
    }

    @Test("Hides when there is no current suggestion to preserve")
    func hidesWhenNoCurrentSuggestionExists() {
        let decision = SuggestionReplacementDecision(
            shouldPresent: false,
            reason: .lowScoreMargin,
            currentAgeMilliseconds: 1_400,
            scoreMargin: 0.05
        )

        #expect(policy.action(for: decision, hasVisibleSuggestion: false) == .hide)
    }

    @Test("Keeps current suggestion visible when a late model result is suppressed")
    func keepsCurrentSuggestionVisibleWhenLateModelResultIsSuppressed() {
        #expect(policy.action(
            forDisplaySuppressionReason: .tooSlowToDisplay,
            hasVisibleSuggestion: true,
            sameFieldAsCurrentSuggestion: true,
            currentSuggestionAgeMilliseconds: 1_300,
            maximumPreservedAgeMilliseconds: 5_000
        ) == .keepCurrentVisible)
    }

    @Test("Hides late suppressed results when the current suggestion is stale or invalid")
    func hidesLateSuppressedResultsWhenCurrentSuggestionIsStaleOrInvalid() {
        #expect(policy.action(
            forDisplaySuppressionReason: .tooSlowToDisplay,
            hasVisibleSuggestion: true,
            sameFieldAsCurrentSuggestion: true,
            currentSuggestionAgeMilliseconds: 5_001,
            maximumPreservedAgeMilliseconds: 5_000
        ) == .hide)

        #expect(policy.action(
            forDisplaySuppressionReason: .tooSlowToDisplay,
            hasVisibleSuggestion: true,
            currentSuggestionInvalidatedByUserTyping: true,
            sameFieldAsCurrentSuggestion: true,
            currentSuggestionAgeMilliseconds: 100,
            maximumPreservedAgeMilliseconds: 5_000
        ) == .hide)

        #expect(policy.action(
            forDisplaySuppressionReason: .tooSlowToDisplay,
            hasVisibleSuggestion: true,
            sameFieldAsCurrentSuggestion: false,
            currentSuggestionAgeMilliseconds: 100,
            maximumPreservedAgeMilliseconds: 5_000
        ) == .hide)
    }

    @Test("Low-confidence model suppression keeps a fresh current suggestion visible")
    func lowConfidenceModelSuppressionKeepsFreshCurrentSuggestionVisible() {
        #expect(policy.action(
            forDisplaySuppressionReason: .lowConfidence,
            hasVisibleSuggestion: true,
            sameFieldAsCurrentSuggestion: true,
            currentSuggestionAgeMilliseconds: 100,
            maximumPreservedAgeMilliseconds: 5_000
        ) == .keepCurrentVisible)
    }

    @Test("Risky display suppression does not preserve the current suggestion")
    func riskyDisplaySuppressionDoesNotPreserveCurrentSuggestion() {
        #expect(policy.action(
            forDisplaySuppressionReason: .highRisk,
            hasVisibleSuggestion: true,
            sameFieldAsCurrentSuggestion: true,
            currentSuggestionAgeMilliseconds: 100,
            maximumPreservedAgeMilliseconds: 5_000
        ) == .hide)
    }
}
