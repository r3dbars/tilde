import Testing
@testable import AutocompleteLabCore

@Suite("Completion output cleaner")
struct CompletionOutputCleanerTests {
    private let cleaner = CompletionOutputCleaner(maxVisibleWords: 8)

    private func clean(
        _ output: String,
        after context: String? = nil
    ) -> CompletionSuggestion? {
        cleaner.cleanWithReason(output, after: context).suggestion
    }

    private func reason(
        _ output: String,
        after context: String? = nil
    ) -> CompletionCleanRejectionReason? {
        cleaner.cleanWithReason(output, after: context).rejectionReason
    }

    @Test("Normalizes thinking, labels, spacing, and lines")
    func normalizesOutputShape() {
        let cases: [(String, String?, String)] = [
            ("keep moving today", nil, " keep moving today"),
            ("<think>I should explain</think>keep it tiny", nil, " keep it tiny"),
            ("<think>keep moving", nil, " keep moving"),
            ("ship this today\nbecause here is why", nil, " ship this today"),
            ("Next words: keep moving today", "Let's", " keep moving today"),
            ("candidate 1: keep moving today", "Let's", " keep moving today"),
            (" ready now", "Already ", "ready now"),
        ]

        for (output, context, expected) in cases {
            #expect(clean(output, after: context)?.visibleText == expected)
        }
    }

    @Test("Caps visible output once in CompletionSuggestion")
    func capsVisibleOutput() {
        let wordCapped = CompletionOutputCleaner(maxVisibleWords: 3).cleanWithReason(
            "one two three four five",
            after: nil
        ).suggestion
        let clamped = CompletionOutputCleaner(maxVisibleWords: 200).cleanWithReason(
            (1...24).map { "word\($0)" }.joined(separator: " "),
            after: nil
        ).suggestion

        #expect(wordCapped?.visibleText == " one two three")
        #expect(clamped?.visibleText.split(whereSeparator: { $0.isWhitespace }).count == 20)
    }

    @Test("Repairs a dangling tail exposed by the display cap")
    func repairsCapInducedDangler() {
        let suggestion = CompletionOutputCleaner(maxVisibleWords: 8).cleanWithReason(
            "see if you had any thoughts on the details.",
            after: nil
        ).suggestion

        #expect(suggestion?.visibleText == " see if you had any thoughts")
    }

    @Test("Rejects unsafe hidden and control characters")
    func rejectsUnsafeCharacters() {
        for output in [
            "safe\u{200B}text", "safe\u{200C}text", "safe\u{200D}text",
            "safe\u{2060}text", "safe\u{FEFF}text", "safe\ttext",
        ] {
            #expect(reason(output) == .unsafeHiddenOrControlCharacter)
        }
    }

    @Test("Rejects empty and no-suggestion output")
    func rejectsEmptyAndSentinel() {
        let empty = ["", "   ", "<think>nothing useful</think>", "Next words:"]
        let sentinels = [
            "<NO_SUGGESTION>", "`<no_suggestion>`", "Next words: <NO_SUGGESTION>",
            "Suffix: '<no_suggestion>'",
        ]

        for output in empty { #expect(reason(output) == .emptyOutput) }
        for output in sentinels { #expect(reason(output) == .noSuggestionSentinel) }
    }

    @Test("Rejects current scaffold, persona, and reasoning leaks")
    func rejectsInstructionLeaks() {
        let leaks = [
            "The following are real chat messages being written by their authors, continued naturally.",
            "The following are real emails being written by their authors, continued naturally.",
            "The following are real documents being written by their authors, continued naturally.",
            "System: continue this", "Assistant: here is the answer",
            "Thinking Process: analyze the request", "Okay, let's see what comes next",
            "Okay, the user is trying to write",
            "I'm sorry, but as an AI chatbot developed", "I cannot assist with that request",
            "As a language model I cannot say", "I am an AI language model",
            "I'm an AI assistant",
            "candidate 1", "Next 3-8 words, or <NO_SUGGESTION>",
        ]

        for output in leaks { #expect(reason(output, after: "Can we") == .promptInstructionEcho) }
        #expect(clean("I'm sorry about the delay", after: "Hey") != nil)
        #expect(clean("suffixes are common in English", after: "Grammar note: ") != nil)
    }

    @Test("Trims exact and partial typed-prefix overlap")
    func trimsTypedPrefixOverlap() {
        let cases: [(String, String, String?)] = [
            ("Hey there friend.", "Hey", " there friend."),
            ("hello and welcome", "hello and w", "elcome"),
            ("I want this to feel smoother", "I want this", " to feel smoother"),
            ("Know you are", "I know you are", nil),
        ]

        for (output, context, expected) in cases {
            #expect(clean(output, after: context)?.visibleText == expected)
        }
    }

    /// Live dogfood regression (2026-08-16, "Classify scenes by geometry,
    /// not host app"): typing "Sure, I will " (trailing space -- last typed
    /// word is complete) and getting back a raw continuation that re-opens
    /// with "I will" produced the ghost "I will try to get back to you" --
    /// a visible echo of what the user had just typed. `replaysContext`
    /// alone never caught this because it only flags 3+-word overlaps, and
    /// the whitespace branch of `trimTypedPrefix` used to only strip
    /// leading whitespace, with no word-echo check of its own. Screen-
    /// context prompts (a Conversation/Reference block sitting just ahead
    /// of `Text:`) make this kind of self-echo more likely, since the model
    /// has more of "the room's own words" to copy from -- but the guard
    /// belongs in the cleaner so every path gets it, not just the
    /// screen-context one.
    @Test("Strips a leading word-for-word echo of the just-typed context, even a short one")
    func stripsLeadingEchoOfJustTypedWords() {
        #expect(clean("I will try to get back to you", after: "Sure, I will ")?.visibleText == "try to get back to you")
        // Single-word echo.
        #expect(clean("will try to get back to you", after: "Sure, I will ")?.visibleText == "try to get back to you")
        // No echo at all: suggestion passes through untouched.
        #expect(clean("try to get back to you", after: "Sure, I will ")?.visibleText == "try to get back to you")
        // An echo that consumes the ENTIRE suggestion rejects as empty, same
        // as any other case where trimming leaves nothing behind.
        #expect(reason("I will", after: "Sure, I will ") == .emptyAfterPrefixTrimming)
    }

    @Test("Does not invent an overlap for an empty trailing fragment")
    func preservesSuggestionAfterPunctuation() {
        #expect(clean("apple", after: ".")?.visibleText == " apple")
        #expect(clean("hello", after: "hello.")?.visibleText == " hello")
    }

    @Test("Rejects obvious current and earlier context replay")
    func rejectsContextReplay() {
        let earlier = """
        I know you are ready to help

        Hey how are you
        """
        let current = "Intelligence of a person is interesting and something that I value"

        #expect(reason("know you are ready", after: earlier) == .replaysContext)
        #expect(reason("Intelligence of a person can vary", after: current) == .replaysContext)
        #expect(clean("the way they connect ideas", after: current)?.visibleText == " the way they connect ideas")
    }

    @Test("Allows ordinary prose instead of judging style")
    func allowsFormerSubjectiveBlacklistPhrases() {
        let ordinaryProse = [
            "Absolutely, I can help with that", "You should open the logs",
            "Press Enter to send the prompt", "the key features and benefits",
            "I think we should make a plan", "it",
            "ready. Then we can send it", "- review all reports",
            "The user asked for a clearer report", "User is the subject of this paragraph",
            "The language model section needs edits", "Our AI assistant demo starts tomorrow",
            "Research on an AI chatbot is moving quickly",
            "We describe Tilde as an AI assistant for writers",
            "As an airline, we publish the schedule", "As an assistant, I scheduled the meeting",
            "As an AI assistant, Tilde predicts a short continuation",
            "As an AI-powered tool, Tilde runs locally",
            "Before cursor movement, save the selection", "Return only one file to the shelf",
        ]

        for output in ordinaryProse { #expect(clean(output, after: "Now") != nil) }
    }

    @Test("Reports privacy-safe rejection reasons without candidate text")
    func reportsReasons() {
        let result = cleaner.cleanWithReason(
            "private\u{200B}text",
            after: "private typed text"
        )

        #expect(result.rejectionReason == .unsafeHiddenOrControlCharacter)
        #expect(result.suggestion == nil)
        #expect(result.rejectionReason?.rawValue == "unsafeHiddenOrControlCharacter")
    }
}
