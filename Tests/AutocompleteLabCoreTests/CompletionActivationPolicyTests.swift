import Testing
@testable import AutocompleteLabCore

@Suite("Completion activation policy")
struct CompletionActivationPolicyTests {
    @Test("Allows suggestions at the end of the current line")
    func allowsEndOfLine() {
        let policy = CompletionActivationPolicy()

        #expect(policy.canSuggest(
            textBeforeCursor: "I think this should ",
            textAfterCursor: "",
            isSecure: false,
            isFieldSuppressed: false,
            fieldKind: .multilineCompose
        ))
        #expect(policy.decision(
            textBeforeCursor: "I think this should ",
            textAfterCursor: "",
            isSecure: false,
            isFieldSuppressed: false,
            fieldKind: .multilineCompose
        ) == .allow(.phraseContinuation))
    }

    @Test("Allows suggestions before trailing whitespace on the current line")
    func allowsTrailingWhitespace() {
        let policy = CompletionActivationPolicy()

        #expect(policy.canSuggest(
            textBeforeCursor: "I think this should",
            textAfterCursor: "   \nnext line",
            isSecure: false,
            isFieldSuppressed: false,
            fieldKind: .multilineCompose
        ))
    }

    @Test("Blocks suggestions in the middle of existing text")
    func blocksMiddleOfLine() {
        let policy = CompletionActivationPolicy()

        #expect(!policy.canSuggest(
            textBeforeCursor: "I think",
            textAfterCursor: " this should stay",
            isSecure: false,
            isFieldSuppressed: false,
            fieldKind: .multilineCompose
        ))
        #expect(policy.decision(
            textBeforeCursor: "I think",
            textAfterCursor: " this should stay",
            isSecure: false,
            isFieldSuppressed: false,
            fieldKind: .multilineCompose
        ) == .block(.middleOfLine))
    }

    @Test("Blocks secure or suppressed fields")
    func blocksSensitiveFields() {
        let policy = CompletionActivationPolicy()

        #expect(!policy.canSuggest(
            textBeforeCursor: "I think this",
            textAfterCursor: "",
            isSecure: true,
            isFieldSuppressed: false,
            fieldKind: .multilineCompose
        ))
        #expect(policy.decision(
            textBeforeCursor: "I think this",
            textAfterCursor: "",
            isSecure: true,
            isFieldSuppressed: false,
            fieldKind: .multilineCompose
        ) == .block(.secureField))

        #expect(!policy.canSuggest(
            textBeforeCursor: "I think this",
            textAfterCursor: "",
            isSecure: false,
            isFieldSuppressed: true
        ))
        #expect(policy.decision(
            textBeforeCursor: "I think this",
            textAfterCursor: "",
            isSecure: false,
            isFieldSuppressed: true
        ) == .block(.suppressedField))
    }

    @Test("Blocks unsafe field kinds")
    func blocksUnsafeFieldKinds() {
        let policy = CompletionActivationPolicy()

        for fieldKind in [AXFieldKind.search, .form, .url, .unprovenSurface, .unknown] {
            #expect(policy.decision(
                textBeforeCursor: "I think this",
                textAfterCursor: "",
                isSecure: false,
                isFieldSuppressed: false,
                fieldKind: fieldKind
            ) == .block(.blockedFieldKind))
        }

        #expect(policy.decision(
            textBeforeCursor: "I think this through ",
            textAfterCursor: "",
            isSecure: false,
            isFieldSuppressed: false,
            fieldKind: .multilineCompose
        ) == .allow(.phraseContinuation))
    }

    @Test("Blocks selected text so accept cannot overwrite user content")
    func blocksSelectedText() {
        let policy = CompletionActivationPolicy()

        #expect(!policy.canSuggest(
            textBeforeCursor: "Replace this",
            textAfterCursor: "",
            isSecure: false,
            selectedTextLength: 7,
            isFieldSuppressed: false,
            fieldKind: .multilineCompose
        ))
        #expect(policy.decision(
            textBeforeCursor: "Replace this",
            textAfterCursor: "",
            isSecure: false,
            selectedTextLength: 7,
            isFieldSuppressed: false,
            fieldKind: .multilineCompose
        ) == .block(.selectedText))
    }

    @Test("Blocks token, payment, and API key looking fields")
    func blocksTokenPaymentAndAPIKeyLookingFields() {
        let policy = CompletionActivationPolicy()

        #expect(policy.decision(
            textBeforeCursor: "api_key = sk-abcdefghijklmnopqrstuvwxyz",
            textAfterCursor: "",
            isSecure: false,
            isFieldSuppressed: false,
            fieldKind: .multilineCompose
        ) == .block(.sensitiveContent))
        #expect(policy.decision(
            textBeforeCursor: "Card number: 4242 4242 4242 4242",
            textAfterCursor: "",
            isSecure: false,
            isFieldSuppressed: false,
            fieldKind: .multilineCompose
        ) == .block(.sensitiveContent))
        #expect(policy.decision(
            textBeforeCursor: "client secret: ",
            textAfterCursor: "",
            isSecure: false,
            isFieldSuppressed: false,
            fieldKind: .multilineCompose
        ) == .block(.sensitiveContent))
    }

    @Test("Blocks very short context")
    func blocksShortContext() {
        let policy = CompletionActivationPolicy()

        #expect(!policy.canSuggest(
            textBeforeCursor: "hi",
            textAfterCursor: "",
            isSecure: false,
            isFieldSuppressed: false,
            fieldKind: .multilineCompose
        ))
        #expect(policy.decision(
            textBeforeCursor: "hi",
            textAfterCursor: "",
            isSecure: false,
            isFieldSuppressed: false,
            fieldKind: .multilineCompose
        ) == .block(.tooLittleContext))
    }

    @Test("Allows likely unfinished one word context")
    func allowsLikelyUnfinishedOneWordContext() {
        let policy = CompletionActivationPolicy()

        #expect(policy.decision(
            textBeforeCursor: "dic",
            textAfterCursor: "",
            isSecure: false,
            isFieldSuppressed: false,
            fieldKind: .multilineCompose
        ) == .allow(.wordCompletion))
    }

    @Test("Blocks complete-looking words and short phrase contexts")
    func blocksCompleteLookingWordsAndShortPhraseContexts() {
        let policy = CompletionActivationPolicy()

        #expect(policy.decision(
            textBeforeCursor: "I think",
            textAfterCursor: "",
            isSecure: false,
            isFieldSuppressed: false,
            fieldKind: .multilineCompose
        ) == .block(.unfinishedWord))

        #expect(policy.decision(
            textBeforeCursor: "I think ",
            textAfterCursor: "",
            isSecure: false,
            isFieldSuppressed: false,
            fieldKind: .multilineCompose
        ) == .block(.tooLittleContext))

        #expect(policy.decision(
            textBeforeCursor: "I think this through ",
            textAfterCursor: "",
            isSecure: false,
            isFieldSuppressed: false,
            fieldKind: .multilineCompose
        ) == .allow(.phraseContinuation))
    }

    @Test("Sentence-ending punctuation stays quiet by default")
    func sentenceEndingPunctuationStaysQuietByDefault() {
        let policy = CompletionActivationPolicy()

        #expect(policy.decision(
            textBeforeCursor: "I finished the thing.",
            textAfterCursor: "",
            isSecure: false,
            isFieldSuppressed: false,
            fieldKind: .multilineCompose
        ) == .block(.terminalSentenceBoundary))

        #expect(policy.decision(
            textBeforeCursor: "I finished the thing. ",
            textAfterCursor: "",
            isSecure: false,
            isFieldSuppressed: false,
            fieldKind: .multilineCompose
        ) == .block(.terminalSentenceBoundary))
        #expect(policy.decision(
            textBeforeCursor: "I finished the thing?",
            textAfterCursor: "",
            isSecure: false,
            isFieldSuppressed: false,
            fieldKind: .multilineCompose
        ) == .block(.terminalSentenceBoundary))
        #expect(policy.decision(
            textBeforeCursor: "I finished the thing!",
            textAfterCursor: "",
            isSecure: false,
            isFieldSuppressed: false,
            fieldKind: .multilineCompose
        ) == .block(.terminalSentenceBoundary))
    }

    @Test("Blocks unsupported Markdown code contexts")
    func blocksUnsupportedMarkdownCodeContexts() {
        let policy = CompletionActivationPolicy()

        #expect(policy.decision(
            textBeforeCursor: "Here is the command:\n```swift\nlet value = ma",
            textAfterCursor: "",
            isSecure: false,
            isFieldSuppressed: false,
            fieldKind: .multilineCompose
        ) == .block(.markdownCodeContext))

        #expect(policy.decision(
            textBeforeCursor: "Here is the command:\n```swift\nlet value = make()\n```\nNow this should ",
            textAfterCursor: "",
            isSecure: false,
            isFieldSuppressed: false,
            fieldKind: .multilineCompose
        ) == .allow(.phraseContinuation))

        #expect(policy.decision(
            textBeforeCursor: "Use `swift bu",
            textAfterCursor: "` when testing",
            isSecure: false,
            isFieldSuppressed: false,
            fieldKind: .multilineCompose
        ) == .block(.markdownCodeContext))
    }

    @Test("Blocks phrase continuation while cursor is inside a common word")
    func blocksPhraseContinuationInsideCommonWord() {
        let policy = CompletionActivationPolicy()

        #expect(policy.decision(
            textBeforeCursor: "I need to understand an",
            textAfterCursor: "",
            isSecure: false,
            isFieldSuppressed: false,
            fieldKind: .multilineCompose
        ) == .block(.unfinishedWord))

        #expect(policy.decision(
            textBeforeCursor: "I need to understand an ",
            textAfterCursor: "",
            isSecure: false,
            isFieldSuppressed: false,
            fieldKind: .multilineCompose
        ) == .allow(.phraseContinuation))
    }

    @Test("Blocks short chat-like phrase bursts")
    func blocksShortChatLikePhraseBursts() {
        let policy = CompletionActivationPolicy()

        #expect(policy.decision(
            textBeforeCursor: "hi there ",
            textAfterCursor: "",
            isSecure: false,
            isFieldSuppressed: false,
            fieldKind: .multilineCompose
        ) == .block(.tooLittleContext))

        #expect(policy.decision(
            textBeforeCursor: "ok sounds good ",
            textAfterCursor: "",
            isSecure: false,
            isFieldSuppressed: false,
            fieldKind: .multilineCompose
        ) == .block(.tooLittleContext))
    }

    @Test("Blocks tiny form-like phrase contexts")
    func blocksTinyFormLikePhraseContexts() {
        let policy = CompletionActivationPolicy()

        #expect(policy.decision(
            textBeforeCursor: "First name: ",
            textAfterCursor: "",
            isSecure: false,
            isFieldSuppressed: false,
            fieldKind: .multilineCompose
        ) == .block(.tooLittleContext))

        #expect(policy.decision(
            textBeforeCursor: "Shipping address ",
            textAfterCursor: "",
            isSecure: false,
            isFieldSuppressed: false,
            fieldKind: .multilineCompose
        ) == .block(.tooLittleContext))
    }

    @Test("Allows safe word completion in short contexts")
    func allowsSafeWordCompletionInShortContexts() {
        let policy = CompletionActivationPolicy()

        #expect(policy.decision(
            textBeforeCursor: "First nam",
            textAfterCursor: "",
            isSecure: false,
            isFieldSuppressed: false,
            fieldKind: .multilineCompose
        ) == .allow(.wordCompletion))
    }

    @Test("Blocks two-letter word completion")
    func blocksTwoLetterWordCompletion() {
        let policy = CompletionActivationPolicy()

        #expect(policy.decision(
            textBeforeCursor: "First na",
            textAfterCursor: "",
            isSecure: false,
            isFieldSuppressed: false
        ) == .block(.unfinishedWord))
    }

    @Test("Allows checklist completions after constrained item text")
    func allowsChecklistCompletionsAfterConstrainedItemText() {
        let policy = CompletionActivationPolicy()

        #expect(policy.decision(
            textBeforeCursor: "- [ ] Follow upd",
            textAfterCursor: "",
            isSecure: false,
            isFieldSuppressed: false,
            fieldKind: .multilineCompose
        ) == .allow(.wordCompletion))

        #expect(policy.decision(
            textBeforeCursor: "- [ ] Follow up with ",
            textAfterCursor: "",
            isSecure: false,
            isFieldSuppressed: false,
            fieldKind: .multilineCompose
        ) == .allow(.phraseContinuation))
    }

    @Test("Blocks common complete one word context")
    func blocksCommonCompleteOneWordContext() {
        let policy = CompletionActivationPolicy()

        #expect(policy.decision(
            textBeforeCursor: "Hey",
            textAfterCursor: "",
            isSecure: false,
            isFieldSuppressed: false,
            fieldKind: .multilineCompose
        ) == .block(.tooLittleContext))
    }

    @Test("Suggestion pace changes phrase and word completion eagerness")
    func suggestionPaceChangesActivationThresholds() {
        let quiet = CompletionActivationPolicy(pace: .quiet)
        let normal = CompletionActivationPolicy(pace: .normal)
        let eager = CompletionActivationPolicy(pace: .eager)

        #expect(quiet.decision(
            textBeforeCursor: "I think this through ",
            textAfterCursor: "",
            isSecure: false,
            isFieldSuppressed: false,
            fieldKind: .multilineCompose
        ) == .block(.tooLittleContext))
        #expect(normal.decision(
            textBeforeCursor: "I think this through ",
            textAfterCursor: "",
            isSecure: false,
            isFieldSuppressed: false,
            fieldKind: .multilineCompose
        ) == .allow(.phraseContinuation))
        #expect(eager.decision(
            textBeforeCursor: "I think this ",
            textAfterCursor: "",
            isSecure: false,
            isFieldSuppressed: false,
            fieldKind: .multilineCompose
        ) == .allow(.phraseContinuation))
        #expect(quiet.decision(
            textBeforeCursor: "di",
            textAfterCursor: "",
            isSecure: false,
            isFieldSuppressed: false,
            fieldKind: .multilineCompose
        ) == .block(.tooLittleContext))
        #expect(eager.decision(
            textBeforeCursor: "dicti",
            textAfterCursor: "",
            isSecure: false,
            isFieldSuppressed: false,
            fieldKind: .multilineCompose
        ) == .allow(.wordCompletion))
    }

    @Test("App support level caps eager suggestion pace for unproven apps")
    func appSupportLevelCapsEagerSuggestionPace() throws {
        let store = CompatibilityProfileStore.mvp
        let policy = SuggestionAggressivenessPolicy()
        let textEdit = try #require(store.profile(for: "com.apple.TextEdit"))
        let notes = try #require(store.profile(for: "com.apple.Notes"))

        #expect(policy.pace(userPace: .eager, supportStatus: .supported(textEdit)) == .eager)
        #expect(policy.pace(userPace: .eager, supportStatus: .supported(notes)) == .normal)
        #expect(policy.pace(userPace: .normal, supportStatus: .supported(notes)) == .normal)
        #expect(policy.pace(userPace: .quiet, supportStatus: .supported(notes)) == .quiet)
        #expect(policy.pace(userPace: .eager, supportStatus: .unsupported) == .quiet)
        #expect(policy.pace(userPace: .eager, supportStatus: .denylisted) == .quiet)
    }

    @Test("Suggestion pace falls back to normal for missing or bad defaults")
    func suggestionPaceDefaultsToNormal() {
        #expect(SuggestionPace(persistedRawValue: nil) == .normal)
        #expect(SuggestionPace(persistedRawValue: "nope") == .normal)
        #expect(SuggestionPace(persistedRawValue: "quiet") == .quiet)
    }
}
