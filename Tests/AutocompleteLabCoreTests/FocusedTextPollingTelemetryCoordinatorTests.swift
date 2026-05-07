import Foundation
import Testing
@testable import AutocompleteLabCore

struct FocusedTextPollingTelemetryCoordinatorTests {
    @Test("Slow latency records summary and hides visible suggestions")
    func slowLatencyRecordsSummaryAndHidesVisibleSuggestions() {
        var coordinator = FocusedTextPollingTelemetryCoordinator(
            latencyStats: FocusedTextPollLatencyStats(sampleWindow: 1),
            backoffPolicy: FocusedTextPollingBackoffPolicy(slowPollP95Milliseconds: 80),
            slowLatencyMilliseconds: 80
        )

        let now = Date(timeIntervalSince1970: 100)
        let update = coordinator.recordLatency(
            120,
            now: now,
            hasVisibleSuggestion: true
        )

        #expect(update.slowLatencyMilliseconds == 120)
        #expect(update.latencySummary?.p95Milliseconds == 120)
        #expect(update.throttle?.reason == .slowPollLatency)
        #expect(update.throttle?.pauseMilliseconds == 240)
        #expect(update.throttle?.shouldHideVisibleSuggestion == true)
        let isPaused = coordinator.isPaused(now: now.addingTimeInterval(0.1))
        #expect(isPaused)
    }

    @Test("Overlapping poll throttle keeps a visible suggestion")
    func overlappingPollThrottleKeepsVisibleSuggestion() {
        var coordinator = FocusedTextPollingTelemetryCoordinator(
            backoffPolicy: FocusedTextPollingBackoffPolicy(overlappingPollCount: 2)
        )

        let now = Date(timeIntervalSince1970: 100)
        _ = coordinator.recordSkippedInFlight(now: now)
        _ = coordinator.recordSkippedInFlight(now: now.addingTimeInterval(0.05))

        let update = coordinator.drainSkipSummary(
            now: now.addingTimeInterval(0.1),
            hasVisibleSuggestion: true
        )

        #expect(update?.skipSummary?.count == 2)
        #expect(update?.throttle?.reason == .overlappingPolls)
        #expect(update?.throttle?.shouldHideVisibleSuggestion == false)
        let isPaused = coordinator.isPaused(now: now.addingTimeInterval(0.2))
        #expect(isPaused)
    }

    @Test("Manual pause clears after its deadline")
    func manualPauseClearsAfterDeadline() {
        var coordinator = FocusedTextPollingTelemetryCoordinator()
        let now = Date(timeIntervalSince1970: 100)

        coordinator.pause(now: now, durationMilliseconds: 100)

        let isPausedBeforeDeadline = coordinator.isPaused(now: now.addingTimeInterval(0.05))
        let isPausedAfterDeadline = coordinator.isPaused(now: now.addingTimeInterval(0.2))

        #expect(isPausedBeforeDeadline)
        #expect(!isPausedAfterDeadline)
    }
}
