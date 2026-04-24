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

    @Test("Removes a full repeated context from model output")
    func removesFullRepeatedContext() {
        let trimmed = CompletionPrefixTrimmer.trim("I think and feel a sense of wonder", after: "I think and")

        #expect(trimmed == " feel a sense of wonder")
    }

    @Test("Removes a full repeated context after existing whitespace")
    func removesFullRepeatedContextAfterWhitespace() {
        let trimmed = CompletionPrefixTrimmer.trim("I think and feel a sense of wonder", after: "I think and ")

        #expect(trimmed == "feel a sense of wonder")
    }

    @Test("Completes a later matching word when the model repeats nearby context")
    func completesLaterMatchingWord() {
        let trimmed = CompletionPrefixTrimmer.trim(
            " to do this project",
            after: "Hey how we going to do the th"
        )

        #expect(trimmed == "is project")
    }

    @Test("Completes a repeated partial word from full context output")
    func completesRepeatedPartialWordFromFullContextOutput() {
        let trimmed = CompletionPrefixTrimmer.trim("Hey that sounds", after: "Hey that soun")

        #expect(trimmed == "ds")
    }

    @Test("Suppresses partial word suggestions that do not complete the typed fragment")
    func suppressesBadPartialWordSuggestion() {
        let trimmed = CompletionPrefixTrimmer.trim(" and keep moving", after: "Hey th")
        let longerTrimmed = CompletionPrefixTrimmer.trim(" and keep moving", after: "Hey that soun")
        let typoTrimmed = CompletionPrefixTrimmer.trim("Hey that sounds", after: "Hey\nHry")

        #expect(trimmed == "")
        #expect(longerTrimmed == "")
        #expect(typoTrimmed == "")
    }

    @Test("Suppresses model echoes from the beginning of the current text")
    func suppressesBeginningContextEchoes() {
        let trimmed = CompletionPrefixTrimmer.trim(
            "Hey. How are",
            after: "Hey. How are we going to do the"
        )

        #expect(trimmed == "")
    }

    @Test("Keeps suggestions after common short complete words")
    func keepsSuggestionAfterCommonShortCompleteWord() {
        let trimmed = CompletionPrefixTrimmer.trim(" make this feel instant", after: "can we")
        let trimmedAfterThe = CompletionPrefixTrimmer.trim(" next step is clear", after: "what is the")
        let trimmedAfterAnd = CompletionPrefixTrimmer.trim(" keep moving", after: "Hey and")

        #expect(trimmed == " make this feel instant")
        #expect(trimmedAfterThe == " next step is clear")
        #expect(trimmedAfterAnd == " keep moving")
    }
}
