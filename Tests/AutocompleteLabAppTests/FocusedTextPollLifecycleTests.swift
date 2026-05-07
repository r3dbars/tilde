import Foundation
import Testing
@testable import AutocompleteLabApp

@Suite("Focused text poll lifecycle")
struct FocusedTextPollLifecycleTests {
    @Test("Scheduled polls wait until the next interval")
    func scheduledPollsWaitUntilNextInterval() {
        var lifecycle = FocusedTextPollLifecycle()
        let now = Date()

        let first = lifecycle.shouldRunScheduledPoll(source: .watchPoll, now: now, interval: 0.5)
        let early = lifecycle.shouldRunScheduledPoll(
            source: .watchPoll,
            now: now.addingTimeInterval(0.2),
            interval: 0.5
        )
        let ready = lifecycle.shouldRunScheduledPoll(
            source: .watchPoll,
            now: now.addingTimeInterval(0.5),
            interval: 0.5
        )

        #expect(first)
        #expect(!early)
        #expect(ready)
    }

    @Test("Immediate poll resets the schedule gate")
    func immediatePollResetsScheduleGate() {
        var lifecycle = FocusedTextPollLifecycle()
        let now = Date()

        _ = lifecycle.shouldRunScheduledPoll(source: .idlePoll, now: now, interval: 10)
        lifecycle.requestImmediatePoll(now: now.addingTimeInterval(1))
        let ready = lifecycle.shouldRunScheduledPoll(
            source: .observer,
            now: now.addingTimeInterval(1),
            interval: 0
        )

        #expect(ready)
    }

    @Test("In-flight polls coalesce to the highest priority pending source")
    func inFlightPollsCoalesceToHighestPrioritySource() {
        var lifecycle = FocusedTextPollLifecycle()

        let first = lifecycle.beginPoll(source: .idlePoll, startedAt: 1_000_000)
        let lowPriorityPending = lifecycle.beginPoll(source: .watchPoll, startedAt: 2_000_000)
        let highPriorityPending = lifecycle.beginPoll(source: .observer, startedAt: 3_000_000)
        let finish = lifecycle.finishPoll(startedAt: 1_000_000, endedAt: 6_000_000)

        #expect(first == .start(startedAt: 1_000_000))
        #expect(lowPriorityPending == .coalesced(.watchPoll))
        #expect(highPriorityPending == .coalesced(.observer))
        #expect(finish.durationMilliseconds == 5)
        #expect(finish.pendingUpdateSource == .observer)
    }

    @Test("Finishing clears request identity and allows the next poll to start")
    func finishingClearsRequestIdentityAndAllowsNextPoll() {
        var lifecycle = FocusedTextPollLifecycle()

        _ = lifecycle.beginPoll(source: .watchPoll, startedAt: 1_000_000)
        lifecycle.recordReadRequestID(42)
        #expect(lifecycle.isLatestReadRequest(42))

        _ = lifecycle.finishPoll(startedAt: 1_000_000, endedAt: 2_000_000)
        let next = lifecycle.beginPoll(source: .watchPoll, startedAt: 3_000_000)

        #expect(!lifecycle.isLatestReadRequest(42))
        #expect(next == .start(startedAt: 3_000_000))
    }
}
