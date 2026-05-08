import Testing
@testable import AutocompleteLabCore

@Suite("Completion prompt builder")
struct CompletionPromptBuilderTests {
    @Test("Prompt asks for a tiny continuation only")
    func promptAsksForTinyContinuationOnly() {
        let builder = CompletionPromptBuilder(maxVisibleWords: 5)
        let prompt = builder.prompt(for: CompletionRequest(textBeforeCursor: "I think we should"))

        #expect(prompt.system.contains("next 5 words or fewer"))
        #expect(prompt.system.contains("Inline autocomplete"))
        #expect(prompt.system.contains("Return 1 to 3 candidate suffixes"))
        #expect(prompt.system.contains("best first"))
        #expect(prompt.system.contains("return exactly <NO_SUGGESTION>"))
        #expect(prompt.system.contains("confidence is low"))
        #expect(prompt.system.contains("boring connective tissue"))
        #expect(prompt.system.contains("Do not answer, explain"))
        #expect(prompt.system.contains("Do not brainstorm, rewrite"))
        #expect(prompt.system.contains("reason"))
        #expect(prompt.user.contains("Before cursor:\nI think we should"))
        #expect(prompt.user.hasSuffix("Next words:"))
    }

    @Test("Codex prompt avoids generic product filler")
    func codexPromptAvoidsGenericProductFiller() {
        let builder = CompletionPromptBuilder(maxVisibleWords: 5)
        let prompt = builder.prompt(for: CompletionRequest(
            textBeforeCursor: "I need this to be more accurate in the codex app so I can",
            appBundleIdentifier: "com.openai.codex"
        ))

        #expect(prompt.system.contains("dogfooding this autocomplete tool"))
        #expect(prompt.system.contains("text the user is typing into an agent prompt"))
        #expect(prompt.system.contains("testing, using, building, debugging"))
        #expect(prompt.system.contains("Never suggest pressing Enter/Return"))
        #expect(prompt.system.contains("integrate it seamlessly"))
        #expect(prompt.system.contains("boost productivity"))
        #expect(prompt.system.contains("streamline the workflow"))
    }

    @Test("Prompt includes aggregate kept style sketch")
    func promptIncludesAggregateKeptStyleSketch() {
        let builder = CompletionPromptBuilder(maxVisibleWords: 5)
        let prompt = builder.prompt(for: CompletionRequest(
            textBeforeCursor: "Can we make this",
            acceptedTextStyleSketch: AcceptedTextStyleSketch(
                sampleCount: 3,
                averageWordCount: 2.6,
                terminalPunctuationRate: 0.8,
                lowercaseStartRate: 0.7,
                questionEndingRate: 0
            )
        ))

        #expect(prompt.system.contains("Recent kept style sketch"))
        #expect(prompt.system.contains("avg 2.60 words"))
        #expect(prompt.system.contains("usually terminal punctuation"))
        #expect(!prompt.system.contains("make this simpler"))
    }

    @Test("Prompt includes trace safe partial word shape")
    func promptIncludesTraceSafePartialWordShape() {
        let builder = CompletionPromptBuilder(maxVisibleWords: 5)
        let prompt = builder.prompt(for: CompletionRequest(
            textBeforeCursor: "Please open Transcrip",
            mode: .wordCompletion
        ))

        #expect(prompt.system.contains("Partial word shape"))
        #expect(prompt.system.contains("9 characters"))
        #expect(prompt.system.contains("titlecase casing"))
        #expect(!prompt.system.contains("Transcrip"))
    }

    @Test("Prompt includes trace safe list shape")
    func promptIncludesTraceSafeListShape() {
        let builder = CompletionPromptBuilder(maxVisibleWords: 5)
        let prompt = builder.prompt(for: CompletionRequest(
            textBeforeCursor: "Plan\n  - [ ] Follow u"
        ))

        #expect(prompt.system.contains("Behavior profile: bullets"))
        #expect(prompt.system.contains("Current line shape: unchecked checklist item"))
        #expect(prompt.system.contains("marker style dash"))
        #expect(prompt.system.contains("indentation 2 columns"))
        #expect(prompt.system.contains("2 content words"))
        #expect(prompt.system.contains("do not repeat the marker or checkbox"))
        #expect(!prompt.system.contains("Follow u"))
    }

    @Test("Prompt keeps AI chat safety while adding list shape")
    func promptKeepsAIChatSafetyWhileAddingListShape() {
        let builder = CompletionPromptBuilder(maxVisibleWords: 5)
        let prompt = builder.prompt(for: CompletionRequest(
            textBeforeCursor: "- [ ] Make autocomplete",
            appBundleIdentifier: "com.openai.codex"
        ))

        #expect(prompt.system.contains("Behavior profile: ai_chat"))
        #expect(prompt.system.contains("Current line shape: unchecked checklist item"))
        #expect(prompt.system.contains("Never suggest sending, submitting"))
        #expect(prompt.system.contains("do not repeat the marker or checkbox"))
    }

    @Test("Codex prompt does not force dogfood topics into normal writing")
    func codexPromptDoesNotForceDogfoodTopicsIntoNormalWriting() {
        let builder = CompletionPromptBuilder(maxVisibleWords: 5)
        let prompt = builder.prompt(for: CompletionRequest(
            textBeforeCursor: "hello does this work right?",
            appBundleIdentifier: "com.openai.codex"
        ))

        #expect(prompt.system.contains("Continue the user's actual sentence naturally"))
        #expect(prompt.system.contains("text the user is typing into an agent prompt"))
        #expect(prompt.system.contains("Do not force software, testing, latency, placement, or debugging topics"))
        #expect(prompt.system.contains("Never suggest pressing Enter/Return"))
        #expect(!prompt.system.contains("Prefer concrete continuations about testing"))
    }

    @Test("Codex prompt ignores loose dogfood substrings")
    func codexPromptIgnoresLooseDogfoodSubstrings() {
        let builder = CompletionPromptBuilder(maxVisibleWords: 5)
        let prompt = builder.prompt(for: CompletionRequest(
            textBeforeCursor: "This table model should pass the normal writing test",
            appBundleIdentifier: "com.openai.codex"
        ))

        #expect(prompt.system.contains("Continue the user's actual sentence naturally"))
        #expect(!prompt.system.contains("dogfooding this autocomplete tool"))
        #expect(!prompt.system.contains("Prefer concrete continuations about testing"))
    }

    @Test("Codex prompt keeps normal suggestion words out of dogfood mode")
    func codexPromptKeepsNormalSuggestionWordsOutOfDogfoodMode() {
        let builder = CompletionPromptBuilder(maxVisibleWords: 5)
        let cases = [
            "I have a suggestion for dinner and",
            "Can you debug this paragraph without",
            "Trace the outline back to"
        ]

        for textBeforeCursor in cases {
            let prompt = builder.prompt(for: CompletionRequest(
                textBeforeCursor: textBeforeCursor,
                appBundleIdentifier: "com.openai.codex"
            ))

            #expect(
                prompt.system.contains("Continue the user's actual sentence naturally"),
                "Expected neutral dogfood-safe prompt for: \(textBeforeCursor)"
            )
            #expect(!prompt.system.contains("dogfooding this autocomplete tool"))
            #expect(!prompt.system.contains("Prefer concrete continuations about testing"))
        }
    }

    @Test("Claude Code prompt uses dogfood guidance")
    func claudeCodePromptUsesDogfoodGuidance() {
        let builder = CompletionPromptBuilder(maxVisibleWords: 5)
        let prompt = builder.prompt(for: CompletionRequest(
            textBeforeCursor: "I need this autocomplete debug trace to",
            appBundleIdentifier: "com.anthropic.claude-code"
        ))

        #expect(prompt.system.contains("The active app is Claude Code"))
        #expect(prompt.system.contains("dogfooding this autocomplete tool"))
        #expect(prompt.system.contains("testing, using, building, debugging"))
        #expect(prompt.system.contains("Never suggest pressing Enter/Return"))
    }

    @Test("Claude desktop prompt gets prompt app guidance")
    func claudeDesktopPromptGetsPromptAppGuidance() {
        let builder = CompletionPromptBuilder(maxVisibleWords: 5)
        let prompt = builder.prompt(for: CompletionRequest(
            textBeforeCursor: "Can you make this sentence",
            appBundleIdentifier: "com.anthropic.claudefordesktop"
        ))

        #expect(prompt.system.contains("The active app is Claude"))
        #expect(prompt.system.contains("text the user is typing into an agent prompt"))
        #expect(prompt.system.contains("not a prompt to answer"))
        #expect(prompt.system.contains("Never suggest pressing Enter/Return"))
    }

    @Test("Dogfood prompt recognizes prompt app safety context")
    func dogfoodPromptRecognizesPromptAppSafetyContext() {
        let builder = CompletionPromptBuilder(maxVisibleWords: 5)
        let prompt = builder.prompt(for: CompletionRequest(
            textBeforeCursor: "Claude Code no-submit prompt insertion should",
            appBundleIdentifier: "com.anthropic.claude-code"
        ))

        #expect(prompt.system.contains("dogfooding this autocomplete tool"))
        #expect(prompt.system.contains("Prefer concrete continuations about testing"))
    }

    @Test("Word completion prompt asks for only the current word suffix")
    func wordCompletionPromptAsksForSuffixOnly() {
        let builder = CompletionPromptBuilder()
        let prompt = builder.prompt(for: CompletionRequest(textBeforeCursor: "dic", mode: .wordCompletion))

        #expect(prompt.system.contains("Inline word completion"))
        #expect(prompt.system.contains("missing suffix"))
        #expect(prompt.system.contains("return exactly <NO_SUGGESTION>"))
        #expect(prompt.system.contains("confidence is low"))
        #expect(prompt.system.contains("No spaces"))
        #expect(prompt.user.hasSuffix("Suffix:"))
    }

    @Test("Prompt clamps oversized visible word requests")
    func promptClampsOversizedVisibleWordRequests() {
        let builder = CompletionPromptBuilder(maxVisibleWords: 20)
        let prompt = builder.prompt(for: CompletionRequest(textBeforeCursor: "I think we should"))

        #expect(builder.maxVisibleWords == 7)
        #expect(prompt.system.contains("next 5 words or fewer"))
        #expect(prompt.system.contains("Behavior profile: docs_prose"))
    }

    @Test("Prompt trims long context from the left")
    func promptTrimsLongContext() {
        let builder = CompletionPromptBuilder(
            maxContextCharacters: 120,
            maxCurrentParagraphCharacters: 120,
            maxCurrentSentenceCharacters: 120
        )
        let longText = String(repeating: "a", count: 200)
        let prompt = builder.prompt(for: CompletionRequest(textBeforeCursor: longText))

        #expect(prompt.user.contains(String(repeating: "a", count: 120)))
        #expect(!prompt.user.contains(String(repeating: "a", count: 121)))
    }

    @Test("Prompt uses current paragraph instead of older field text")
    func promptUsesCurrentParagraph() {
        let builder = CompletionPromptBuilder(
            maxContextCharacters: 300,
            maxCurrentParagraphCharacters: 120,
            maxCurrentSentenceCharacters: 120
        )
        let prompt = builder.prompt(for: CompletionRequest(textBeforeCursor: """
        I know you are ready and this old line should not steer the next suggestion.

        Hey how are you
        """))

        #expect(!prompt.user.contains("I know you are ready"))
        #expect(prompt.user.contains("Hey how are you"))
    }

    @Test("Prompt trims current paragraph from the left")
    func promptTrimsCurrentParagraphFromLeft() {
        let builder = CompletionPromptBuilder(
            maxContextCharacters: 300,
            maxCurrentParagraphCharacters: 90,
            maxCurrentSentenceCharacters: 90
        )
        let currentParagraph = String(repeating: "b", count: 140)
        let prompt = builder.prompt(for: CompletionRequest(textBeforeCursor: "Old paragraph\n\n\(currentParagraph)"))

        #expect(prompt.user.contains(String(repeating: "b", count: 90)))
        #expect(!prompt.user.contains("Old paragraph"))
        #expect(!prompt.user.contains(String(repeating: "b", count: 91)))
    }

    @Test("Prompt uses current sentence instead of earlier paragraph sentence")
    func promptUsesCurrentSentence() {
        let builder = CompletionPromptBuilder(
            maxContextCharacters: 300,
            maxCurrentParagraphCharacters: 220,
            maxCurrentSentenceCharacters: 120
        )
        let prompt = builder.prompt(for: CompletionRequest(textBeforeCursor: """
        I know you are ready and this earlier sentence should not steer Gemma. Hey how are you
        """))

        #expect(!prompt.user.contains("I know you are ready"))
        #expect(prompt.user.contains("Hey how are you"))
    }

    @Test("Prompt includes prior sentence when current fragment is short")
    func promptIncludesPriorSentenceForShortFragment() {
        let builder = CompletionPromptBuilder(
            maxContextCharacters: 300,
            maxCurrentParagraphCharacters: 220,
            maxCurrentSentenceCharacters: 120
        )
        let prompt = builder.prompt(for: CompletionRequest(textBeforeCursor: """
        The beta keeps typed text local. That means
        """))

        #expect(prompt.user.contains("The beta keeps typed text local. That means"))
    }

    @Test("Prompt caps context by token budget")
    func promptCapsContextByTokenBudget() throws {
        let builder = CompletionPromptBuilder(
            maxContextCharacters: 1_000,
            maxContextTokens: 48,
            maxCurrentParagraphCharacters: 1_000,
            maxCurrentSentenceCharacters: 1_000
        )
        let words = (1...80).map { "word\($0)" }.joined(separator: " ")
        let prompt = builder.prompt(for: CompletionRequest(textBeforeCursor: words))
        let context = try #require(prompt.user.contextBetweenCursorHeaderAndPromptSuffix)

        #expect(builder.maxContextTokens == 48)
        #expect(context.split(whereSeparator: { $0.isWhitespace }).count == 48)
        #expect(!context.contains("word1"))
        #expect(context.contains("word80"))
    }

    @Test("Sentence mode can borrow previous paragraph for a tiny new paragraph")
    func sentenceModeBorrowsPreviousParagraphForTinyNewParagraph() {
        let builder = CompletionPromptBuilder(
            maxContextCharacters: 300,
            maxContextTokens: 48,
            maxCurrentParagraphCharacters: 220,
            maxCurrentSentenceCharacters: 120
        )
        let prompt = builder.prompt(for: CompletionRequest(
            textBeforeCursor: """
            The launch note is about local autocomplete and privacy-first tracing.

            This
            """,
            mode: .sentenceContinuation
        ))

        #expect(prompt.user.contains("The launch note is about local autocomplete"))
        #expect(prompt.user.contains("This"))
    }

    @Test("Prompt keeps current paragraph when sentence ends at cursor")
    func promptKeepsParagraphWhenSentenceEndsAtCursor() {
        let builder = CompletionPromptBuilder(
            maxContextCharacters: 300,
            maxCurrentParagraphCharacters: 220,
            maxCurrentSentenceCharacters: 120
        )
        let prompt = builder.prompt(for: CompletionRequest(textBeforeCursor: "Can we make this work."))

        #expect(prompt.user.contains("Can we make this work."))
    }

    @Test("Prompt starts next sentence after sentence boundary")
    func promptStartsNextSentenceAfterSentenceBoundary() {
        let builder = CompletionPromptBuilder(maxVisibleWords: 5)
        let prompt = builder.prompt(for: CompletionRequest(textBeforeCursor: "Can we make this work."))

        #expect(prompt.system.contains("Start the next sentence naturally"))
        #expect(!prompt.system.contains("Continue the current sentence"))
    }

    @Test("Sentence continuation prompt uses explicit sentence mode guidance")
    func sentenceContinuationPromptUsesExplicitSentenceModeGuidance() {
        let builder = CompletionPromptBuilder(maxVisibleWords: 5)
        let prompt = builder.prompt(for: CompletionRequest(
            textBeforeCursor: "Can we make this work.",
            mode: .sentenceContinuation
        ))

        #expect(prompt.system.contains("Sentence mode: start only the next sentence's first few words"))
        #expect(prompt.system.contains("Require higher confidence"))
        #expect(prompt.system.contains("Start the next sentence naturally"))
        #expect(!prompt.system.contains("Phrase mode: continue only the current local thought"))
    }

    @Test("Prompt uses AI chat behavior profile from app metadata")
    func promptUsesAIChatBehaviorProfileFromAppMetadata() {
        let builder = CompletionPromptBuilder(maxVisibleWords: 5)
        let prompt = builder.prompt(for: CompletionRequest(
            textBeforeCursor: "Can you make this easier to",
            appBundleIdentifier: "com.openai.codex"
        ))

        #expect(prompt.system.contains("next 1 words or fewer"))
        #expect(prompt.system.contains("Behavior profile: ai_chat, max 1 visible words / 4 generated tokens"))
        #expect(prompt.system.contains("Never suggest sending, submitting"))
        #expect(prompt.system.contains("Never suggest pressing Enter/Return"))
    }

    @Test("Prompt uses field kind behavior profile before app metadata")
    func promptUsesFieldKindBehaviorProfileBeforeAppMetadata() {
        let builder = CompletionPromptBuilder(maxVisibleWords: 5)
        let searchPrompt = builder.prompt(for: CompletionRequest(
            textBeforeCursor: "autocomplete",
            appBundleIdentifier: "com.apple.Notes",
            fieldKind: .search
        ))
        let formPrompt = builder.prompt(for: CompletionRequest(
            textBeforeCursor: "Justin",
            appBundleIdentifier: "com.openai.codex",
            fieldKind: .form
        ))

        #expect(searchPrompt.system.contains("next 1 words or fewer"))
        #expect(searchPrompt.system.contains("Behavior profile: search"))
        #expect(searchPrompt.system.contains("Search fields are suppressed by default"))
        #expect(formPrompt.system.contains("Behavior profile: forms"))
        #expect(formPrompt.system.contains("Forms are suppressed by default"))
        #expect(formPrompt.system.contains("Do not fill names, addresses"))
    }

    @Test("Prompt honors explicit behavior profile and request visible word cap")
    func promptHonorsExplicitBehaviorProfileAndRequestVisibleWordCap() {
        let builder = CompletionPromptBuilder(maxVisibleWords: 6)
        let prompt = builder.prompt(for: CompletionRequest(
            textBeforeCursor: "I think this should",
            appBundleIdentifier: "com.apple.Notes",
            behaviorProfileID: .email,
            maxVisibleWords: 3
        ))

        #expect(prompt.system.contains("next 3 words or fewer"))
        #expect(prompt.system.contains("Behavior profile: email"))
        #expect(prompt.system.contains("Do not invent commitments"))
    }
}

private extension String {
    var contextBetweenCursorHeaderAndPromptSuffix: String? {
        guard let headerRange = range(of: "Before cursor:\n"),
              let suffixRange = range(of: "\n\nNext words:") ?? range(of: "\n\nSuffix:") else {
            return nil
        }

        return String(self[headerRange.upperBound..<suffixRange.lowerBound])
    }
}
