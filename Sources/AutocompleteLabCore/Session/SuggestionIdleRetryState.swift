public enum SuggestionIdleRetryReason: String, Equatable, Sendable {
    case requestCancelled = "request-cancelled"
}

public struct SuggestionIdleRetryState: Equatable, Sendable {
    private struct PendingRetry: Equatable, Sendable {
        let snapshot: FocusedTextSnapshot
        let reason: SuggestionIdleRetryReason
        let retryAtMilliseconds: Int
    }

    public let settleDelayMilliseconds: Int
    private var pendingRetry: PendingRetry?

    public init(settleDelayMilliseconds: Int = 240) {
        self.settleDelayMilliseconds = max(1, settleDelayMilliseconds)
    }

    public var hasPendingRetry: Bool {
        pendingRetry != nil
    }

    public mutating func noteTextChange(
        snapshot: FocusedTextSnapshot,
        cancelledPendingRequest: Bool,
        nowMilliseconds: Int,
        settleDelayMilliseconds: Int? = nil
    ) {
        let reason: SuggestionIdleRetryReason?
        if cancelledPendingRequest {
            reason = .requestCancelled
        } else {
            reason = pendingRetry?.reason
        }

        guard let reason else {
            return
        }

        arm(
            snapshot: snapshot,
            reason: reason,
            nowMilliseconds: nowMilliseconds,
            settleDelayMilliseconds: settleDelayMilliseconds
        )
    }

    public mutating func cancel() {
        pendingRetry = nil
    }

    public mutating func consumeRetryIfReady(
        snapshot: FocusedTextSnapshot,
        nowMilliseconds: Int,
        hasVisibleSuggestion: Bool
    ) -> SuggestionIdleRetryReason? {
        guard let pendingRetry else {
            return nil
        }

        guard !hasVisibleSuggestion,
              pendingRetry.snapshot == snapshot else {
            self.pendingRetry = nil
            return nil
        }

        guard nowMilliseconds >= pendingRetry.retryAtMilliseconds else {
            return nil
        }

        self.pendingRetry = nil
        return pendingRetry.reason
    }

    private mutating func arm(
        snapshot: FocusedTextSnapshot,
        reason: SuggestionIdleRetryReason,
        nowMilliseconds: Int,
        settleDelayMilliseconds: Int?
    ) {
        let delayMilliseconds = max(
            1,
            settleDelayMilliseconds ?? self.settleDelayMilliseconds
        )
        pendingRetry = PendingRetry(
            snapshot: snapshot,
            reason: reason,
            retryAtMilliseconds: nowMilliseconds + delayMilliseconds
        )
    }
}
