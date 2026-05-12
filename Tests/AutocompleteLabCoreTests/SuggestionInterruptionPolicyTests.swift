import Testing
@testable import AutocompleteLabCore

@Suite("Suggestion interruption policy")
struct SuggestionInterruptionPolicyTests {
    private let policy = SuggestionInterruptionPolicy()

    @Test("Sleep wake and display interruptions fail closed")
    func sleepWakeAndDisplayInterruptionsFailClosed() {
        for kind in [
            SuggestionInterruptionKind.systemWillSleep,
            .systemDidWake,
            .displaysDidSleep,
            .displaysDidWake
        ] {
            let decision = policy.decision(for: kind)

            #expect(decision.shouldInvalidatePendingRequest)
            #expect(decision.shouldClearFocusedField)
            #expect(decision.shouldStopKeyboardCapture)
            #expect(decision.shouldHideFieldStatus)
            #expect(decision.hideReason == kind.rawValue)
            #expect(decision.keyboardCaptureStopReason == kind.rawValue)
            #expect(decision.diagnosticEvent == "workspace-lifecycle-interrupted")
            #expect(decision.diagnosticMetadata["safetyFailure"] == "true")
        }
    }

    @Test("Accessibility loss clears active typing state")
    func accessibilityLossClearsActiveTypingState() {
        let decision = policy.decision(for: .accessibilityPermissionLost)

        #expect(decision.shouldInvalidatePendingRequest)
        #expect(decision.shouldClearFocusedField)
        #expect(decision.shouldStopKeyboardCapture)
        #expect(decision.hideReason == "accessibility-permission-lost")
        #expect(decision.decisionText == "Blocked: Accessibility permission missing")
        #expect(decision.diagnosticEvent == "accessibility-permission-lost")
    }

    @Test("Screen geometry changes stop capture without forgetting the field")
    func screenGeometryChangesStopCaptureWithoutForgettingField() {
        let decision = policy.decision(for: .screenGeometryChanged)

        #expect(decision.shouldInvalidatePendingRequest)
        #expect(!decision.shouldClearFocusedField)
        #expect(decision.shouldStopKeyboardCapture)
        #expect(decision.shouldHideFieldStatus)
        #expect(decision.hideReason == "screen-geometry-changed")
        #expect(decision.diagnosticEvent == "screen-geometry-changed")
    }
}
