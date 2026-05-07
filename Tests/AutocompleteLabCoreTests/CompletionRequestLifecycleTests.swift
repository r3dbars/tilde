import Testing
@testable import AutocompleteLabCore

@Suite("Completion request lifecycle")
struct CompletionRequestLifecycleTests {
    @Test("Issuing a request stores it and allows its ticket")
    func issuingRequestAllowsTicket() {
        var lifecycle = CompletionRequestLifecycle()
        let request = CompletionRequest(
            textBeforeCursor: "Can we",
            suggestionID: "suggestion-a"
        )

        let ticket = lifecycle.issue(request)

        #expect(lifecycle.currentRequest == request)
        #expect(lifecycle.allows(ticket))
    }

    @Test("Newer request blocks older tickets")
    func newerRequestBlocksOlderTickets() {
        var lifecycle = CompletionRequestLifecycle()
        let firstRequest = CompletionRequest(
            textBeforeCursor: "Can we",
            suggestionID: "suggestion-a"
        )
        let firstTicket = lifecycle.issue(firstRequest)
        let secondRequest = CompletionRequest(
            textBeforeCursor: "Can we make",
            suggestionID: "suggestion-b"
        )

        let secondTicket = lifecycle.issue(secondRequest)

        #expect(!lifecycle.allows(firstTicket))
        #expect(lifecycle.allows(secondTicket))
    }

    @Test("Streaming state can be stored and cleared per suggestion")
    func streamingStateCanBeStoredAndCleared() {
        var lifecycle = CompletionRequestLifecycle()
        let request = CompletionRequest(
            textBeforeCursor: "Can we",
            suggestionID: "suggestion-a"
        )
        _ = lifecycle.issue(request)

        lifecycle.setStreamingState(
            StreamingPresentationState(
                presentedCount: 1,
                lastVisibleText: "make this",
                lastPresentedAtMilliseconds: 25
            ),
            for: request.suggestionID
        )

        #expect(
            lifecycle.streamingState(for: request.suggestionID)
                == StreamingPresentationState(
                    presentedCount: 1,
                    lastVisibleText: "make this",
                    lastPresentedAtMilliseconds: 25
                )
        )

        lifecycle.clearStreamingState(for: request.suggestionID)

        #expect(lifecycle.streamingState(for: request.suggestionID) == StreamingPresentationState())
    }

    @Test("Invalidation clears request, streaming state, and stale tickets")
    func invalidationClearsLifecycleState() {
        var lifecycle = CompletionRequestLifecycle()
        let request = CompletionRequest(
            textBeforeCursor: "Can we",
            suggestionID: "suggestion-a"
        )
        let ticket = lifecycle.issue(request)
        lifecycle.setStreamingState(
            StreamingPresentationState(presentedCount: 1),
            for: request.suggestionID
        )

        lifecycle.invalidate()

        #expect(lifecycle.currentRequest == nil)
        #expect(lifecycle.streamingState(for: request.suggestionID) == StreamingPresentationState())
        #expect(!lifecycle.allows(ticket))
    }
}
