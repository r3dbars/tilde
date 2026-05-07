import Foundation

public struct FocusedTextPollSkipStats: Equatable, Sendable {
    private var skippedInFlightCount: Int
    private var firstSkippedAt: Date?

    public init(skippedInFlightCount: Int = 0, firstSkippedAt: Date? = nil) {
        self.skippedInFlightCount = max(0, skippedInFlightCount)
        self.firstSkippedAt = firstSkippedAt
    }

    public mutating func recordSkippedInFlight(now: Date) -> FocusedTextPollSkipNotice? {
        skippedInFlightCount += 1
        if firstSkippedAt == nil {
            firstSkippedAt = now
        }

        guard skippedInFlightCount == 1 else {
            return nil
        }

        return FocusedTextPollSkipNotice(count: skippedInFlightCount)
    }

    public mutating func drain(now: Date) -> FocusedTextPollSkipSummary? {
        guard skippedInFlightCount > 0 else {
            return nil
        }

        let startedAt = firstSkippedAt ?? now
        let durationMilliseconds = max(0, Int((now.timeIntervalSince(startedAt) * 1000).rounded()))
        let summary = FocusedTextPollSkipSummary(
            count: skippedInFlightCount,
            durationMilliseconds: durationMilliseconds
        )
        skippedInFlightCount = 0
        firstSkippedAt = nil
        return summary
    }
}

public struct FocusedTextPollSkipNotice: Equatable, Sendable {
    public let count: Int

    public init(count: Int) {
        self.count = max(0, count)
    }
}

public struct FocusedTextPollSkipSummary: Equatable, Sendable {
    public let count: Int
    public let durationMilliseconds: Int

    public init(count: Int, durationMilliseconds: Int) {
        self.count = max(0, count)
        self.durationMilliseconds = max(0, durationMilliseconds)
    }
}
