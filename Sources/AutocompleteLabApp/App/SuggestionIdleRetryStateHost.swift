import AutocompleteLabCore

/// Owns mutable idle-retry state while the core type owns retry behavior.
@MainActor
final class SuggestionIdleRetryStateHost {
    private var state: SuggestionIdleRetryState

    init(settleDelayMilliseconds: Int = 240) {
        state = SuggestionIdleRetryState(settleDelayMilliseconds: settleDelayMilliseconds)
    }

    var hasPendingRetry: Bool {
        state.hasPendingRetry
    }

    func noteTextChange(
        snapshot: FocusedTextSnapshot,
        cancelledPendingRequest: Bool,
        nowMilliseconds: Int,
        settleDelayMilliseconds: Int? = nil
    ) {
        state.noteTextChange(
            snapshot: snapshot,
            cancelledPendingRequest: cancelledPendingRequest,
            nowMilliseconds: nowMilliseconds,
            settleDelayMilliseconds: settleDelayMilliseconds
        )
    }

    func noteTypingBurstSuppression(
        snapshot: FocusedTextSnapshot,
        nowMilliseconds: Int,
        settleDelayMilliseconds: Int? = nil
    ) {
        state.noteTypingBurstSuppression(
            snapshot: snapshot,
            nowMilliseconds: nowMilliseconds,
            settleDelayMilliseconds: settleDelayMilliseconds
        )
    }

    func cancel() {
        state.cancel()
    }

    func consumeRetryIfReady(
        snapshot: FocusedTextSnapshot,
        nowMilliseconds: Int,
        hasVisibleSuggestion: Bool
    ) -> SuggestionIdleRetryReason? {
        state.consumeRetryIfReady(
            snapshot: snapshot,
            nowMilliseconds: nowMilliseconds,
            hasVisibleSuggestion: hasVisibleSuggestion
        )
    }
}
