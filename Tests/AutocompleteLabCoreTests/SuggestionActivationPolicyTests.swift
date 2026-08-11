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

    @Test("Existing document text does not count as newly typed intent")
    func existingDocumentDoesNotBypassSessionGate() {
        let existingDocument = "A long document already at the caret"
        #expect(existingDocument.count > SuggestionActivationPolicy.minimumTypedCharacters)
        #expect(!SuggestionActivationPolicy.allowsSuggestions(afterUserTyped: " "))
        #expect(!SuggestionActivationPolicy.allowsSuggestions(afterUserTyped: " a"))
    }

    @Test("Three meaningful characters allow suggestions")
    func groundedInputAllowsSuggestions() {
        #expect(SuggestionActivationPolicy.allowsSuggestions(afterUserTyped: "yes"))
        #expect(SuggestionActivationPolicy.allowsSuggestions(afterUserTyped: "y e s"))
        #expect(SuggestionActivationPolicy.allowsSuggestions(afterUserTyped: "café"))
    }
}
