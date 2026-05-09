import Testing
@testable import AutocompleteLabCore

@Suite("Focused text poll latency stats")
struct FocusedTextPollLatencyStatsTests {
    @Test("Emits a summary when the sample window fills")
    func emitsSummaryWhenSampleWindowFills() {
        var stats = FocusedTextPollLatencyStats(sampleWindow: 5)

        #expect(stats.record(1) == nil)
        #expect(stats.record(2) == nil)
        #expect(stats.record(50) == nil)
        #expect(stats.record(4) == nil)

        let summary = stats.record(5)

        #expect(summary?.count == 5)
        #expect(summary?.p50Milliseconds == 4)
        #expect(summary?.p90Milliseconds == 50)
        #expect(summary?.p95Milliseconds == 50)
        #expect(summary?.p99Milliseconds == 50)
        #expect(summary?.maxMilliseconds == 50)
    }

    @Test("Draining resets the sample window")
    func drainResetsSampleWindow() {
        var stats = FocusedTextPollLatencyStats(sampleWindow: 2)

        #expect(stats.record(10) == nil)
        #expect(stats.drain()?.count == 1)
        #expect(stats.drain() == nil)
        #expect(stats.record(20) == nil)
        #expect(stats.record(30)?.count == 2)
    }

    @Test("Negative durations are clamped")
    func negativeDurationsAreClamped() {
        var stats = FocusedTextPollLatencyStats(sampleWindow: 1)

        let summary = stats.record(-10)

        #expect(summary?.p50Milliseconds == 0)
        #expect(summary?.p90Milliseconds == 0)
        #expect(summary?.p95Milliseconds == 0)
        #expect(summary?.p99Milliseconds == 0)
        #expect(summary?.maxMilliseconds == 0)
    }

    @Test("Diagnostics markers wait for the user-facing warning threshold")
    func diagnosticsMarkersWaitForUserFacingWarningThreshold() {
        let policy = FocusedTextPollDiagnosticsPolicy(
            slowPollMarkerMilliseconds: 120,
            slowAXReadMarkerMilliseconds: 120
        )

        #expect(!policy.shouldRecordSlowPollMarker(durationMilliseconds: 87))
        #expect(policy.shouldRecordSlowPollMarker(durationMilliseconds: 120))
        #expect(!policy.shouldRecordSlowAXReadMarker(queueDelayMilliseconds: 0, readDurationMilliseconds: 95))
        #expect(policy.shouldRecordSlowAXReadMarker(queueDelayMilliseconds: 121, readDurationMilliseconds: 40))
    }
}
