import Testing
@testable import AutocompleteLabCore

@Suite("Completion activation policy")
struct CompletionActivationPolicyTests {
    @Test("Allows suggestions at the end of the current line")
    func allowsEndOfLine() {
        let policy = CompletionActivationPolicy()

        #expect(policy.canSuggest(
            textBeforeCursor: "I think this ",
            textAfterCursor: "",
            isSecure: false,
            isFieldSuppressed: false
        ))
        #expect(policy.decision(
            textBeforeCursor: "I think this ",
            textAfterCursor: "",
            isSecure: false,
            isFieldSuppressed: false
        ) == .allow(.phraseContinuation))
    }

    @Test("Allows suggestions before trailing whitespace on the current line")
    func allowsTrailingWhitespace() {
        let policy = CompletionActivationPolicy()

        #expect(policy.canSuggest(
            textBeforeCursor: "I think this",
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

    @Test("Blocks complete-looking words until a boundary")
    func blocksCompleteLookingWordsUntilBoundary() {
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
        ) == .allow(.phraseContinuation))
    }

    @Test("Does not treat punctuation as word completion")
    func doesNotTreatPunctuationAsWordCompletion() {
        let policy = CompletionActivationPolicy()

        #expect(policy.decision(
            textBeforeCursor: "the thing.",
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
}
