import Testing
@testable import AutocompleteLabApp

@Suite("Visible suggestion outcome policy")
struct VisibleSuggestionOutcomePolicyTests {
    @Test("Accepted hide reasons map to accepted outcomes")
    func acceptedHideReasonsMapToAcceptedOutcomes() {
        let policy = VisibleSuggestionOutcomePolicy()

        #expect(policy.outcome(forHideReason: "accepted-all") == .accepted)
        #expect(policy.outcome(forHideReason: "accepted-next-word-final") == .accepted)
        #expect(!VisibleSuggestionOutcome.accepted.recordsRepeatedMiss)
    }

    @Test("Typed-through and typed-over reasons stay distinct from ignored")
    func typedProgressReasonsStayDistinctFromIgnored() {
        let policy = VisibleSuggestionOutcomePolicy()

        #expect(policy.outcome(forHideReason: "typed-through-visible-prefix") == .typedThrough)
        #expect(policy.outcome(forHideReason: "typed-over") == .typedOver)
        #expect(policy.outcome(forHideReason: "escape") == .ignored)
        #expect(VisibleSuggestionOutcome.ignored.recordsRepeatedMiss)
        #expect(!VisibleSuggestionOutcome.typedThrough.recordsRepeatedMiss)
        #expect(!VisibleSuggestionOutcome.typedOver.recordsRepeatedMiss)
    }
}
