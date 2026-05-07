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
        #expect(prompt.system.contains("Return only the suffix after the Before cursor text"))
        #expect(prompt.system.contains("boring connective tissue"))
        #expect(prompt.system.contains("Do not answer, explain"))
        #expect(prompt.system.contains("repeat the Before cursor text"))
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
        #expect(prompt.system.contains("No spaces"))
        #expect(prompt.user.hasSuffix("Suffix:"))
    }

    @Test("Prompt clamps oversized visible word requests")
    func promptClampsOversizedVisibleWordRequests() {
        let builder = CompletionPromptBuilder(maxVisibleWords: 20)
        let prompt = builder.prompt(for: CompletionRequest(textBeforeCursor: "I think we should"))

        #expect(builder.maxVisibleWords == 7)
        #expect(prompt.system.contains("next 7 words or fewer"))
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
}
