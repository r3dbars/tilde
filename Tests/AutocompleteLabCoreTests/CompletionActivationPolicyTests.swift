import Testing
@testable import AutocompleteLabCore

@Suite("Completion activation policy")
struct CompletionActivationPolicyTests {
    @Test("Allows suggestions at the end of the current line")
    func allowsEndOfLine() {
        let policy = CompletionActivationPolicy()

        #expect(policy.canSuggest(
            textBeforeCursor: "I think this",
            textAfterCursor: "",
            isSecure: false,
            isFieldSuppressed: false
        ))
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

        #expect(!policy.canSuggest(
            textBeforeCursor: "I think this",
            textAfterCursor: "",
            isSecure: false,
            isFieldSuppressed: true
        ))
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
    }
}
