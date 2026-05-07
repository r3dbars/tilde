import Foundation

public enum FocusedTextPollingThrottleReason: String, Equatable, Sendable {
    case slowPollLatency = "slow-poll-latency"
    case overlappingPolls = "overlapping-polls"
}

public struct FocusedTextPollingThrottleRecommendation: Equatable, Sendable {
    public let shouldThrottle: Bool
    public let reason: FocusedTextPollingThrottleReason?
    public let pauseMilliseconds: Int

    public init(
        shouldThrottle: Bool,
        reason: FocusedTextPollingThrottleReason?,
        pauseMilliseconds: Int
    ) {
        self.shouldThrottle = shouldThrottle
        self.reason = reason
        self.pauseMilliseconds = max(0, pauseMilliseconds)
    }

    public static let none = FocusedTextPollingThrottleRecommendation(
        shouldThrottle: false,
        reason: nil,
        pauseMilliseconds: 0
    )
}

public struct FocusedTextPollingThrottleVisibilityPolicy: Equatable, Sendable {
    public init() {}

    public func shouldHideVisibleSuggestion(for reason: FocusedTextPollingThrottleReason) -> Bool {
        switch reason {
        case .slowPollLatency:
            true
        case .overlappingPolls:
            false
        }
    }
}

public struct FocusedTextPollingBackoffPolicy: Equatable, Sendable {
    public static let typingBackoff = FocusedTextPollingBackoffPolicy()

    public let repeatPauseWindowMilliseconds: Int
    public let repeatPauseStepMilliseconds: Int
    public let maxPauseDurationMilliseconds: Int
    public let staleSnapshotMilliseconds: Int
    public let slowPollP95Milliseconds: Int
    public let overlappingPollCount: Int
    public let minimumThrottleMilliseconds: Int

    public init(
        repeatPauseWindowMilliseconds: Int = 350,
        repeatPauseStepMilliseconds: Int = 40,
        maxPauseDurationMilliseconds: Int = 360,
        staleSnapshotMilliseconds: Int = 450,
        slowPollP95Milliseconds: Int = 80,
        overlappingPollCount: Int = 2,
        minimumThrottleMilliseconds: Int = 120
    ) {
        self.repeatPauseWindowMilliseconds = max(0, repeatPauseWindowMilliseconds)
        self.repeatPauseStepMilliseconds = max(0, repeatPauseStepMilliseconds)
        self.maxPauseDurationMilliseconds = max(0, maxPauseDurationMilliseconds)
        self.staleSnapshotMilliseconds = max(0, staleSnapshotMilliseconds)
        self.slowPollP95Milliseconds = max(0, slowPollP95Milliseconds)
        self.overlappingPollCount = max(1, overlappingPollCount)
        self.minimumThrottleMilliseconds = max(0, minimumThrottleMilliseconds)
    }

    public func pauseDurationMilliseconds(
        baseDurationMilliseconds: Int,
        repeatedPauseCount: Int
    ) -> Int {
        let baseDurationMilliseconds = max(0, baseDurationMilliseconds)
        guard baseDurationMilliseconds > 0 else {
            return 0
        }

        let repeatedPauseCount = max(1, repeatedPauseCount)
        let backedOffDuration = baseDurationMilliseconds + ((repeatedPauseCount - 1) * repeatPauseStepMilliseconds)
        return min(maxPauseDurationMilliseconds, backedOffDuration)
    }

    public func isRepeatedPause(previousPauseAt: Date?, pausedUntil: Date?, now: Date) -> Bool {
        if let pausedUntil, pausedUntil > now {
            return true
        }

        guard let previousPauseAt else {
            return false
        }

        let elapsedMilliseconds = Int((now.timeIntervalSince(previousPauseAt) * 1000).rounded())
        return elapsedMilliseconds >= 0 && elapsedMilliseconds <= repeatPauseWindowMilliseconds
    }

    public func snapshotAgeMilliseconds(lastObservedAt: Date?, now: Date) -> Int? {
        guard let lastObservedAt else {
            return nil
        }

        return max(0, Int((now.timeIntervalSince(lastObservedAt) * 1000).rounded()))
    }

    public func isSnapshotStale(lastObservedAt: Date?, now: Date) -> Bool {
        guard let ageMilliseconds = snapshotAgeMilliseconds(lastObservedAt: lastObservedAt, now: now) else {
            return false
        }

        return ageMilliseconds >= staleSnapshotMilliseconds
    }

    public func throttleRecommendation(
        latencySummary: FocusedTextPollLatencySummary?,
        skipSummary: FocusedTextPollSkipSummary?
    ) -> FocusedTextPollingThrottleRecommendation {
        let slowLatencyPause = latencySummary.flatMap { summary -> Int? in
            guard summary.p95Milliseconds >= slowPollP95Milliseconds else {
                return nil
            }

            return min(
                maxPauseDurationMilliseconds,
                max(minimumThrottleMilliseconds, summary.p95Milliseconds * 2)
            )
        }

        let overlappingPollsPause = skipSummary.flatMap { summary -> Int? in
            guard summary.count >= overlappingPollCount else {
                return nil
            }

            let extraSkips = max(0, summary.count - overlappingPollCount)
            return min(
                maxPauseDurationMilliseconds,
                minimumThrottleMilliseconds + (extraSkips * repeatPauseStepMilliseconds)
            )
        }

        switch (slowLatencyPause, overlappingPollsPause) {
        case let (slowLatencyPause?, overlappingPollsPause?):
            if overlappingPollsPause >= slowLatencyPause {
                return recommendation(reason: .overlappingPolls, pauseMilliseconds: overlappingPollsPause)
            }

            return recommendation(reason: .slowPollLatency, pauseMilliseconds: slowLatencyPause)
        case let (slowLatencyPause?, nil):
            return recommendation(reason: .slowPollLatency, pauseMilliseconds: slowLatencyPause)
        case let (nil, overlappingPollsPause?):
            return recommendation(reason: .overlappingPolls, pauseMilliseconds: overlappingPollsPause)
        case (nil, nil):
            return .none
        }
    }

    private func recommendation(
        reason: FocusedTextPollingThrottleReason,
        pauseMilliseconds: Int
    ) -> FocusedTextPollingThrottleRecommendation {
        FocusedTextPollingThrottleRecommendation(
            shouldThrottle: true,
            reason: reason,
            pauseMilliseconds: pauseMilliseconds
        )
    }
}
