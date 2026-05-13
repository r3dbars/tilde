import AutocompleteLabCore
import Testing
@testable import AutocompleteLabApp

@Suite("Suggestion debounce schedule")
struct SuggestionDebounceScheduleTests {
    @Test("Inline render mode uses the policy delay as the scheduled delay")
    func inlineRenderModeUsesPolicyDelay() {
        let schedule = SuggestionDebounceSchedule(
            policyDelayMilliseconds: 120,
            renderMode: .inlineAdjacent
        )

        #expect(schedule.policyDelayMilliseconds == 120)
        #expect(schedule.scheduledDelayMilliseconds == 120)
        #expect(schedule.traceMetadata["delayMilliseconds"] == "120")
        #expect(schedule.traceMetadata["policyDelayMilliseconds"] == "120")
        #expect(schedule.traceMetadata["scheduledDelayMilliseconds"] == "120")
    }

    @Test("Floating render mode reports the actual scheduled floor")
    func floatingRenderModeReportsActualScheduledFloor() {
        let schedule = SuggestionDebounceSchedule(
            policyDelayMilliseconds: 20,
            renderMode: .floatingMirror
        )

        #expect(schedule.policyDelayMilliseconds == 20)
        #expect(schedule.scheduledDelayMilliseconds == 60)
        #expect(schedule.traceMetadata["delayMilliseconds"] == "20")
        #expect(schedule.traceMetadata["policyDelayMilliseconds"] == "20")
        #expect(schedule.traceMetadata["scheduledDelayMilliseconds"] == "60")
    }
}
