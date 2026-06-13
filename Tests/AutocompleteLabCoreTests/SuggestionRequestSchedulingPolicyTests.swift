import Testing
@testable import AutocompleteLabCore

@Suite("Suggestion request scheduling policy")
struct SuggestionRequestSchedulingPolicyTests {
    @Test("Instant word requests run immediately even for floating overlays")
    func instantWordRequestsRunImmediately() {
        let policy = SuggestionRequestSchedulingPolicy()

        let schedule = policy.schedule(
            policyDelayMilliseconds: 40,
            timingLane: .instantWord,
            requestMode: .wordCompletion,
            renderMode: .floatingMirror
        )

        #expect(schedule.policyDelayMilliseconds == 40)
        #expect(schedule.scheduledDelayMilliseconds == 0)
        #expect(schedule.resultLatencyBudgetMilliseconds == 450)
        #expect(schedule.reason == "keystroke-instant-word")
        #expect(schedule.traceMetadata["scheduledDelayMilliseconds"] == "0")
        #expect(schedule.traceMetadata["requestSchedulingReason"] == "keystroke-instant-word")
        #expect(schedule.traceMetadata["resultLatencyBudgetMilliseconds"] == "450")
    }

    @Test("Floating continuation requests keep the overlay stability floor")
    func floatingContinuationRequestsKeepOverlayFloor() {
        let policy = SuggestionRequestSchedulingPolicy()

        let schedule = policy.schedule(
            policyDelayMilliseconds: 20,
            timingLane: .pausePhrase,
            requestMode: .phraseContinuation,
            renderMode: .floatingMirror
        )

        #expect(schedule.policyDelayMilliseconds == 20)
        #expect(schedule.scheduledDelayMilliseconds == 60)
        #expect(schedule.resultLatencyBudgetMilliseconds == 750)
        #expect(schedule.reason == "floating-overlay-floor")
    }

    @Test("Inline continuation requests use policy delay")
    func inlineContinuationRequestsUsePolicyDelay() {
        let policy = SuggestionRequestSchedulingPolicy()

        let schedule = policy.schedule(
            policyDelayMilliseconds: 120,
            timingLane: .pausePhrase,
            requestMode: .phraseContinuation,
            renderMode: .inlineAdjacent
        )

        #expect(schedule.policyDelayMilliseconds == 120)
        #expect(schedule.scheduledDelayMilliseconds == 120)
        #expect(schedule.reason == "policy-delay")
    }

    @Test("Late results are suppressed only after the schedule budget")
    func lateResultsAreSuppressedOnlyAfterBudget() {
        let policy = SuggestionRequestSchedulingPolicy(instantWordResultBudgetMilliseconds: 300)
        let schedule = policy.schedule(
            policyDelayMilliseconds: 0,
            timingLane: .instantWord,
            requestMode: .wordCompletion,
            renderMode: .inlineAdjacent
        )

        #expect(policy.shouldSuppressResult(latencyMilliseconds: 300, schedule: schedule) == false)
        #expect(policy.shouldSuppressResult(latencyMilliseconds: 301, schedule: schedule) == true)
    }
}
