import Foundation

public struct FocusedTextPollingTelemetryUpdate: Equatable, Sendable {
    public let slowLatencyMilliseconds: Int?
    public let latencySummary: FocusedTextPollLatencySummary?
    public let skipSummary: FocusedTextPollSkipSummary?
    public let throttle: FocusedTextPollingThrottleEffect?

    public init(
        slowLatencyMilliseconds: Int? = nil,
        latencySummary: FocusedTextPollLatencySummary? = nil,
        skipSummary: FocusedTextPollSkipSummary? = nil,
        throttle: FocusedTextPollingThrottleEffect? = nil
    ) {
        self.slowLatencyMilliseconds = slowLatencyMilliseconds
        self.latencySummary = latencySummary
        self.skipSummary = skipSummary
        self.throttle = throttle
    }
}

public struct FocusedTextPollingThrottleEffect: Equatable, Sendable {
    public let reason: FocusedTextPollingThrottleReason
    public let pauseMilliseconds: Int
    public let shouldHideVisibleSuggestion: Bool

    public init(
        reason: FocusedTextPollingThrottleReason,
        pauseMilliseconds: Int,
        shouldHideVisibleSuggestion: Bool
    ) {
        self.reason = reason
        self.pauseMilliseconds = max(0, pauseMilliseconds)
        self.shouldHideVisibleSuggestion = shouldHideVisibleSuggestion
    }
}

public struct FocusedTextPollingTelemetryCoordinator: Equatable, Sendable {
    private var latencyStats: FocusedTextPollLatencyStats
    private var skipStats: FocusedTextPollSkipStats
    private var pauseState: FocusedTextPollingPause
    private let backoffPolicy: FocusedTextPollingBackoffPolicy
    private let visibilityPolicy: FocusedTextPollingThrottleVisibilityPolicy
    private let slowLatencyMilliseconds: Int

    public init(
        latencyStats: FocusedTextPollLatencyStats = FocusedTextPollLatencyStats(),
        skipStats: FocusedTextPollSkipStats = FocusedTextPollSkipStats(),
        pauseState: FocusedTextPollingPause = FocusedTextPollingPause(),
        backoffPolicy: FocusedTextPollingBackoffPolicy = .typingBackoff,
        visibilityPolicy: FocusedTextPollingThrottleVisibilityPolicy = FocusedTextPollingThrottleVisibilityPolicy(),
        slowLatencyMilliseconds: Int = 80
    ) {
        self.latencyStats = latencyStats
        self.skipStats = skipStats
        self.pauseState = pauseState
        self.backoffPolicy = backoffPolicy
        self.visibilityPolicy = visibilityPolicy
        self.slowLatencyMilliseconds = max(0, slowLatencyMilliseconds)
    }

    public mutating func isPaused(now: Date) -> Bool {
        pauseState.isPaused(now: now)
    }

    public mutating func pause(now: Date, durationMilliseconds: Int) {
        pauseState.pause(
            now: now,
            durationMilliseconds: durationMilliseconds,
            policy: backoffPolicy
        )
    }

    public mutating func recordSkippedInFlight(now: Date) -> FocusedTextPollSkipNotice? {
        skipStats.recordSkippedInFlight(now: now)
    }

    public mutating func recordLatency(
        _ durationMilliseconds: Int,
        now: Date,
        hasVisibleSuggestion: Bool
    ) -> FocusedTextPollingTelemetryUpdate {
        let clampedDurationMilliseconds = max(0, durationMilliseconds)
        let summary = latencyStats.record(clampedDurationMilliseconds)
        let throttle = throttleEffect(
            backoffPolicy.throttleRecommendation(
                latencySummary: summary,
                skipSummary: nil
            ),
            now: now,
            hasVisibleSuggestion: hasVisibleSuggestion
        )

        return FocusedTextPollingTelemetryUpdate(
            slowLatencyMilliseconds: clampedDurationMilliseconds >= slowLatencyMilliseconds
                ? clampedDurationMilliseconds
                : nil,
            latencySummary: summary,
            throttle: throttle
        )
    }

    public mutating func drainSkipSummary(
        now: Date,
        hasVisibleSuggestion: Bool
    ) -> FocusedTextPollingTelemetryUpdate? {
        guard let summary = skipStats.drain(now: now) else {
            return nil
        }

        let throttle = throttleEffect(
            backoffPolicy.throttleRecommendation(
                latencySummary: nil,
                skipSummary: summary
            ),
            now: now,
            hasVisibleSuggestion: hasVisibleSuggestion
        )

        return FocusedTextPollingTelemetryUpdate(
            skipSummary: summary,
            throttle: throttle
        )
    }

    private mutating func throttleEffect(
        _ recommendation: FocusedTextPollingThrottleRecommendation,
        now: Date,
        hasVisibleSuggestion: Bool
    ) -> FocusedTextPollingThrottleEffect? {
        guard recommendation.shouldThrottle,
              let reason = recommendation.reason,
              recommendation.pauseMilliseconds > 0 else {
            return nil
        }

        pauseState.pause(
            now: now,
            durationMilliseconds: recommendation.pauseMilliseconds,
            policy: backoffPolicy
        )

        return FocusedTextPollingThrottleEffect(
            reason: reason,
            pauseMilliseconds: recommendation.pauseMilliseconds,
            shouldHideVisibleSuggestion: hasVisibleSuggestion
                && visibilityPolicy.shouldHideVisibleSuggestion(for: reason)
        )
    }
}
