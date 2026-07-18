import Testing
@testable import AutocompleteLabCore

@Suite("Pending suggestion request continuity")
struct PendingSuggestionRequestContinuityPolicyTests {
    private let policy = PendingSuggestionRequestContinuityPolicy()

    @Test("Forward typing preserves a compatible request")
    func forwardTypingPreservesRequest() {
        #expect(policy.shouldPreserve(
            hasPendingRequest: true,
            requestTextBeforeCursor: "I want to dis",
            requestTextAfterCursor: "",
            requestFieldIdentityDescription: "com.openai.codex:42:1",
            currentTextBeforeCursor: "I want to discuss",
            currentTextAfterCursor: "",
            currentFieldIdentityDescription: "com.openai.codex:42:1"
        ))
    }

    @Test("Unchanged polling preserves a compatible request")
    func unchangedPollingPreservesRequest() {
        #expect(policy.shouldPreserve(
            hasPendingRequest: true,
            requestTextBeforeCursor: "A steady request",
            requestTextAfterCursor: "",
            requestFieldIdentityDescription: "com.openai.codex:42:1",
            currentTextBeforeCursor: "A steady request",
            currentTextAfterCursor: "",
            currentFieldIdentityDescription: "com.openai.codex:42:1"
        ))
    }

    @Test("Deletion cancels the request")
    func deletionCancelsRequest() {
        #expect(!policy.shouldPreserve(
            hasPendingRequest: true,
            requestTextBeforeCursor: "A steady request",
            requestTextAfterCursor: "",
            requestFieldIdentityDescription: "com.openai.codex:42:1",
            currentTextBeforeCursor: "A steady req",
            currentTextAfterCursor: "",
            currentFieldIdentityDescription: "com.openai.codex:42:1"
        ))
    }

    @Test("Divergent typing cancels the request")
    func divergentTypingCancelsRequest() {
        #expect(!policy.shouldPreserve(
            hasPendingRequest: true,
            requestTextBeforeCursor: "A steady request",
            requestTextAfterCursor: "",
            requestFieldIdentityDescription: "com.openai.codex:42:1",
            currentTextBeforeCursor: "A different request",
            currentTextAfterCursor: "",
            currentFieldIdentityDescription: "com.openai.codex:42:1"
        ))
    }

    @Test("Suffix or field changes cancel the request")
    func suffixOrFieldChangesCancelRequest() {
        #expect(!policy.shouldPreserve(
            hasPendingRequest: true,
            requestTextBeforeCursor: "A steady request",
            requestTextAfterCursor: " tail",
            requestFieldIdentityDescription: "com.openai.codex:42:1",
            currentTextBeforeCursor: "A steady request",
            currentTextAfterCursor: " changed",
            currentFieldIdentityDescription: "com.openai.codex:42:1"
        ))
        #expect(!policy.shouldPreserve(
            hasPendingRequest: true,
            requestTextBeforeCursor: "A steady request",
            requestTextAfterCursor: "",
            requestFieldIdentityDescription: "com.openai.codex:42:1",
            currentTextBeforeCursor: "A steady request",
            currentTextAfterCursor: "",
            currentFieldIdentityDescription: "com.openai.codex:42:2"
        ))
    }
}
