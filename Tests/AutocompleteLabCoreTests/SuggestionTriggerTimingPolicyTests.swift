import Testing
@testable import AutocompleteLabCore

@Suite("Suggestion trigger timing policy")
struct SuggestionTriggerTimingPolicyTests {
    private let policy = SuggestionTriggerTimingPolicy()

    @Test("combines trigger decision and scheduling without changing cadence")
    func combinesTriggerDecisionAndSchedulingWithoutChangingCadence() {
        let trigger = SuggestionTriggerPolicy(
            charactersBeforePauseRequest: 1,
            pauseDelayMilliseconds: 180,
            minimumPhraseContinuationWords: 1
        )
        let decision = policy.decision(
            using: trigger,
            previousTextBeforeCursor: "hello",
            currentTextBeforeCursor: "hello world",
            requestMode: .phraseContinuation
        )

        #expect(decision == .request(delayMilliseconds: 180, lane: .pausePhrase))
        let schedule = policy.schedule(
            policyDelayMilliseconds: 180,
            timingLane: .pausePhrase,
            requestMode: .phraseContinuation,
            renderMode: .inlineAdjacent
        )
        #expect(schedule.scheduledDelayMilliseconds == 180)
        #expect(schedule.resultLatencyBudgetMilliseconds == 2_000)
    }

    @Test("keeps the instant-word lane at zero delay and the 1200ms budget")
    func keepsInstantWordLaneAtZeroDelayAndThe1200MillisecondBudget() {
        let schedule = policy.schedule(
            policyDelayMilliseconds: 120,
            timingLane: .instantWord,
            requestMode: .wordCompletion,
            renderMode: .inlineAdjacent
        )

        #expect(schedule.scheduledDelayMilliseconds == 0)
        #expect(schedule.resultLatencyBudgetMilliseconds == 1_200)
        #expect(!policy.shouldSuppressResult(latencyMilliseconds: 1_200, schedule: schedule))
        #expect(policy.shouldSuppressResult(latencyMilliseconds: 1_201, schedule: schedule))
    }
}
