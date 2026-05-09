import Foundation

public struct SuggestionPauseScheduleState: Equatable, Sendable {
    public let isPaused: Bool
    public let pausedUntil: Date?

    public init(isPaused: Bool, pausedUntil: Date?) {
        self.isPaused = isPaused
        self.pausedUntil = isPaused ? pausedUntil : nil
    }
}

public struct SuggestionPauseSchedulePolicy: Equatable, Sendable {
    public init() {}

    public func normalizedState(
        isPaused: Bool,
        pausedUntil: Date?,
        now: Date
    ) -> SuggestionPauseScheduleState {
        guard isPaused else {
            return SuggestionPauseScheduleState(isPaused: false, pausedUntil: nil)
        }

        guard let pausedUntil else {
            return SuggestionPauseScheduleState(isPaused: true, pausedUntil: nil)
        }

        guard pausedUntil > now else {
            return SuggestionPauseScheduleState(isPaused: false, pausedUntil: nil)
        }

        return SuggestionPauseScheduleState(isPaused: true, pausedUntil: pausedUntil)
    }

    public func timedPause(now: Date, durationSeconds: TimeInterval) -> SuggestionPauseScheduleState {
        SuggestionPauseScheduleState(
            isPaused: true,
            pausedUntil: now.addingTimeInterval(max(1, durationSeconds))
        )
    }

    public func pauseUntilTomorrow(
        now: Date,
        calendar: Calendar = .current
    ) -> SuggestionPauseScheduleState {
        let startOfToday = calendar.startOfDay(for: now)
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday)
            ?? now.addingTimeInterval(24 * 60 * 60)
        return SuggestionPauseScheduleState(isPaused: true, pausedUntil: startOfTomorrow)
    }
}
