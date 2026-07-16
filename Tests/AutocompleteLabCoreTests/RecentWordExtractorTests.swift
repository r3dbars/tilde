import Testing
@testable import AutocompleteLabCore
@testable import AutocompleteLabResearch

@Suite("Recent word extractor")
struct RecentWordExtractorTests {
    @Test("Extracts accepted words for future word completion")
    func extractsAcceptedWords() {
        let extractor = RecentWordExtractor()

        #expect(extractor.words(in: " dictation, autocomplete!") == ["dictation", "autocomplete"])
    }

    @Test("Learns a typed word when the user finishes it")
    func learnsCompletedTypedWord() {
        let extractor = RecentWordExtractor()

        #expect(extractor.completedWords(
            previousTextBeforeCursor: "I need dictation",
            currentTextBeforeCursor: "I need dictation "
        ) == ["dictation"])
    }

    @Test("Does not learn unfinished or unrelated text changes")
    func skipsUnfinishedOrUnrelatedText() {
        let extractor = RecentWordExtractor()

        #expect(extractor.completedWords(
            previousTextBeforeCursor: "I need dicta",
            currentTextBeforeCursor: "I need dictation"
        ).isEmpty)
        #expect(extractor.completedWords(
            previousTextBeforeCursor: "old field",
            currentTextBeforeCursor: "new field "
        ).isEmpty)
    }
}
