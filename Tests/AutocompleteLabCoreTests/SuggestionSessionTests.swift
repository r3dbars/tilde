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

    @Test("Tab residual keeps the original visible character cap")
    func tabResidualKeepsOriginalVisibleCharacterCap() throws {
        var session = SuggestionSession(
            visibleSuggestion: CompletionSuggestion(
                text: " one two three",
                maxVisibleWords: 8,
                maxVisibleCharacters: 16
            )
        )

        #expect(session.acceptNextWord() == " one")

        let residual = try #require(session.visibleSuggestion)
        #expect(residual.maxVisibleCharacters == 16)
        #expect(residual.visibleText == " two three")
    }

    @Test("Tab can require recompute after one accepted word")
    func tabCanRequireRecomputeAfterOneAcceptedWord() {
        var session = SuggestionSession(
            visibleSuggestion: CompletionSuggestion(text: " we should ship", maxVisibleWords: 8)
        )

        #expect(session.acceptNextWord(keepsResidual: false) == " we")
        #expect(!session.hasVisibleSuggestion)
    }

    @Test("Typing a visible prefix keeps the residual suggestion visible")
    func typedVisiblePrefixKeepsResidualSuggestion() {
        var session = SuggestionSession(
            visibleSuggestion: CompletionSuggestion(text: "tation", maxVisibleWords: 8)
        )

        let didCommit = session.commitTypedVisiblePrefix("t")

        #expect(didCommit)
        #expect(session.visibleSuggestion?.visibleText == "ation")
    }

    @Test("Typing a visible prefix ignores case differences")
    func typedVisiblePrefixIgnoresCaseDifferences() {
        var session = SuggestionSession(
            visibleSuggestion: CompletionSuggestion(text: "Tation", maxVisibleWords: 8)
        )

        let didCommit = session.commitTypedVisiblePrefix("t")

        #expect(didCommit)
        #expect(session.visibleSuggestion?.visibleText == "ation")
    }

    @Test("Typing the full visible suggestion dismisses it")
    func typedFullVisiblePrefixDismissesSuggestion() {
        var session = SuggestionSession(
            visibleSuggestion: CompletionSuggestion(text: "ation", maxVisibleWords: 8)
        )

        let didCommit = session.commitTypedVisiblePrefix("ation")

        #expect(didCommit)
        #expect(!session.hasVisibleSuggestion)
    }

    @Test("Typing conflicting text leaves the suggestion untouched")
    func typedConflictingPrefixLeavesSuggestionUntouched() {
        var session = SuggestionSession(
            visibleSuggestion: CompletionSuggestion(text: "ation", maxVisibleWords: 8)
        )

        let didCommit = session.commitTypedVisiblePrefix("x")

        #expect(!didCommit)
        #expect(session.visibleSuggestion?.visibleText == "ation")
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

    @Test("Next word preview keeps residual character cap")
    func nextWordPreviewKeepsResidualCharacterCap() throws {
        let session = SuggestionSession(
            visibleSuggestion: CompletionSuggestion(
                text: " one two three",
                maxVisibleWords: 8,
                maxVisibleCharacters: 16
            )
        )

        let preview = try #require(session.nextWordAcceptancePreview())

        #expect(preview.acceptedText == " one")
        #expect(preview.remainingVisibleTextAfterAccept == " two three")
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
