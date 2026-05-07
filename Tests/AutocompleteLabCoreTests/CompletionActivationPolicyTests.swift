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
            isFieldSuppressed: false
        ))
        #expect(policy.decision(
            textBeforeCursor: "I think this should ",
            textAfterCursor: "",
            isSecure: false,
            isFieldSuppressed: false
        ) == .allow(.phraseContinuation))
    }

    @Test("Allows suggestions before trailing whitespace on the current line")
    func allowsTrailingWhitespace() {
        let policy = CompletionActivationPolicy()

        #expect(policy.canSuggest(
            textBeforeCursor: "I think this should",
            textAfterCursor: "   \nnext line",
            isSecure: false,
            isFieldSuppressed: false
        ))
    }

    @Test("Blocks suggestions in the middle of existing text")
    func blocksMiddleOfLine() {
        let policy = CompletionActivationPolicy()

        #expect(!policy.canSuggest(
            textBeforeCursor: "I think",
            textAfterCursor: " this should stay",
            isSecure: false,
            isFieldSuppressed: false
        ))
        #expect(policy.decision(
            textBeforeCursor: "I think",
            textAfterCursor: " this should stay",
            isSecure: false,
            isFieldSuppressed: false
        ) == .block(.middleOfLine))
    }

    @Test("Blocks secure or suppressed fields")
    func blocksSensitiveFields() {
        let policy = CompletionActivationPolicy()

        #expect(!policy.canSuggest(
            textBeforeCursor: "I think this",
            textAfterCursor: "",
            isSecure: true,
            isFieldSuppressed: false
        ))
        #expect(policy.decision(
            textBeforeCursor: "I think this",
            textAfterCursor: "",
            isSecure: true,
            isFieldSuppressed: false
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

        for fieldKind in [AXFieldKind.search, .form, .url] {
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
            isFieldSuppressed: false
        ))
        #expect(policy.decision(
            textBeforeCursor: "Replace this",
            textAfterCursor: "",
            isSecure: false,
            selectedTextLength: 7,
            isFieldSuppressed: false
        ) == .block(.selectedText))
    }

    @Test("Blocks token, payment, and API key looking fields")
    func blocksTokenPaymentAndAPIKeyLookingFields() {
        let policy = CompletionActivationPolicy()

        #expect(policy.decision(
            textBeforeCursor: "api_key = sk-abcdefghijklmnopqrstuvwxyz",
            textAfterCursor: "",
            isSecure: false,
            isFieldSuppressed: false
        ) == .block(.sensitiveContent))
        #expect(policy.decision(
            textBeforeCursor: "Card number: 4242 4242 4242 4242",
            textAfterCursor: "",
            isSecure: false,
            isFieldSuppressed: false
        ) == .block(.sensitiveContent))
        #expect(policy.decision(
            textBeforeCursor: "client secret: ",
            textAfterCursor: "",
            isSecure: false,
            isFieldSuppressed: false
        ) == .block(.sensitiveContent))
    }

    @Test("Blocks very short context")
    func blocksShortContext() {
        let policy = CompletionActivationPolicy()

        #expect(!policy.canSuggest(
            textBeforeCursor: "hi",
            textAfterCursor: "",
            isSecure: false,
            isFieldSuppressed: false
        ))
        #expect(policy.decision(
            textBeforeCursor: "hi",
            textAfterCursor: "",
            isSecure: false,
            isFieldSuppressed: false
        ) == .block(.tooLittleContext))
    }

    @Test("Allows likely unfinished one word context")
    func allowsLikelyUnfinishedOneWordContext() {
        let policy = CompletionActivationPolicy()

        #expect(policy.decision(
            textBeforeCursor: "dic",
            textAfterCursor: "",
            isSecure: false,
            isFieldSuppressed: false
        ) == .allow(.wordCompletion))
    }

    @Test("Blocks complete-looking words and short phrase contexts")
    func blocksCompleteLookingWordsAndShortPhraseContexts() {
        let policy = CompletionActivationPolicy()

        #expect(policy.decision(
            textBeforeCursor: "I think",
            textAfterCursor: "",
            isSecure: false,
            isFieldSuppressed: false
        ) == .block(.unfinishedWord))

        #expect(policy.decision(
            textBeforeCursor: "I think ",
            textAfterCursor: "",
            isSecure: false,
            isFieldSuppressed: false
        ) == .block(.tooLittleContext))

        #expect(policy.decision(
            textBeforeCursor: "I think this through ",
            textAfterCursor: "",
            isSecure: false,
            isFieldSuppressed: false
        ) == .allow(.phraseContinuation))
    }

    @Test("Does not treat punctuation as word completion")
    func doesNotTreatPunctuationAsWordCompletion() {
        let policy = CompletionActivationPolicy()

        #expect(policy.decision(
            textBeforeCursor: "I finished the thing.",
            textAfterCursor: "",
            isSecure: false,
            isFieldSuppressed: false
        ) == .allow(.phraseContinuation))
    }

    @Test("Blocks phrase continuation while cursor is inside a common word")
    func blocksPhraseContinuationInsideCommonWord() {
        let policy = CompletionActivationPolicy()

        #expect(policy.decision(
            textBeforeCursor: "I need to understand an",
            textAfterCursor: "",
            isSecure: false,
            isFieldSuppressed: false
        ) == .block(.unfinishedWord))

        #expect(policy.decision(
            textBeforeCursor: "I need to understand an ",
            textAfterCursor: "",
            isSecure: false,
            isFieldSuppressed: false
        ) == .allow(.phraseContinuation))
    }

    @Test("Blocks short chat-like phrase bursts")
    func blocksShortChatLikePhraseBursts() {
        let policy = CompletionActivationPolicy()

        #expect(policy.decision(
            textBeforeCursor: "hi there ",
            textAfterCursor: "",
            isSecure: false,
            isFieldSuppressed: false
        ) == .block(.tooLittleContext))

        #expect(policy.decision(
            textBeforeCursor: "ok sounds good ",
            textAfterCursor: "",
            isSecure: false,
            isFieldSuppressed: false
        ) == .block(.tooLittleContext))
    }

    @Test("Blocks tiny form-like phrase contexts")
    func blocksTinyFormLikePhraseContexts() {
        let policy = CompletionActivationPolicy()

        #expect(policy.decision(
            textBeforeCursor: "First name: ",
            textAfterCursor: "",
            isSecure: false,
            isFieldSuppressed: false
        ) == .block(.tooLittleContext))

        #expect(policy.decision(
            textBeforeCursor: "Shipping address ",
            textAfterCursor: "",
            isSecure: false,
            isFieldSuppressed: false
        ) == .block(.tooLittleContext))
    }

    @Test("Allows safe word completion in short contexts")
    func allowsSafeWordCompletionInShortContexts() {
        let policy = CompletionActivationPolicy()

        #expect(policy.decision(
            textBeforeCursor: "First na",
            textAfterCursor: "",
            isSecure: false,
            isFieldSuppressed: false
        ) == .allow(.wordCompletion))
    }

    @Test("Blocks common complete one word context")
    func blocksCommonCompleteOneWordContext() {
        let policy = CompletionActivationPolicy()

        #expect(policy.decision(
            textBeforeCursor: "Hey",
            textAfterCursor: "",
            isSecure: false,
            isFieldSuppressed: false
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
            isFieldSuppressed: false
        ) == .block(.tooLittleContext))
        #expect(normal.decision(
            textBeforeCursor: "I think this through ",
            textAfterCursor: "",
            isSecure: false,
            isFieldSuppressed: false
        ) == .allow(.phraseContinuation))
        #expect(eager.decision(
            textBeforeCursor: "I think this ",
            textAfterCursor: "",
            isSecure: false,
            isFieldSuppressed: false
        ) == .allow(.phraseContinuation))
        #expect(quiet.decision(
            textBeforeCursor: "di",
            textAfterCursor: "",
            isSecure: false,
            isFieldSuppressed: false
        ) == .block(.tooLittleContext))
        #expect(eager.decision(
            textBeforeCursor: "dicti",
            textAfterCursor: "",
            isSecure: false,
            isFieldSuppressed: false
        ) == .allow(.wordCompletion))
    }

    @Test("Suggestion pace falls back to normal for missing or bad defaults")
    func suggestionPaceDefaultsToNormal() {
        #expect(SuggestionPace(persistedRawValue: nil) == .normal)
        #expect(SuggestionPace(persistedRawValue: "nope") == .normal)
        #expect(SuggestionPace(persistedRawValue: "quiet") == .quiet)
    }
}
