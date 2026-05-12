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
}
