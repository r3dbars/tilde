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

    @Test("Removes a duplicated phrase from model output")
    func removesDuplicatedPhraseFromModelOutput() {
        let trimmed = CompletionPrefixTrimmer.trim(" Know you are", after: "I know you are")

        #expect(trimmed == "")
    }

    @Test("Removes overlapping phrase and keeps the new continuation")
    func removesOverlappingPhraseAndKeepsContinuation() {
        let trimmed = CompletionPrefixTrimmer.trim(" you are right", after: "I know you are")

        #expect(trimmed == " right")
    }

    @Test("Removes duplicated greeting and keeps only new words")
    func removesDuplicatedGreeting() {
        let trimmed = CompletionPrefixTrimmer.trim(" Hey there.", after: "Hey")

        #expect(trimmed == " there.")
    }
}
