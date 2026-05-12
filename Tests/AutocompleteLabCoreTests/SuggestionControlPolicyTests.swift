import Testing
@testable import AutocompleteLabCore

@Suite("Suggestion control policy")
struct SuggestionControlPolicyTests {
    @Test("Persisted pause bool maps to stable control state")
    func persistedPauseBoolMapsToStableControlState() {
        let policy = SuggestionControlPolicy()

        let running = policy.state(isPaused: false)
        let paused = policy.state(isPaused: true)

        #expect(running == .running)
        #expect(!running.isPaused)
        #expect(running.statusName == "running")
        #expect(running.toggleTitle == "Pause Suggestions")

        #expect(paused == .paused)
        #expect(paused.isPaused)
        #expect(paused.statusName == "paused")
        #expect(paused.toggleTitle == "Resume Suggestions")
    }

    @Test("Fresh installs start paused until the user resumes suggestions")
    func freshInstallsStartPausedUntilTheUserResumesSuggestions() {
        let policy = SuggestionControlPolicy()

        #expect(policy.startupState(persistedIsPaused: nil) == .paused)
        #expect(policy.startupState(persistedIsPaused: true) == .paused)
        #expect(policy.startupState(persistedIsPaused: false) == .running)
    }

    @Test("Paused state blocks suggestion requests with global pause reason")
    func pausedStateBlocksSuggestionRequests() {
        let policy = SuggestionControlPolicy()

        #expect(policy.suggestionAvailability(for: .running) == .allowed)
        #expect(policy.suggestionAvailability(for: .running).isAllowed)

        let decision = policy.suggestionAvailability(for: .paused)

        #expect(decision == .blocked(.globalPause))
        #expect(!decision.isAllowed)

        guard case let .blocked(reason) = decision else {
            Issue.record("Expected paused state to block suggestions")
            return
        }

        #expect(reason.decisionText == "Paused")
        #expect(reason.hideReason == "global-pause")
    }

    @Test("Toggling into pause requests visible state cleanup")
    func togglingIntoPauseRequestsVisibleStateCleanup() {
        let policy = SuggestionControlPolicy()

        let transition = policy.toggle(.running)

        #expect(transition.previousState == .running)
        #expect(transition.nextState == .paused)
        #expect(transition.decisionText == "Paused")
        #expect(transition.shouldClearFocusedField)
        #expect(transition.shouldStopKeyboardCapture)
        #expect(transition.cleanupReason == .globalPause)
    }

    @Test("Toggling out of pause resumes without cleanup")
    func togglingOutOfPauseResumesWithoutCleanup() {
        let policy = SuggestionControlPolicy()

        let transition = policy.toggle(.paused)

        #expect(transition.previousState == .paused)
        #expect(transition.nextState == .running)
        #expect(transition.decisionText == "Ready: resumed")
        #expect(!transition.shouldClearFocusedField)
        #expect(!transition.shouldStopKeyboardCapture)
        #expect(transition.cleanupReason == nil)
    }
}
