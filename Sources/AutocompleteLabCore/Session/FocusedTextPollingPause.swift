import Foundation

public struct FocusedTextPollingPause: Equatable, Sendable {
    public private(set) var pausedUntil: Date?

    public init(pausedUntil: Date? = nil) {
        self.pausedUntil = pausedUntil
    }

    public mutating func pause(now: Date, durationMilliseconds: Int) {
        guard durationMilliseconds > 0 else {
            pausedUntil = nil
            return
        }

        pausedUntil = now.addingTimeInterval(TimeInterval(durationMilliseconds) / 1000)
    }

    public mutating func isPaused(now: Date) -> Bool {
        guard let pausedUntil else {
            return false
        }

        if pausedUntil > now {
            return true
        }

        self.pausedUntil = nil
        return false
    }
}
