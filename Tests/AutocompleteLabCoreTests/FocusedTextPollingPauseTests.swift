import Foundation
import Testing
@testable import AutocompleteLabCore

@Suite("Focused text polling pause")
struct FocusedTextPollingPauseTests {
    @Test("Starts unpaused")
    func startsUnpaused() {
        var pause = FocusedTextPollingPause()
        let isPaused = pause.isPaused(now: Date(timeIntervalSince1970: 100))

        #expect(!isPaused)
        #expect(pause.pausedUntil == nil)
    }

    @Test("Pause is active before the deadline")
    func pauseIsActiveBeforeDeadline() throws {
        let now = Date(timeIntervalSince1970: 100)
        var pause = FocusedTextPollingPause()

        pause.pause(now: now, durationMilliseconds: 200)
        let isPaused = pause.isPaused(now: now.addingTimeInterval(0.1))

        #expect(isPaused)
        #expect(try isSameTime(#require(pause.pausedUntil), now.addingTimeInterval(0.2)))
    }

    @Test("Expired pause clears itself")
    func expiredPauseClearsItself() {
        let now = Date(timeIntervalSince1970: 100)
        var pause = FocusedTextPollingPause()

        pause.pause(now: now, durationMilliseconds: 120)
        let isPaused = pause.isPaused(now: now.addingTimeInterval(0.2))

        #expect(!isPaused)
        #expect(pause.pausedUntil == nil)
    }

    @Test("Second pause replaces the deadline")
    func secondPauseReplacesDeadline() throws {
        let now = Date(timeIntervalSince1970: 100)
        var pause = FocusedTextPollingPause()

        pause.pause(now: now, durationMilliseconds: 120)
        pause.pause(now: now.addingTimeInterval(0.05), durationMilliseconds: 300)

        #expect(try isSameTime(#require(pause.pausedUntil), now.addingTimeInterval(0.35)))
    }

    private func isSameTime(_ lhs: Date, _ rhs: Date) -> Bool {
        abs(lhs.timeIntervalSince(rhs)) < 0.000_001
    }
}
