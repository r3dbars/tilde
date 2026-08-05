import Testing
@testable import AutocompleteLabCore

@Suite("Suggestion activation")
struct SuggestionActivationPolicyTests {
    @Test("Empty and punctuation-only fields stay quiet")
    func emptyFieldsStayQuiet() {
        #expect(!SuggestionActivationPolicy.allowsSuggestions(afterUserTyped: ""))
        #expect(!SuggestionActivationPolicy.allowsSuggestions(afterUserTyped: "  !?"))
    }

    @Test("Fewer than three typed characters stays quiet")
    func shortInputStaysQuiet() {
        #expect(!SuggestionActivationPolicy.allowsSuggestions(afterUserTyped: "y"))
        #expect(!SuggestionActivationPolicy.allowsSuggestions(afterUserTyped: "y e"))
    }

    @Test("Three meaningful characters allow suggestions")
    func groundedInputAllowsSuggestions() {
        #expect(SuggestionActivationPolicy.allowsSuggestions(afterUserTyped: "yes"))
        #expect(SuggestionActivationPolicy.allowsSuggestions(afterUserTyped: "y e s"))
        #expect(SuggestionActivationPolicy.allowsSuggestions(afterUserTyped: "café"))
    }

    @Test("Location-zero fields fail closed when blank or unreadable")
    func blankFieldPolicyFailsClosed() {
        #expect(BlankFieldSuggestionPolicy.shouldSuppress(
            selectionLocation: 0,
            firstCharacterAtCursor: nil
        ))
        #expect(BlankFieldSuggestionPolicy.shouldSuppress(
            selectionLocation: 0,
            firstCharacterAtCursor: ""
        ))
        #expect(!BlankFieldSuggestionPolicy.shouldSuppress(
            selectionLocation: 0,
            firstCharacterAtCursor: "H"
        ))
        #expect(!BlankFieldSuggestionPolicy.shouldSuppress(
            selectionLocation: 12,
            firstCharacterAtCursor: nil
        ))
    }
}
