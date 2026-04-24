import Testing
@testable import AutocompleteLabCore

@Suite("Completion prefix trimmer")
struct CompletionPrefixTrimmerTests {
    @Test("Removes a fully duplicated leading word")
    func removesFullyDuplicatedLeadingWord() {
        let trimmed = CompletionPrefixTrimmer.trim(" and keep moving", after: "Hey and")

        #expect(trimmed == " keep moving")
    }

    @Test("Removes only the already typed part of a word")
    func removesAlreadyTypedPartOfWord() {
        let trimmed = CompletionPrefixTrimmer.trim(" and keep moving", after: "Hey a")

        #expect(trimmed == "nd keep moving")
    }

    @Test("Avoids double spaces after whitespace")
    func avoidsDoubleSpacesAfterWhitespace() {
        let trimmed = CompletionPrefixTrimmer.trim(" and keep moving", after: "Hey ")

        #expect(trimmed == "and keep moving")
    }
}
