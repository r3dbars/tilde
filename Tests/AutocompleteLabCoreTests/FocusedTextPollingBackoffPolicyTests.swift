import Foundation
import Testing
@testable import AutocompleteLabCore

@Suite("Focused text polling backoff policy")
struct FocusedTextPollingBackoffPolicyTests {
    @Test("Repeated pauses grow but clamp")
    func repeatedPausesGrowButClamp() {
        let policy = FocusedTextPollingBackoffPolicy(
            repeatPauseStepMilliseconds: 50,
            maxPauseDurationMilliseconds: 220
        )

        #expect(policy.pauseDurationMilliseconds(baseDurationMilliseconds: 120, repeatedPauseCount: 1) == 120)
        #expect(policy.pauseDurationMilliseconds(baseDurationMilliseconds: 120, repeatedPauseCount: 2) == 170)
        #expect(policy.pauseDurationMilliseconds(baseDurationMilliseconds: 120, repeatedPauseCount: 5) == 220)
    }

    @Test("Repeated pause window keeps active typing together")
    func repeatedPauseWindowKeepsActiveTypingTogether() {
        let now = Date(timeIntervalSince1970: 100)
        let policy = FocusedTextPollingBackoffPolicy(repeatPauseWindowMilliseconds: 300)

        #expect(policy.isRepeatedPause(
            previousPauseAt: now,
            pausedUntil: nil,
            now: now.addingTimeInterval(0.25)
        ))
        #expect(!policy.isRepeatedPause(
            previousPauseAt: now,
            pausedUntil: nil,
            now: now.addingTimeInterval(0.4)
        ))
    }

    @Test("Active pause is always repeated")
    func activePauseIsAlwaysRepeated() {
        let now = Date(timeIntervalSince1970: 100)
        let policy = FocusedTextPollingBackoffPolicy(repeatPauseWindowMilliseconds: 0)

        #expect(policy.isRepeatedPause(
            previousPauseAt: nil,
            pausedUntil: now.addingTimeInterval(0.1),
            now: now
        ))
    }

    @Test("Stale snapshot detection clamps negative age")
    func staleSnapshotDetectionClampsNegativeAge() {
        let now = Date(timeIntervalSince1970: 100)
        let policy = FocusedTextPollingBackoffPolicy(staleSnapshotMilliseconds: 450)

        #expect(policy.snapshotAgeMilliseconds(lastObservedAt: nil, now: now) == nil)
        #expect(policy.snapshotAgeMilliseconds(lastObservedAt: now.addingTimeInterval(1), now: now) == 0)
        #expect(!policy.isSnapshotStale(lastObservedAt: now.addingTimeInterval(-0.4), now: now))
        #expect(policy.isSnapshotStale(lastObservedAt: now.addingTimeInterval(-0.45), now: now))
    }

    @Test("In-flight skip waits for the grace window")
    func inFlightSkipWaitsForGraceWindow() {
        let now = Date(timeIntervalSince1970: 100)
        let policy = FocusedTextPollingBackoffPolicy(inFlightSkipGraceMilliseconds: 450)

        #expect(policy.shouldRecordInFlightSkip(lastPollAttemptAt: nil, now: now))
        #expect(!policy.shouldRecordInFlightSkip(
            lastPollAttemptAt: now.addingTimeInterval(-0.44),
            now: now
        ))
        #expect(policy.shouldRecordInFlightSkip(
            lastPollAttemptAt: now.addingTimeInterval(-0.45),
            now: now
        ))
        #expect(policy.shouldRecordInFlightSkip(
            lastPollAttemptAt: now.addingTimeInterval(0.1),
            now: now
        ))
    }

    @Test("Slow latency recommends throttle")
    func slowLatencyRecommendsThrottle() {
        let policy = FocusedTextPollingBackoffPolicy(
            maxPauseDurationMilliseconds: 360,
            slowPollP95Milliseconds: 80,
            minimumThrottleMilliseconds: 120
        )
        let summary = FocusedTextPollLatencySummary(
            count: 5,
            p50Milliseconds: 40,
            p95Milliseconds: 90,
            maxMilliseconds: 110
        )

        #expect(policy.throttleRecommendation(
            latencySummary: summary,
            skipSummary: nil
        ) == FocusedTextPollingThrottleRecommendation(
            shouldThrottle: true,
            reason: .slowPollLatency,
            pauseMilliseconds: 180
        ))
    }

    @Test("Overlapping poll streak recommends throttle")
    func overlappingPollStreakRecommendsThrottle() {
        let policy = FocusedTextPollingBackoffPolicy(
            repeatPauseStepMilliseconds: 40,
            overlappingPollCount: 2,
            minimumThrottleMilliseconds: 120
        )
        let summary = FocusedTextPollSkipSummary(count: 4, durationMilliseconds: 150)

        #expect(policy.throttleRecommendation(
            latencySummary: nil,
            skipSummary: summary
        ) == FocusedTextPollingThrottleRecommendation(
            shouldThrottle: true,
            reason: .overlappingPolls,
            pauseMilliseconds: 200
        ))
    }

    @Test("Single slow AX read recommends throttle")
    func singleSlowAXReadRecommendsThrottle() {
        let policy = FocusedTextPollingBackoffPolicy(
            maxPauseDurationMilliseconds: 360,
            slowPollP95Milliseconds: 80,
            minimumThrottleMilliseconds: 120
        )

        #expect(policy.throttleRecommendation(
            queueDelayMilliseconds: 0,
            readDurationMilliseconds: 95
        ) == FocusedTextPollingThrottleRecommendation(
            shouldThrottle: true,
            reason: .slowAXRead,
            pauseMilliseconds: 190
        ))
    }

    @Test("Slow AX read throttle clamps to max pause")
    func slowAXReadThrottleClampsToMaxPause() {
        let policy = FocusedTextPollingBackoffPolicy(
            maxPauseDurationMilliseconds: 360,
            slowPollP95Milliseconds: 80,
            minimumThrottleMilliseconds: 120
        )

        #expect(policy.throttleRecommendation(
            queueDelayMilliseconds: 20,
            readDurationMilliseconds: 420
        ) == FocusedTextPollingThrottleRecommendation(
            shouldThrottle: true,
            reason: .slowAXRead,
            pauseMilliseconds: 360
        ))
    }

    @Test("Fast clean polls do not throttle")
    func fastCleanPollsDoNotThrottle() {
        let policy = FocusedTextPollingBackoffPolicy(slowPollP95Milliseconds: 80)
        let latencySummary = FocusedTextPollLatencySummary(
            count: 5,
            p50Milliseconds: 15,
            p95Milliseconds: 40,
            maxMilliseconds: 60
        )
        let skipSummary = FocusedTextPollSkipSummary(count: 1, durationMilliseconds: 20)

        #expect(policy.throttleRecommendation(
            latencySummary: latencySummary,
            skipSummary: skipSummary
        ) == .none)
    }

    @Test("Fast AX read does not throttle")
    func fastAXReadDoesNotThrottle() {
        let policy = FocusedTextPollingBackoffPolicy(slowPollP95Milliseconds: 80)

        #expect(policy.throttleRecommendation(
            queueDelayMilliseconds: 20,
            readDurationMilliseconds: 79
        ) == .none)
    }
}
