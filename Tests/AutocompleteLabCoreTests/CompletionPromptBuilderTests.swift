import Testing
@testable import AutocompleteLabCore

@Suite("Completion prompt builder")
struct CompletionPromptBuilderTests {
    @Test("Prompt asks for a bounded continuation only")
    func promptAsksForBoundedContinuationOnly() {
        let builder = CompletionPromptBuilder(maxVisibleWords: 5)
        let prompt = builder.prompt(for: CompletionRequest(textBeforeCursor: "I think we should"))

        #expect(prompt.system.contains("next 5 words or fewer"))
        #expect(prompt.system.contains("Length setting: short"))
        #expect(prompt.system.contains("Return 1 or 2 candidate suffixes"))
        #expect(prompt.system.contains("Inline autocomplete"))
        #expect(prompt.system.contains("Return only the suffix after the Before cursor text"))
        #expect(prompt.system.contains("boring connective tissue"))
        #expect(prompt.system.contains("Prefer enough high-confidence words"))
        #expect(prompt.system.contains("not obvious from the local text"))
        #expect(prompt.system.contains("weak guess, new topic"))
        #expect(prompt.system.contains("Never suggest pressing Tab, Option-Tab, Backtick"))
        #expect(prompt.system.contains("do not suggest accepting terms or permissions"))
        #expect(prompt.system.contains("Ordinary drafting with should or need"))
        #expect(prompt.system.contains("answer the user, issue an instruction"))
        #expect(prompt.system.contains("Avoid generic filler"))
        #expect(prompt.system.contains("The review should focus on"))
        #expect(prompt.system.contains("Correct this spelling: recieve"))
        #expect(prompt.system.contains("adress ->"))
        #expect(prompt.system.contains("Before we ship, we should"))
        #expect(prompt.system.contains("The meeting notes need a"))
        #expect(prompt.system.contains("simple simple, so the next words should"))
        #expect(prompt.system.contains("Make the copy"))
        #expect(prompt.system.contains("Return only the corrected word"))
        #expect(prompt.system.contains("This bug is easiest to test with"))
        #expect(prompt.system.contains("Hold the risky path until"))
        #expect(prompt.system.contains("tested the button, tested the button"))
        #expect(prompt.system.contains("press Tab and confirm"))
        #expect(prompt.system.contains("common phrase"))
        #expect(prompt.system.contains("Do not answer, explain"))
        #expect(prompt.system.contains("repeat the Before cursor text"))
        #expect(prompt.system.contains("Do not brainstorm, rewrite"))
        #expect(prompt.system.contains("reason"))
        #expect(prompt.user.contains("Before cursor:\nI think we should"))
        #expect(prompt.user.hasSuffix("Next words:"))
    }

    @Test("Default daily-driver prompt asks for a three to eight word phrase")
    func defaultDailyDriverPromptAsksForThreeToEightWordPhrase() {
        let builder = CompletionPromptBuilder(maxVisibleWords: 8)
        let prompt = builder.prompt(for: CompletionRequest(
            textBeforeCursor: "This should feel",
            maxVisibleWords: 8
        ))

        #expect(prompt.system.contains("next 8 words or fewer"))
        #expect(prompt.system.contains("Length setting: medium. Prefer at least 3 words"))
        #expect(prompt.user.hasSuffix("Next 3-8 words, or <NO_SUGGESTION>:"))
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

    @Test("Prompt includes trace safe document title shape")
    func promptIncludesTraceSafeDocumentTitleShape() {
        let builder = CompletionPromptBuilder(maxVisibleWords: 5)
        let prompt = builder.prompt(for: CompletionRequest(
            textBeforeCursor: "Can we keep this",
            documentTitleShape: DocumentTitleShape.from(windowTitle: "Launch Plan.md *")
        ))

        #expect(prompt.system.contains("Document/window title shape"))
        #expect(prompt.system.contains("file extension md"))
        #expect(prompt.system.contains("unsaved marker present"))
        #expect(prompt.system.contains("weak genre context"))
        #expect(!prompt.system.contains("Launch"))
        #expect(!prompt.system.contains("Plan"))
    }

    @Test("Prompt can include opt-in visible page context")
    func promptCanIncludeVisiblePageContext() throws {
        let pageContext = try #require(VisiblePageContext(text: """
        Launch Plan
        - Keep OCR local
        Untitled 13
        Save
        Save
        !!!
        """))
        let builder = CompletionPromptBuilder(maxVisibleWords: 5)
        let prompt = builder.prompt(for: CompletionRequest(
            textBeforeCursor: "We should",
            visiblePageContext: pageContext
        ))

        #expect(prompt.system.contains("Visible page context source: screen_ocr, scope: visible_screen"))
        #expect(prompt.system.contains("Use it to infer the active app"))
        #expect(prompt.system.contains("Prefer a useful best guess"))
        #expect(prompt.system.contains("Never output visible window titles"))
        #expect(prompt.user.contains("Visible page context:\nOCR scope: visible_screen\nLaunch Plan"))
        #expect(prompt.user.contains("OCR scope: visible_screen"))
        #expect(prompt.user.contains("- Keep OCR local"))
        #expect(!prompt.user.contains("Untitled 13"))
        #expect(prompt.user.contains("Before cursor:\nWe should"))
        #expect(prompt.user.hasSuffix("Next words:"))
        #expect(!prompt.user.contains("!!!"))
    }

    @Test("Prompt uses active app screen context as reply evidence")
    func promptUsesActiveAppScreenContextAsReplyEvidence() throws {
        let pageContext = try #require(VisiblePageContext(
            captureScope: .visibleScreen,
            activeApplicationName: "Obsidian",
            text: """
            Inbox
            Sam: Can you send the launch note today?
            Draft
            Yeah I can
            """
        ))
        let builder = CompletionPromptBuilder(maxVisibleWords: 8)
        let prompt = builder.prompt(for: CompletionRequest(
            textBeforeCursor: "Yeah I can",
            appBundleIdentifier: "md.obsidian",
            visiblePageContext: pageContext,
            maxVisibleWords: 8
        ))

        #expect(prompt.system.contains("what the user is replying to"))
        #expect(prompt.system.contains("local writing companion"))
        #expect(prompt.user.contains("Active app: Obsidian"))
        #expect(prompt.user.contains("Sam: Can you send the launch note today?"))
        #expect(prompt.user.contains("Before cursor:\nYeah I can"))
    }

    @Test("Word prompt includes trace safe document title shape")
    func wordPromptIncludesTraceSafeDocumentTitleShape() {
        let builder = CompletionPromptBuilder(maxVisibleWords: 5)
        let prompt = builder.prompt(for: CompletionRequest(
            textBeforeCursor: "Lau",
            documentTitleShape: DocumentTitleShape.from(windowTitle: "Launch Plan.md *"),
            mode: .wordCompletion
        ))

        #expect(prompt.system.contains("Document/window title shape"))
        #expect(prompt.system.contains("Tab inserts only this visible suffix"))
        #expect(prompt.system.contains("transi -> tion"))
        #expect(prompt.system.contains("qui -> etly"))
        #expect(prompt.system.contains("return rable, not ration"))
        #expect(prompt.system.contains("Do not return tion for redac"))
        #expect(prompt.system.contains("privacy note should stay redac"))
        #expect(prompt.system.contains("Never return tion unless it completes the visible word"))
        #expect(prompt.system.contains("file extension md"))
        #expect(!prompt.system.contains("Launch"))
        #expect(!prompt.system.contains("Plan"))
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
        #expect(prompt.system.contains("complete the visible local word"))
        #expect(prompt.system.contains("return exactly <NO_SUGGESTION>"))
        #expect(prompt.system.contains("suffix would complete the wrong word"))
        #expect(prompt.system.contains("No spaces"))
        #expect(prompt.user.hasSuffix("Suffix:"))
    }

    @Test("Prompt allows extended visible word requests")
    func promptAllowsExtendedVisibleWordRequests() {
        let builder = CompletionPromptBuilder(maxVisibleWords: 20)
        let prompt = builder.prompt(for: CompletionRequest(
            textBeforeCursor: "I think we should",
            maxVisibleWords: 20
        ))

        #expect(builder.maxVisibleWords == 20)
        #expect(prompt.system.contains("next 20 words or fewer"))
        #expect(prompt.system.contains("Return exactly one longer candidate suffix"))
        #expect(prompt.system.contains("The candidate must be 12-20 words"))
        #expect(prompt.system.contains("Do not stop at a 2-4 word phrase"))
        #expect(prompt.system.contains("return <NO_SUGGESTION> instead of a short fallback"))
        #expect(prompt.system.contains("Long natural examples"))
        #expect(prompt.system.contains("easy to finish without making the user think about permissions twice"))
        #expect(!prompt.system.contains(#""The onboarding screen should make" -> "permission feel clear""#))
        #expect(prompt.system.contains("Behavior profile: docs_prose"))
        #expect(prompt.user.hasSuffix("Next 12-20 words, or <NO_SUGGESTION>:"))
    }

    @Test("High word slider overrides short kept style for length")
    func highWordSliderOverridesShortKeptStyleForLength() {
        let builder = CompletionPromptBuilder(maxVisibleWords: 20)
        let prompt = builder.prompt(for: CompletionRequest(
            textBeforeCursor: "The onboarding note should make the setup feel clear and",
            acceptedTextStyleSketch: AcceptedTextStyleSketch(
                sampleCount: 22,
                averageWordCount: 1.23,
                terminalPunctuationRate: 0,
                lowercaseStartRate: 1,
                questionEndingRate: 0,
                shortSuffixRate: 0.91
            ),
            maxVisibleWords: 20
        ))

        #expect(prompt.system.contains("Recent kept style sketch: avg 1.23 words"))
        #expect(prompt.system.contains("Length setting overrides recent short-kept history"))
        #expect(prompt.system.contains("not to shrink the suggestion below the high word-count target"))
        #expect(prompt.user.hasSuffix("Next 12-20 words, or <NO_SUGGESTION>:"))
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

        #expect(prompt.system.contains("Sentence mode: continue naturally up to the visible word limit"))
        #expect(prompt.system.contains("longer sentence chunk is allowed"))
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

        #expect(prompt.system.contains("next 5 words or fewer"))
        #expect(prompt.system.contains("Behavior profile: ai_chat, max 20 visible words / 48 generated tokens"))
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
              let suffixRange = range(of: "\n\nNext ") ?? range(of: "\n\nSuffix:") else {
            return nil
        }

        return String(self[headerRange.upperBound..<suffixRange.lowerBound])
    }
}
