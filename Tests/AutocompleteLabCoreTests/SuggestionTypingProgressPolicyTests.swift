import Testing
@testable import AutocompleteLabCore

@Suite("Suggestion typing progress policy")
struct SuggestionTypingProgressPolicyTests {
    private let policy = SuggestionTypingProgressPolicy()

    @Test("unchanged when cursor text matches the suggestion baseline")
    func unchangedAtBaseline() {
        #expect(
            policy.progress(
                originalTextBeforeCursor: "Can we make this feel instant",
                displayedText: " and effortless",
                newTextBeforeCursor: "Can we make this feel instant"
            ) == .unchanged
        )
    }

    @Test("typed through when user text follows the visible suggestion prefix")
    func typedThroughVisiblePrefix() {
        #expect(
            policy.progress(
                originalTextBeforeCursor: "Can we make this feel ",
                displayedText: "instant and effortless",
                newTextBeforeCursor: "Can we make this feel ins"
            ) == .typedThroughVisiblePrefix(typedSuffix: "ins")
        )
    }

    @Test("typed over when user text conflicts with the visible suggestion")
    func typedOverVisibleSuggestion() {
        #expect(
            policy.progress(
                originalTextBeforeCursor: "Can we make this feel ",
                displayedText: "instant and effortless",
                newTextBeforeCursor: "Can we make this feel slow"
            ) == .typedOver(typedSuffix: "slow")
        )
    }
}
