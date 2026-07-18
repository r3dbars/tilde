@testable import AutocompleteLabApp
import AutocompleteLabCore
import Foundation
import Testing

@Suite("Suggestion pause state host")
@MainActor
struct SuggestionPauseStateHostTests {
    @Test("loads a fresh install as running")
    func loadsFreshInstallAsRunning() {
        let suiteName = "SuggestionPauseStateHostTests.fresh"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let host = SuggestionPauseStateHost(defaults: defaults)

        host.load(now: Date(timeIntervalSince1970: 1_000))

        #expect(!host.isPaused)
        #expect(host.pausedUntil == nil)
        #expect(host.controlState == .running)
    }

    @Test("normalizes an expired timed pause and reports the transition")
    func normalizesExpiredTimedPauseAndReportsTransition() {
        let suiteName = "SuggestionPauseStateHostTests.expired"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        var didReportEnd = false
        let host = SuggestionPauseStateHost(
            defaults: defaults,
            onTimedPauseEnded: { didReportEnd = true }
        )
        host.applyScheduledPause(
            SuggestionPauseScheduleState(
                isPaused: true,
                pausedUntil: Date(timeIntervalSince1970: 1_010)
            )
        )

        host.expireTimedPauseIfNeeded(now: Date(timeIntervalSince1970: 1_011))

        #expect(!host.isPaused)
        #expect(host.pausedUntil == nil)
        #expect(didReportEnd)
    }
}
