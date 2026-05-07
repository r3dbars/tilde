import Foundation

public struct FocusedTextPollingPause: Equatable, Sendable {
    public private(set) var pausedUntil: Date?
    public private(set) var repeatedPauseCount: Int
    private var lastPauseAt: Date?

    public init(pausedUntil: Date? = nil, repeatedPauseCount: Int = 0) {
        self.pausedUntil = pausedUntil
        self.repeatedPauseCount = max(0, repeatedPauseCount)
        self.lastPauseAt = nil
    }

    public mutating func pause(
        now: Date,
        durationMilliseconds: Int,
        policy: FocusedTextPollingBackoffPolicy = .typingBackoff
    ) {
        guard durationMilliseconds > 0 else {
            clear()
            return
        }

        if policy.isRepeatedPause(previousPauseAt: lastPauseAt, pausedUntil: pausedUntil, now: now) {
            repeatedPauseCount += 1
        } else {
            repeatedPauseCount = 1
        }
        lastPauseAt = now

        let effectiveDurationMilliseconds = policy.pauseDurationMilliseconds(
            baseDurationMilliseconds: durationMilliseconds,
            repeatedPauseCount: repeatedPauseCount
        )
        pausedUntil = now.addingTimeInterval(TimeInterval(effectiveDurationMilliseconds) / 1000)
    }

    public mutating func isPaused(now: Date) -> Bool {
        guard let pausedUntil else {
            return false
        }

        if pausedUntil > now {
            return true
        }

        clear()
        return false
    }

    private mutating func clear() {
        pausedUntil = nil
        repeatedPauseCount = 0
        lastPauseAt = nil
    }
}
