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

    @Test("Suppresses generic chat filler")
    func suppressesGenericChatFiller() {
        let cleaner = CompletionOutputCleaner(maxVisibleWords: 8)

        #expect(cleaner.clean("That makes a lot of sense I would") == nil)
        #expect(cleaner.clean("I would like to help with that") == nil)
        #expect(cleaner.clean("I will do that now.") == nil)
        #expect(cleaner.clean("Let me know when it's done.") == nil)
        #expect(cleaner.clean("integrate it seamlessly.") == nil)
        #expect(cleaner.clean("enhance the experience") == nil)
    }

    @Test("Uses only first line")
    func usesOnlyFirstLine() {
        let cleaner = CompletionOutputCleaner(maxVisibleWords: 8)
        let suggestion = cleaner.clean("ship this today\nbecause here is why")

        #expect(suggestion?.visibleText == " ship this today")
    }

    @Test("Strips echoed prompt labels")
    func stripsEchoedPromptLabels() {
        let cleaner = CompletionOutputCleaner(maxVisibleWords: 8)

        #expect(cleaner.clean("Next words: keep moving today", after: "Let's")?.visibleText == " keep moving today")
        #expect(cleaner.clean("Suffix: tation", after: "dic", mode: .wordCompletion)?.visibleText == "tation")
        #expect(cleaner.clean("Next words:", after: "Let's") == nil)
    }

    @Test("Trims repeated typed prefix from real model output")
    func trimsRepeatedTypedPrefix() {
        let cleaner = CompletionOutputCleaner(maxVisibleWords: 8)

        #expect(cleaner.clean("Hey there friend.", after: "Hey")?.visibleText == " there friend.")
        #expect(cleaner.clean("Know you are", after: "I know you are") == nil)
        #expect(cleaner.clean("hello and welcome", after: "hello and w")?.visibleText == "elcome")
    }

    @Test("Allows one word phrase completions for snappy mode")
    func allowsOneWordPhraseCompletionsForSnappyMode() {
        let cleaner = CompletionOutputCleaner(maxVisibleWords: 8)

        #expect(cleaner.clean("there.", after: "Hey")?.visibleText == " there.")
        #expect(cleaner.clean("ready.", after: "I know you are")?.visibleText == " ready.")
    }

    @Test("Suppresses one word twitch completions")
    func suppressesLowValueOneWordPhraseCompletions() {
        let cleaner = CompletionOutputCleaner(maxVisibleWords: 8)

        #expect(cleaner.clean("it", after: "I think") == nil)
        #expect(cleaner.clean("I", after: "Today") == nil)
        #expect(cleaner.clean("we.", after: "I think") == nil)
        #expect(cleaner.clean("you", after: "Can") == nil)
        #expect(cleaner.clean("is.", after: "The answer") == nil)
        #expect(cleaner.clean("the", after: "This is") == nil)
        #expect(cleaner.clean("ready.", after: "I know you are")?.visibleText == " ready.")
    }

    @Test("Allows single token word completion suffixes")
    func allowsSingleTokenWordCompletionSuffixes() {
        let cleaner = CompletionOutputCleaner(maxVisibleWords: 8)

        #expect(cleaner.clean("dictation", after: "dic", mode: .wordCompletion)?.visibleText == "tation")
        #expect(cleaner.clean("tation", after: "dic", mode: .wordCompletion)?.visibleText == "tation")
        #expect(cleaner.clean("tation next", after: "dic", mode: .wordCompletion) == nil)
    }

    @Test("Suppresses punctuation in word completion suffixes")
    func suppressesPunctuationInWordCompletionSuffixes() {
        let cleaner = CompletionOutputCleaner(maxVisibleWords: 8)

        #expect(cleaner.clean("ing.", after: "walk", mode: .wordCompletion) == nil)
        #expect(cleaner.clean("ing,", after: "walk", mode: .wordCompletion) == nil)
        #expect(cleaner.clean("ing", after: "walk", mode: .wordCompletion)?.visibleText == "ing")
    }

    @Test("Suppresses suggestions that parrot earlier field text")
    func suppressesSuggestionsThatParrotEarlierFieldText() {
        let cleaner = CompletionOutputCleaner(maxVisibleWords: 8)
        let context = """
        I know you are

        Hey how are you
        """

        #expect(cleaner.clean("know you are ready", after: context) == nil)
    }

    @Test("Allows normal continuations even when earlier context exists")
    func allowsNormalContinuationsWithEarlierContext() {
        let cleaner = CompletionOutputCleaner(maxVisibleWords: 8)
        let context = """
        I know you are

        Can we make this feel
        """

        #expect(cleaner.clean("instant and calm", after: context)?.visibleText == " instant and calm")
    }

    @Test("Returns nil for empty output")
    func nilForEmptyOutput() {
        let cleaner = CompletionOutputCleaner()

        #expect(cleaner.clean("   ") == nil)
    }
}
