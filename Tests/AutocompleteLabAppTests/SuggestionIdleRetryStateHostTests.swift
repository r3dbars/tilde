@testable import AutocompleteLabApp
import AutocompleteLabCore
import Testing

@Suite("Suggestion idle retry state host")
@MainActor
struct SuggestionIdleRetryStateHostTests {
    @Test("retains a cancelled request until the settled snapshot is ready")
    func retainsCancelledRequestUntilSettledSnapshotIsReady() {
        let host = SuggestionIdleRetryStateHost(settleDelayMilliseconds: 100)
        let snapshot = snapshot("Hello")

        host.noteTextChange(
            snapshot: snapshot,
            cancelledPendingRequest: true,
            nowMilliseconds: 0
        )

        #expect(host.consumeRetryIfReady(
            snapshot: snapshot,
            nowMilliseconds: 99,
            hasVisibleSuggestion: false
        ) == nil)
        #expect(host.consumeRetryIfReady(
            snapshot: snapshot,
            nowMilliseconds: 100,
            hasVisibleSuggestion: false
        ) == .requestCancelled)
        #expect(!host.hasPendingRetry)
    }

    @Test("cancellation clears a pending retry")
    func cancellationClearsPendingRetry() {
        let host = SuggestionIdleRetryStateHost(settleDelayMilliseconds: 200)
        let first = snapshot("Burst a")

        host.noteTextChange(
            snapshot: first,
            cancelledPendingRequest: true,
            nowMilliseconds: 0
        )
        #expect(host.hasPendingRetry)
        host.cancel()
        #expect(!host.hasPendingRetry)
    }

    private func snapshot(_ textBeforeCursor: String) -> FocusedTextSnapshot {
        FocusedTextSnapshot(
            fieldIdentity: FocusedFieldIdentity(
                bundleIdentifier: "com.example.synthetic",
                processIdentifier: 42,
                elementIdentifier: 7
            ),
            textBeforeCursor: textBeforeCursor,
            textAfterCursor: ""
        )
    }
}
