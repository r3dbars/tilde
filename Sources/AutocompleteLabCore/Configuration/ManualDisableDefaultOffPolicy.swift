import Foundation

public struct ManualDisableDefaultOffPolicy: Equatable, Sendable {
    public let windowDays: Int
    public let disableThreshold: Int

    public init(windowDays: Int = 7, disableThreshold: Int = 2) {
        self.windowDays = windowDays
        self.disableThreshold = disableThreshold
    }

    public func history(
        afterAddingManualDisableTo existingHistory: [Date],
        now: Date = Date()
    ) -> [Date] {
        recentHistory(from: existingHistory + [now], now: now)
    }

    public func shouldMarkDefaultOff(
        history: [Date],
        now: Date = Date()
    ) -> Bool {
        recentHistory(from: history, now: now).count >= disableThreshold
    }

    public func recentHistory(
        from history: [Date],
        now: Date = Date()
    ) -> [Date] {
        guard windowDays > 0 else {
            return history.sorted()
        }

        let cutoff = now.addingTimeInterval(-Double(windowDays) * 24 * 60 * 60)
        return history
            .filter { $0 >= cutoff && $0 <= now }
            .sorted()
    }
}
