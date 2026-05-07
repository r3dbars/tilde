import Testing
@testable import AutocompleteLabCore

@Suite("Suggestion session")
struct SuggestionSessionTests {
    @Test("Visible text is capped by word count")
    func visibleTextIsCapped() {
        let suggestion = CompletionSuggestion(text: " we should ship this today", maxVisibleWords: 3)

        #expect(suggestion.visibleText == " we should ship")
        #expect(suggestion.visibleWordCount == 3)
        #expect(suggestion.text == " we should ship")
    }

    @Test("Visible text is capped under forty two characters")
    func visibleTextIsCappedUnderFortyTwoCharacters() {
        let suggestion = CompletionSuggestion(
            text: " this is a very useful continuation that should not run long",
            maxVisibleWords: 12
        )

        #expect(suggestion.visibleText.count <= CompletionSuggestion.defaultMaxVisibleCharacters)
        #expect(suggestion.visibleText == " this is a very useful continuation that")
    }

    @Test("Visible text stays single line")
    func visibleTextStaysSingleLine() {
        let suggestion = CompletionSuggestion(
            text: " keep this line\nbut never reveal this line",
            maxVisibleWords: 8
        )

        #expect(suggestion.visibleText == " keep this line")
    }

    @Test("Long single word is hard capped")
    func longSingleWordIsHardCapped() {
        let suggestion = CompletionSuggestion(
            text: " supercalifragilisticexpialidociousplusmore",
            maxVisibleWords: 1
        )

        #expect(suggestion.visibleText.count == CompletionSuggestion.defaultMaxVisibleCharacters)
    }

    @Test("Repeated word acceptance cannot reveal hidden overflow text")
    func repeatedWordAcceptanceCannotRevealOverflowText() {
        var session = SuggestionSession(
            visibleSuggestion: CompletionSuggestion(text: " we should ship this today", maxVisibleWords: 3)
        )

        #expect(session.acceptNextWord() == " we")
        #expect(session.acceptNextWord() == " should")
        #expect(session.acceptNextWord() == " ship")
        #expect(session.acceptNextWord() == nil)
    }

    @Test("Tab accepts one word and keeps the rest visible")
    func tabAcceptsOneWord() {
        var session = SuggestionSession(
            visibleSuggestion: CompletionSuggestion(text: " we should ship", maxVisibleWords: 8)
        )

        #expect(session.acceptNextWord() == " we")
        #expect(session.visibleSuggestion?.visibleText == " should ship")
    }

    @Test("Previewing next word does not consume the suggestion")
    func previewingNextWordDoesNotConsumeSuggestion() {
        var session = SuggestionSession(
            visibleSuggestion: CompletionSuggestion(text: " we should ship", maxVisibleWords: 8)
        )

        #expect(session.nextWordAcceptance() == " we")
        #expect(session.visibleSuggestion?.visibleText == " we should ship")

        session.commitNextWordAcceptance(" we")

        #expect(session.visibleSuggestion?.visibleText == " should ship")
    }

    @Test("Failed insert can leave suggestion untouched")
    func failedInsertCanLeaveSuggestionUntouched() {
        let session = SuggestionSession(
            visibleSuggestion: CompletionSuggestion(text: " make this feel instant", maxVisibleWords: 8)
        )

        let preview = session.nextWordAcceptance()

        #expect(preview == " make")
        #expect(session.visibleSuggestion?.visibleText == " make this feel instant")
    }

    @Test("Backtick accepts all visible text and dismisses")
    func backtickAcceptsAllVisibleText() {
        var session = SuggestionSession(
            visibleSuggestion: CompletionSuggestion(text: " keep it small", maxVisibleWords: 8)
        )

        #expect(session.acceptAllVisible() == " keep it small")
        #expect(!session.hasVisibleSuggestion)
    }

    @Test("Previewing all visible text does not dismiss until committed")
    func previewingAllVisibleDoesNotDismissUntilCommitted() {
        var session = SuggestionSession(
            visibleSuggestion: CompletionSuggestion(text: " keep it small", maxVisibleWords: 8)
        )

        #expect(session.allVisibleAcceptance() == " keep it small")
        #expect(session.hasVisibleSuggestion)

        session.commitAllVisibleAcceptance(" keep it small")

        #expect(!session.hasVisibleSuggestion)
    }

    @Test("Dismiss clears visible suggestion")
    func dismissClearsSuggestion() {
        var session = SuggestionSession(
            visibleSuggestion: CompletionSuggestion(text: " and keep moving", maxVisibleWords: 8)
        )

        session.dismiss()

        #expect(!session.hasVisibleSuggestion)
    }
}
