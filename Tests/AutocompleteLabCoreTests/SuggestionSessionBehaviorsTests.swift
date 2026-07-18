import Testing
import AutocompleteLabCore

@Suite("Suggestion session behaviors")
struct SuggestionSessionBehaviorsTests {
    @Test("bundles the five session behavior seams")
    func bundlesTheFiveSessionBehaviorSeams() {
        let behaviors = SuggestionSessionBehaviors()

        #expect(behaviors.control.startupState(persistedIsPaused: nil) == .running)
        #expect(
            behaviors.acceptanceGuard.decision(
                shown: Optional<SuggestionAcceptanceSnapshot>.none,
                current: Optional<SuggestionAcceptanceSnapshot>.none
            ) == .block(.missingShownSnapshot)
        )
        #expect(
            behaviors.triggerTiming.schedule(
                policyDelayMilliseconds: 0,
                timingLane: .instantWord,
                requestMode: .wordCompletion,
                renderMode: .inlineAdjacent
            ).resultLatencyBudgetMilliseconds == 1_200
        )
        #expect(behaviors.annoyanceBackoff == SuggestionAnnoyanceBackoffPolicy())
    }

    @Test("safety activation preserves secure-field suppression")
    func safetyActivationPreservesSecureFieldSuppression() {
        let decision = SuggestionSessionBehaviors().safetyActivation.activationDecision(
            using: CompletionActivationPolicy(pace: .normal),
            textBeforeCursor: "write a note",
            textAfterCursor: "",
            isSecure: true,
            isFieldSuppressed: false
        )

        #expect(decision == .block(.secureField))
    }
}
