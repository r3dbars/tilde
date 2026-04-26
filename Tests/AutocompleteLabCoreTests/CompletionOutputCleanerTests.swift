import Testing
@testable import AutocompleteLabCore

@Suite("Completion output cleaner")
struct CompletionOutputCleanerTests {
    @Test("Adds a leading space so insertion continues the sentence")
    func addsLeadingSpace() {
        let cleaner = CompletionOutputCleaner(maxVisibleWords: 3)
        let suggestion = cleaner.clean("keep moving today")

        #expect(suggestion?.visibleText == " keep moving today")
    }

    @Test("Removes thinking tags")
    func removesThinkingTags() {
        let cleaner = CompletionOutputCleaner(maxVisibleWords: 4)
        let suggestion = cleaner.clean("<think>I should explain</think>keep it tiny")

        #expect(suggestion?.visibleText == " keep it tiny")
    }

    @Test("Removes stray thinking markers")
    func removesStrayThinkingMarkers() {
        let cleaner = CompletionOutputCleaner(maxVisibleWords: 6)

        #expect(cleaner.clean("<think> and I would like to see")?.visibleText == " and I would like to see")
        #expect(cleaner.clean("make sure <think>")?.visibleText == " make sure")
    }

    @Test("Suppresses assistant meta text")
    func suppressesAssistantMetaText() {
        let cleaner = CompletionOutputCleaner(maxVisibleWords: 8)

        #expect(cleaner.clean("Okay, let's see. The user is trying to") == nil)
        #expect(cleaner.clean("The user is trying to write a sentence") == nil)
    }

    @Test("Uses only first line")
    func usesOnlyFirstLine() {
        let cleaner = CompletionOutputCleaner(maxVisibleWords: 8)
        let suggestion = cleaner.clean("ship this today\nbecause here is why")

        #expect(suggestion?.visibleText == " ship this today")
    }

    @Test("Returns nil for empty output")
    func nilForEmptyOutput() {
        let cleaner = CompletionOutputCleaner()

        #expect(cleaner.clean("   ") == nil)
    }
}
