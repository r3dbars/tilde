import Foundation
import Testing
@testable import AutocompleteLabCore

@Suite("Suggestion pause schedule policy")
struct SuggestionPauseSchedulePolicyTests {
    @Test("Unpaused state drops stale expiry")
    func unpausedStateDropsStaleExpiry() {
        let policy = SuggestionPauseSchedulePolicy()
        let now = Date(timeIntervalSince1970: 1_000)

        let state = policy.normalizedState(
            isPaused: false,
            pausedUntil: now.addingTimeInterval(900),
            now: now
        )

        #expect(!state.isPaused)
        #expect(state.pausedUntil == nil)
    }

    @Test("Expired timed pause resumes suggestions")
    func expiredTimedPauseResumesSuggestions() {
        let policy = SuggestionPauseSchedulePolicy()
        let now = Date(timeIntervalSince1970: 1_000)

        let state = policy.normalizedState(
            isPaused: true,
            pausedUntil: now.addingTimeInterval(-1),
            now: now
        )

        #expect(!state.isPaused)
        #expect(state.pausedUntil == nil)
    }

    @Test("Indefinite pause stays paused")
    func indefinitePauseStaysPaused() {
        let policy = SuggestionPauseSchedulePolicy()
        let now = Date(timeIntervalSince1970: 1_000)

        let state = policy.normalizedState(
            isPaused: true,
            pausedUntil: nil,
            now: now
        )

        #expect(state.isPaused)
        #expect(state.pausedUntil == nil)
    }

    @Test("Timed pause creates a future expiry")
    func timedPauseCreatesFutureExpiry() throws {
        let policy = SuggestionPauseSchedulePolicy()
        let now = Date(timeIntervalSince1970: 1_000)

        let state = policy.timedPause(now: now, durationSeconds: 900)

        #expect(state.isPaused)
        #expect(try #require(state.pausedUntil) == now.addingTimeInterval(900))
    }

    @Test("Timed pause clamps nonpositive durations")
    func timedPauseClampsNonpositiveDurations() throws {
        let policy = SuggestionPauseSchedulePolicy()
        let now = Date(timeIntervalSince1970: 1_000)

        let state = policy.timedPause(now: now, durationSeconds: 0)

        #expect(state.isPaused)
        #expect(try #require(state.pausedUntil) == now.addingTimeInterval(1))
    }

    @Test("Pause until tomorrow expires at the next local day")
    func pauseUntilTomorrowExpiresAtNextLocalDay() throws {
        let policy = SuggestionPauseSchedulePolicy()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = try #require(calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2023,
            month: 12,
            day: 8,
            hour: 22,
            minute: 45
        )))
        let expected = try #require(calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2023,
            month: 12,
            day: 9,
            hour: 0,
            minute: 0
        )))

        let state = policy.pauseUntilTomorrow(now: now, calendar: calendar)

        #expect(state.isPaused)
        #expect(try #require(state.pausedUntil) == expected)
    }
}
