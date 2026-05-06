import Foundation
import Testing
@testable import AutocompleteLabCore

@Suite("Focused text poll skip stats")
struct FocusedTextPollSkipStatsTests {
    @Test("First skipped poll emits a notice")
    func firstSkippedPollEmitsNotice() {
        let now = Date(timeIntervalSince1970: 100)
        var stats = FocusedTextPollSkipStats()

        #expect(stats.recordSkippedInFlight(now: now) == FocusedTextPollSkipNotice(count: 1))
        #expect(stats.recordSkippedInFlight(now: now.addingTimeInterval(0.05)) == nil)
    }

    @Test("Drain summarizes skipped poll streak and resets")
    func drainSummarizesSkippedPollStreakAndResets() {
        let now = Date(timeIntervalSince1970: 100)
        var stats = FocusedTextPollSkipStats()

        _ = stats.recordSkippedInFlight(now: now)
        _ = stats.recordSkippedInFlight(now: now.addingTimeInterval(0.05))

        #expect(stats.drain(now: now.addingTimeInterval(0.12)) == FocusedTextPollSkipSummary(
            count: 2,
            durationMilliseconds: 120
        ))
        #expect(stats.drain(now: now.addingTimeInterval(0.2)) == nil)
        #expect(stats.recordSkippedInFlight(now: now.addingTimeInterval(0.3)) == FocusedTextPollSkipNotice(count: 1))
    }

    @Test("Drain clamps negative elapsed duration")
    func drainClampsNegativeElapsedDuration() {
        let now = Date(timeIntervalSince1970: 100)
        var stats = FocusedTextPollSkipStats()

        _ = stats.recordSkippedInFlight(now: now)

        #expect(stats.drain(now: now.addingTimeInterval(-1)) == FocusedTextPollSkipSummary(
            count: 1,
            durationMilliseconds: 0
        ))
    }
}
