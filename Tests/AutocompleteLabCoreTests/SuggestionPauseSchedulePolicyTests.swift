import Foundation
import Testing
@testable import AutocompleteLabCore

@Suite("Suggestion pause schedule policy")
struct SuggestionPauseSchedulePolicyTests {
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
}
