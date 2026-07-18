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

    @Test("forwards typing-burst suppression and cancellation through the host")
    func forwardsTypingBurstSuppressionAndCancellation() {
        let host = SuggestionIdleRetryStateHost(settleDelayMilliseconds: 200)
        let first = snapshot("Burst a")
        let final = snapshot("Burst abc")

        host.noteTextChange(
            snapshot: first,
            cancelledPendingRequest: true,
            nowMilliseconds: 0
        )
        host.noteTypingBurstSuppression(snapshot: final, nowMilliseconds: 100)

        #expect(host.hasPendingRetry)
        #expect(host.consumeRetryIfReady(
            snapshot: final,
            nowMilliseconds: 299,
            hasVisibleSuggestion: false
        ) == nil)
        #expect(host.consumeRetryIfReady(
            snapshot: final,
            nowMilliseconds: 300,
            hasVisibleSuggestion: false
        ) == .typingBurstSuppressed)

        host.noteTextChange(
            snapshot: snapshot("Again"),
            cancelledPendingRequest: true,
            nowMilliseconds: 400
        )
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
