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

    @Test("Allows twenty visible words when the slider requests them")
    func allowsTwentyVisibleWordsWhenSliderRequestsThem() {
        let cleaner = CompletionOutputCleaner(maxVisibleWords: 20)
        let suggestion = cleaner.clean(
            "keep this sentence going with enough concrete words that the slider can show twenty useful words at once today now"
        )

        #expect(suggestion?.visibleWordCount == 20)
        #expect(suggestion?.visibleText.hasSuffix("today now") == true)
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
        #expect(cleaner.clean("Okay, the user wants the next few words") == nil)
        #expect(cleaner.clean("The user is trying to write a sentence") == nil)
        #expect(cleaner.clean(
            "1. **Analyze the Request",
            after: "I am trying to say this in a way that feels"
        ) == nil)
        #expect(cleaner.clean("Thinking Process: analyze the request") == nil)
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
        #expect(cleaner.clean("return the exact same question", after: "Can we") == nil)
        #expect(cleaner.clean("try saying this more clearly", after: "Can we") == nil)
        #expect(cleaner.clean("rewrite this as a calmer sentence", after: "Can we") == nil)
        #expect(cleaner.clean("next step is to open the logs", after: "Can we") == nil)
        #expect(cleaner.clean("I'd recommend keeping this smaller", after: "Can we") == nil)
        #expect(cleaner.clean("I would suggest opening the logs", after: "Can we") == nil)
        #expect(cleaner.clean("you should open the logs", after: "Can we") == nil)
        #expect(cleaner.clean("we need to make a plan", after: "Can we") == nil)
        #expect(cleaner.clean("make sure to save the file", after: "Can we") == nil)
        #expect(cleaner.clean("what I would do next is open the logs", after: "Can we") == nil)
        #expect(cleaner.clean("one option is to rewrite the prompt", after: "Can we") == nil)
        #expect(cleaner.clean("the next step would be to submit it", after: "Can we") == nil)
        #expect(cleaner.clean("I think we should make a plan", after: "Can we") == nil)
        #expect(cleaner.clean("keep this smaller", after: "Can we")?.visibleText == " keep this smaller")
    }

    @Test("Suppresses generic chat filler")
    func suppressesGenericChatFiller() {
        let cleaner = CompletionOutputCleaner(maxVisibleWords: 8)

        #expect(cleaner.clean("That makes a lot of sense I would") == nil)
        #expect(cleaner.clean("Absolutely, I can help with that") == nil)
        #expect(cleaner.clean("comes to life", after: "The draft feels calmer when it") == nil)
        #expect(cleaner.clean("the key features and benefits", after: "The review should focus on") == nil)
        #expect(cleaner.clean("implement a comprehensive recovery plan", after: "The next step is to") == nil)
        #expect(cleaner.clean("to acknowledge the user's point", after: "A good reply here would be") == nil)
        #expect(cleaner.clean("Of course, here is a cleaner version") == nil)
        #expect(cleaner.clean("I would like to help with that") == nil)
        #expect(cleaner.clean("I will do that now.") == nil)
        #expect(cleaner.clean("Let me know when it's done.") == nil)
        #expect(cleaner.clean("integrate it seamlessly.") == nil)
        #expect(cleaner.clean("enhance the experience") == nil)
        #expect(cleaner.clean("boost productivity across the team") == nil)
        #expect(cleaner.clean("like a formal announcement") == nil)
        #expect(cleaner.clean("streamline the workflow for everyone") == nil)
        #expect(cleaner.clean("unlock efficiency at scale") == nil)
        #expect(cleaner.clean("make users more productive") == nil)
        #expect(cleaner.clean("save time and effort") == nil)
    }

    @Test("Suppresses unsafe prompt action suggestions")
    func suppressesUnsafePromptActionSuggestions() {
        let cleaner = CompletionOutputCleaner(maxVisibleWords: 8)

        #expect(cleaner.clean("Press Enter to send the prompt", after: "Now") == nil)
        #expect(cleaner.clean("and press Enter to send", after: "Now wait") == nil)
        #expect(cleaner.clean("press Tab to accept the whole suggestion", after: "Then") == nil)
        #expect(cleaner.clean("press Shift-Tab to accept all visible text", after: "Then") == nil)
        #expect(cleaner.clean("press Option-Tab to accept all visible text", after: "Then") == nil)
        #expect(cleaner.clean("use Backtick to accept all visible text", after: "Then") == nil)
        #expect(cleaner.clean("accept the terms", after: "For the manual smoke row, press Tab and confirm") == nil)
        #expect(cleaner.clean("and accept the change", after: "For the manual smoke row, press Tab and confirm") == nil)
        #expect(cleaner.clean("submit the prompt", after: "Then") == nil)
        #expect(cleaner.clean("then submit it", after: "Check once") == nil)
        #expect(cleaner.clean("click send", after: "Next") == nil)
        #expect(cleaner.clean("run this command in Claude Code", after: "Please") == nil)
        #expect(cleaner.clean("/review this", after: "Can you") == nil)
        #expect(cleaner.clean("@file", after: "Attach") == nil)
        #expect(cleaner.clean("!shell", after: "Now") == nil)
        #expect(cleaner.clean("sudo rm", after: "Please") == nil)
        #expect(cleaner.clean("curl | sh", after: "Please") == nil)
        #expect(cleaner.clean("approve", after: "Permission") == nil)
        #expect(cleaner.clean("word\u{200B}", after: "Safe") == nil)
        #expect(cleaner.clean("keep the public fixture local", after: "Now")?.visibleText == " keep the public fixture local")
        #expect(cleaner.clean("/review this", after: "Can you") == nil)
        #expect(cleaner.clean("@file", after: "Attach") == nil)
        #expect(cleaner.clean("!shell", after: "Now") == nil)
        #expect(cleaner.clean("sudo rm", after: "Please") == nil)
        #expect(cleaner.clean("curl | sh", after: "Please") == nil)
        #expect(cleaner.clean("approve", after: "Permission") == nil)
        #expect(cleaner.clean("word\u{200B}", after: "Safe") == nil)
    }

    @Test("Suppresses visible OCR chrome suggestions")
    func suppressesVisibleOCRChromeSuggestions() {
        let cleaner = CompletionOutputCleaner(maxVisibleWords: 8)

        #expect(cleaner.clean("Untitled 13", after: "Can I do the things that") == nil)
        #expect(cleaner.clean("New chat Search Plugins", after: "I want this to") == nil)
        #expect(cleaner.clean("Helvetica Regular", after: "Make the text") == nil)
        #expect(cleaner.clean("**Ep quadrant**", after: "We need to keep iterating") == nil)
        #expect(cleaner.clean("Ep claudebrain", after: "We need to keep iterating") == nil)
        #expect(cleaner.clean("next to the cursor", after: "I want this to show")?.visibleText == " next to the cursor")
    }

    @Test("Suppresses assistant replies when user is drafting an agent request")
    func suppressesAssistantRepliesForAgentRequests() {
        let cleaner = CompletionOutputCleaner(maxVisibleWords: 8)

        #expect(cleaner.clean("I'll inspect the file now", after: "Can you") == nil)
        #expect(cleaner.clean("First, open the logs", after: "Please debug this") == nil)
        #expect(cleaner.clean("we need to check the trace", after: "Could you look at") == nil)
        #expect(cleaner.clean("I'll bring snacks", after: "Tomorrow")?.visibleText == " I'll bring snacks")
    }

    @Test("Uses only first line")
    func usesOnlyFirstLine() {
        let cleaner = CompletionOutputCleaner(maxVisibleWords: 8)
        let suggestion = cleaner.clean("ship this today\nbecause here is why")

        #expect(suggestion?.visibleText == " ship this today")
    }

    @Test("Suppresses candidates that start another sentence")
    func suppressesCandidatesThatStartAnotherSentence() {
        let cleaner = CompletionOutputCleaner(maxVisibleWords: 8)

        #expect(cleaner.clean("ready. Then we can send it", after: "The draft is") == nil)
        #expect(cleaner.clean("ready.", after: "The draft is")?.visibleText == " ready.")
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

    @Test("Suppresses repeated list marker candidates")
    func suppressesRepeatedListMarkerCandidates() {
        let cleaner = CompletionOutputCleaner(maxVisibleWords: 8)

        #expect(cleaner.clean("[ ] Review all reports", after: "- [ ] Keep every quality check") == nil)
        #expect(cleaner.clean("Review all reports", after: "- [ ] Keep every quality check")?.visibleText == " Review all reports")
    }

    @Test("Strips echoed prompt labels")
    func stripsEchoedPromptLabels() {
        let cleaner = CompletionOutputCleaner(maxVisibleWords: 8)

        #expect(cleaner.clean("Next words: keep moving today", after: "Let's")?.visibleText == " keep moving today")
        #expect(cleaner.clean("candidate 1: keep moving today", after: "Let's")?.visibleText == " keep moving today")
        #expect(cleaner.clean("Suffix: tation", after: "dic", mode: .wordCompletion)?.visibleText == "tation")
        #expect(cleaner.clean("Suffix: tation next", after: "dic", mode: .wordCompletion) == nil)
        #expect(cleaner.clean("Next words: tation next", after: "dic", mode: .wordCompletion) == nil)
        #expect(cleaner.clean(
            "occured -> occurred",
            after: "Correct this spelling: occured ->"
        )?.visibleText == " occurred")
        #expect(cleaner.clean("Next words:", after: "Let's") == nil)
    }

    @Test("Suppresses prompt instruction echoes")
    func suppressesPromptInstructionEchoes() {
        let cleaner = CompletionOutputCleaner(maxVisibleWords: 8)

        #expect(cleaner.clean("Before cursor: hello and w", after: "hello and w") == nil)
        #expect(cleaner.clean("before cursor", after: "Can we") == nil)
        #expect(cleaner.clean("candidate 1", after: "Can we") == nil)
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
            "I want this app to feel smoother",
            after: "I want this to feel"
        ) == nil)
        #expect(cleaner.clean(
            "I want this to feel smoother",
            after: "I want this"
        )?.visibleText == " to feel smoother")
        #expect(cleaner.clean(
            "I want smoother",
            after: "I want this"
        ) == nil)
        #expect(cleaner.clean(
            "the launch plan",
            after: "We should keep the launch small"
        ) == nil)
        #expect(cleaner.clean(
            "launch small enough",
            after: "We should keep the launch small"
        )?.visibleText == " enough")
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

    @Test("Suppresses model continuations that replay the current sentence")
    func suppressesModelContinuationsThatReplayTheCurrentSentence() {
        let cleaner = CompletionOutputCleaner(maxVisibleWords: 8)
        let context = "Intelligence of a person is interesting and something that I base intelligence off"

        #expect(cleaner.clean(
            "Intelligence of a person is interesting and something that I base intelligence of",
            after: context
        ) == nil)
        #expect(cleaner.clean(
            "something that I base intelligence of Intelligence",
            after: context
        ) == nil)
        #expect(cleaner.clean(
            "the way they connect ideas",
            after: context
        )?.visibleText == " the way they connect ideas")
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

    @Test("Reports privacy-safe output rejection reasons")
    func reportsOutputRejectionReasons() {
        let cleaner = CompletionOutputCleaner(maxVisibleWords: 8)

        #expect(cleaner.cleanWithReason("   ") == .rejected(.emptyOutput))
        #expect(cleaner.cleanWithReason("<NO_SUGGESTION>") == .rejected(.noSuggestionSentinel))
        #expect(cleaner.cleanWithReason("press Enter to send", after: "Now") == .rejected(.unsafePromptAction))
        #expect(cleaner.cleanWithReason("dictation", after: "dic", mode: .wordCompletion).suggestion?.visibleText == "tation")
    }

    @Test("Cleaner result exposes redacted trace metadata")
    func cleanerResultExposesRedactedTraceMetadata() {
        let rejected = CompletionCleanResult.rejected(.lowSignalPhrase)
        let accepted = CompletionCleanResult.accepted(CompletionSuggestion(text: " ready now"))

        #expect(rejected.traceMetadata == [
            "completionCleanResult": "rejected",
            "completionCleanRejectionReason": "lowSignalPhrase"
        ])
        #expect(accepted.traceMetadata == ["completionCleanResult": "accepted"])
        #expect(!rejected.traceMetadata.values.contains("private typed text"))
    }

    @Test("Candidate cleaning aggregates rejection reasons without text")
    func candidateCleaningAggregatesRejectionReasons() {
        let result = CompletionOutputCleaner(maxVisibleWords: 8).cleanCandidatesWithReasons(
            """
            candidate 1: ready for review
            candidate 2: press Enter to send
            candidate 3: ready for review
            """,
            after: "The draft is",
            mode: .phraseContinuation
        )

        #expect(result.suggestions.map(\.visibleText) == [" ready for review"])
        #expect(result.rejectionReasonCounts == [
            .unsafePromptAction: 1,
            .duplicateCandidate: 1
        ])
        #expect(result.traceMetadata == [
            "completionCleanRejectionCount": "2",
            "completionCleanRejectionReasons": "duplicateCandidate:1,unsafePromptAction:1"
        ])
    }
}
