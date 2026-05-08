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
        #expect(cleaner.clean("As an AI, I can help with that") == nil)
        #expect(cleaner.clean("Here is a possible continuation") == nil)
        #expect(cleaner.clean("It sounds like you want to keep going") == nil)
        #expect(cleaner.clean("You could try another option") == nil)
    }

    @Test("Suppresses recommendation rewrite and next action candidates")
    func suppressesRecommendationRewriteAndNextActionCandidates() {
        let cleaner = CompletionOutputCleaner(maxVisibleWords: 8)

        #expect(cleaner.clean("Recommendation: keep this smaller", after: "Can we") == nil)
        #expect(cleaner.clean("Rewrite: keep this smaller", after: "Can we") == nil)
        #expect(cleaner.clean("Next action: open the logs", after: "Can we") == nil)
        #expect(cleaner.clean("try saying this more clearly", after: "Can we") == nil)
        #expect(cleaner.clean("rewrite this as a calmer sentence", after: "Can we") == nil)
        #expect(cleaner.clean("next step is to open the logs", after: "Can we") == nil)
        #expect(cleaner.clean("keep this smaller", after: "Can we")?.visibleText == " keep this smaller")
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

    @Test("Suppresses unsafe prompt action suggestions")
    func suppressesUnsafePromptActionSuggestions() {
        let cleaner = CompletionOutputCleaner(maxVisibleWords: 8)

        #expect(cleaner.clean("Press Enter to send the prompt", after: "Now") == nil)
        #expect(cleaner.clean("submit the prompt", after: "Then") == nil)
        #expect(cleaner.clean("click send", after: "Next") == nil)
        #expect(cleaner.clean("run this command in Claude Code", after: "Please") == nil)
    }

    @Test("Suppresses assistant replies when user is drafting an agent request")
    func suppressesAssistantRepliesForAgentRequests() {
        let cleaner = CompletionOutputCleaner(maxVisibleWords: 8)

        #expect(cleaner.clean("I'll inspect the file now", after: "Can you") == nil)
        #expect(cleaner.clean("First, open the logs", after: "Please debug this") == nil)
        #expect(cleaner.clean("we need to check the trace", after: "Could you look at") == nil)
        #expect(cleaner.clean("I'll bring snacks", after: "Tomorrow")?.visibleText == " I'll bring snacks")
    }

    @Test("Suppresses generic productivity filler in agent prompts")
    func suppressesGenericProductivityFillerInAgentPrompts() {
        let cleaner = CompletionOutputCleaner(maxVisibleWords: 8)

        #expect(cleaner.clean("make this more productive", after: "Can you") == nil)
        #expect(cleaner.clean("streamline the workflow for everyone", after: "Please fix") == nil)
        #expect(cleaner.clean("boost productivity across the board", after: "Could you write") == nil)
        #expect(
            cleaner.clean("make this more productive", after: "Tomorrow we should")?.visibleText
                == " make this more productive"
        )
    }

    @Test("Uses only first line")
    func usesOnlyFirstLine() {
        let cleaner = CompletionOutputCleaner(maxVisibleWords: 8)
        let suggestion = cleaner.clean("ship this today\nbecause here is why")

        #expect(suggestion?.visibleText == " ship this today")
    }

    @Test("Cleans numbered multiline candidates")
    func cleansNumberedMultilineCandidates() {
        let cleaner = CompletionOutputCleaner(maxVisibleWords: 5)
        let suggestions = cleaner.cleanCandidates(
            """
            1. make this feel calm
            2. make this feel calm
            3. make this easier to ship
            """,
            after: "Can we",
            mode: .phraseContinuation
        )

        #expect(suggestions.map(\.visibleText) == [
            " make this feel calm",
            " make this easier to ship"
        ])
    }

    @Test("Cleans bulleted multiline candidates")
    func cleansBulletedMultilineCandidates() {
        let cleaner = CompletionOutputCleaner(maxVisibleWords: 5)
        let suggestions = cleaner.cleanCandidates(
            """
            - keep this small
            * make it easy to trust
            A. return exactly <NO_SUGGESTION>
            """,
            after: "We should",
            mode: .phraseContinuation
        )

        #expect(suggestions.map(\.visibleText) == [
            " keep this small",
            " make it easy to trust"
        ])
    }

    @Test("Suppresses unsafe multiline candidates")
    func suppressesUnsafeMultilineCandidates() {
        let cleaner = CompletionOutputCleaner(maxVisibleWords: 8)
        let suggestions = cleaner.cleanCandidates(
            """
            1. <NO_SUGGESTION>
            2. press Enter to send the prompt
            3. Inline autocomplete. Return only the continuation.
            """,
            after: "Can you",
            mode: .phraseContinuation
        )

        #expect(suggestions.isEmpty)
    }

    @Test("Strips echoed prompt labels")
    func stripsEchoedPromptLabels() {
        let cleaner = CompletionOutputCleaner(maxVisibleWords: 8)

        #expect(cleaner.clean("Next words: keep moving today", after: "Let's")?.visibleText == " keep moving today")
        #expect(cleaner.clean("Suffix: tation", after: "dic", mode: .wordCompletion)?.visibleText == "tation")
        #expect(cleaner.clean("Next words:", after: "Let's") == nil)
    }

    @Test("Suppresses prompt instruction echoes")
    func suppressesPromptInstructionEchoes() {
        let cleaner = CompletionOutputCleaner(maxVisibleWords: 8)

        #expect(cleaner.clean("Before cursor: hello and w", after: "hello and w") == nil)
        #expect(cleaner.clean("Inline autocomplete. Return only the continuation.", after: "Can we") == nil)
        #expect(cleaner.clean("Return only the next few words.", after: "Can we") == nil)
        #expect(cleaner.clean("No spaces or punctuation.", after: "hel", mode: .wordCompletion) == nil)
        #expect(cleaner.clean("Continue the current sentence naturally.", after: "Can we") == nil)
        #expect(cleaner.clean("Start the next sentence if needed.", after: "We shipped it.") == nil)
    }

    @Test("Suppresses no suggestion sentinel outputs")
    func suppressesNoSuggestionSentinelOutputs() {
        let cleaner = CompletionOutputCleaner(maxVisibleWords: 8)

        #expect(cleaner.clean("<NO_SUGGESTION>", after: "Can we") == nil)
        #expect(cleaner.clean("<no_suggestion>", after: "Can we") == nil)
        #expect(cleaner.clean("`<NO_SUGGESTION>`", after: "Can we") == nil)
        #expect(cleaner.clean("Next words: <NO_SUGGESTION>", after: "Can we") == nil)
        #expect(cleaner.clean("Suffix: '<no_suggestion>'", after: "dic", mode: .wordCompletion) == nil)
        #expect(cleaner.clean("<think>no confident suffix</think><NO_SUGGESTION>", after: "dic", mode: .wordCompletion) == nil)
    }

    @Test("Trims repeated typed prefix from real model output")
    func trimsRepeatedTypedPrefix() {
        let cleaner = CompletionOutputCleaner(maxVisibleWords: 8)

        #expect(cleaner.clean("Hey there friend.", after: "Hey")?.visibleText == " there friend.")
        #expect(cleaner.clean("Know you are", after: "I know you are") == nil)
        #expect(cleaner.clean("hello and welcome", after: "hello and w")?.visibleText == "elcome")
    }

    @Test("Suppresses completions that duplicate the user's visible text")
    func suppressesVisibleTextDuplicates() {
        let cleaner = CompletionOutputCleaner(maxVisibleWords: 8)

        #expect(cleaner.clean(
            "Can we make this feel calmer",
            after: "Can we make this feel calmer"
        ) == nil)
        #expect(cleaner.clean(
            "make this feel calmer",
            after: "Can we make this feel calmer"
        ) == nil)
        #expect(cleaner.clean(
            "feel calmer",
            after: "Can we make this feel calmer"
        ) == nil)
        #expect(cleaner.clean(
            "and easier to trust",
            after: "Can we make this feel calmer"
        )?.visibleText == " and easier to trust")
    }

    @Test("Allows one word phrase completions for snappy mode")
    func allowsOneWordPhraseCompletionsForSnappyMode() {
        let cleaner = CompletionOutputCleaner(maxVisibleWords: 8)

        #expect(cleaner.clean("there.", after: "Hey")?.visibleText == " there.")
        #expect(cleaner.clean("ready.", after: "I know you are")?.visibleText == " ready.")
    }

    @Test("Suppresses completions that restart the current sentence")
    func suppressesCurrentSentenceRestarts() {
        let cleaner = CompletionOutputCleaner(maxVisibleWords: 8)

        #expect(cleaner.clean(
            "Can we make this feel calmer",
            after: "Can we make this"
        )?.visibleText == " feel calmer")
        #expect(cleaner.clean(
            "I want this app to feel smoother",
            after: "I want this to feel"
        ) == nil)
        #expect(cleaner.clean(
            "I want this to feel smoother",
            after: "I want this"
        )?.visibleText == " to feel smoother")
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

    @Test("Suppresses unrelated whole words in word completion mode")
    func suppressesUnrelatedWholeWordsInWordCompletionMode() {
        let cleaner = CompletionOutputCleaner(maxVisibleWords: 8)

        #expect(cleaner.clean("different", after: "dic", mode: .wordCompletion) == nil)
        #expect(cleaner.clean("the", after: "dic", mode: .wordCompletion) == nil)
        #expect(cleaner.clean("dictation", after: "dic", mode: .wordCompletion)?.visibleText == "tation")
        #expect(cleaner.clean("tation", after: "dic", mode: .wordCompletion)?.visibleText == "tation")
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
