import Testing
@testable import AutocompleteLabApp

@Suite("Field status indicator state")
struct FieldStatusIndicatorStateTests {
    @Test("Blocked state can explain why the field is quiet")
    func blockedStateCanExplainWhyTheFieldIsQuiet() {
        let state = FieldStatusIndicatorState.blocked.withReason("surface needs proof first")

        #expect(state.kind == .blocked)
        #expect(state.accessibilityLabel == "SteadyType is off in this field: surface needs proof first")
    }

    @Test("Waiting state can explain temporary quiet mode")
    func waitingStateCanExplainTemporaryQuietMode() {
        let state = FieldStatusIndicatorState.waiting.withReason("recent rejects")

        #expect(state.kind == .waiting)
        #expect(state.accessibilityLabel == "SteadyType is waiting in this field: recent rejects")
    }

    @Test("Reason copy is one line and bounded")
    func reasonCopyIsOneLineAndBounded() {
        let state = FieldStatusIndicatorState.blocked.withReason(
            "this reason is intentionally long and includes\nextra spacing so the tooltip stays readable instead of turning into a noisy diagnostic sentence that overwhelms the field"
        )

        #expect(!state.accessibilityLabel.contains("\n"))
        #expect(state.accessibilityLabel.count <= 130)
    }
}
