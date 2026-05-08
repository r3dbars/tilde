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

    @Test("Next word preview records the visible acceptance slice")
    func nextWordPreviewRecordsVisibleAcceptanceSlice() throws {
        let session = SuggestionSession(
            visibleSuggestion: CompletionSuggestion(text: " we should ship", maxVisibleWords: 8)
        )

        let preview = try #require(session.nextWordAcceptancePreview())

        #expect(preview.mode == .nextWord)
        #expect(preview.acceptedText == " we")
        #expect(preview.visibleTextBeforeAccept == " we should ship")
        #expect(preview.remainingVisibleTextAfterAccept == " should ship")
        #expect(preview.acceptanceMatchesVisiblePrefix)
        #expect(!preview.acceptanceMatchesFullVisible)
        #expect(preview.traceMetadata["acceptanceSource"] == "visiblePrefix")
        #expect(preview.traceMetadata["acceptedChars"] == String(preview.acceptedText.count))
        #expect(preview.traceMetadata["visibleBeforeAcceptChars"] == String(preview.visibleTextBeforeAccept.count))
        #expect(preview.traceMetadata["remainingVisibleAfterAcceptChars"] == String(preview.remainingVisibleTextAfterAccept.count))
        #expect(preview.traceMetadata["acceptanceMatchesVisiblePrefix"] == "true")
        #expect(preview.traceMetadata["acceptanceMatchesFullVisible"] == "false")
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

    @Test("Full preview records an exact visible match")
    func fullPreviewRecordsExactVisibleMatch() throws {
        let session = SuggestionSession(
            visibleSuggestion: CompletionSuggestion(text: " keep it small", maxVisibleWords: 8)
        )

        let preview = try #require(session.allVisibleAcceptancePreview())

        #expect(preview.mode == .allVisible)
        #expect(preview.acceptedText == " keep it small")
        #expect(preview.visibleTextBeforeAccept == " keep it small")
        #expect(preview.remainingVisibleTextAfterAccept == "")
        #expect(preview.acceptanceMatchesVisiblePrefix)
        #expect(preview.acceptanceMatchesFullVisible)
        #expect(preview.traceMetadata["acceptanceSource"] == "visibleFull")
        #expect(preview.traceMetadata["acceptanceMatchesVisiblePrefix"] == "true")
        #expect(preview.traceMetadata["acceptanceMatchesFullVisible"] == "true")
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
