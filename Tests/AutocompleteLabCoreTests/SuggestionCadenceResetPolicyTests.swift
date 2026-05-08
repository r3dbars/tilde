import Testing
@testable import AutocompleteLabCore

@Suite("Suggestion cadence reset policy")
struct SuggestionCadenceResetPolicyTests {
    @Test("Selected text resets stale requested prefixes")
    func selectedTextResetsStaleRequestedPrefixes() {
        let policy = SuggestionCadenceResetPolicy()

        #expect(policy.shouldResetLastRequestedText(
            previousTextBeforeCursor: "Autocomplete smoke\nCan we make this inst",
            currentTextBeforeCursor: "",
            selectedTextLength: 40
        ))
    }

    @Test("Deletion resets stale requested prefixes")
    func deletionResetsStaleRequestedPrefixes() {
        let policy = SuggestionCadenceResetPolicy()

        #expect(policy.shouldResetLastRequestedText(
            previousTextBeforeCursor: "Autocomplete smoke\nCan we make this inst",
            currentTextBeforeCursor: "Autocomplete smoke\nCan we make this",
            selectedTextLength: 0
        ))
    }

    @Test("Forward typing keeps cadence state")
    func forwardTypingKeepsCadenceState() {
        let policy = SuggestionCadenceResetPolicy()

        #expect(!policy.shouldResetLastRequestedText(
            previousTextBeforeCursor: "Can we make",
            currentTextBeforeCursor: "Can we make this",
            selectedTextLength: 0
        ))
    }
}
