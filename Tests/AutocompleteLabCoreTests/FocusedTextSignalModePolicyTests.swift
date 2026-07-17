import Testing
@testable import AutocompleteLabCore

@Suite("Focused text signal mode policy")
struct FocusedTextSignalModePolicyTests {
    @Test("New apps start hybrid with a slow heartbeat")
    func newAppsStartHybrid() {
        let policy = FocusedTextSignalModePolicy()
        let state = FocusedTextSignalModeState()

        #expect(policy.mode(for: "com.example.editor", state: state) == .hybrid)
        #expect(policy.heartbeatInterval(for: "com.example.editor", state: state) == 0.5)
    }

    @Test("Consecutive event-confirmed reads promote an app")
    func eventConfirmedReadsPromote() {
        let policy = FocusedTextSignalModePolicy(eventPromotionThreshold: 3)
        var state = FocusedTextSignalModeState()

        let first = policy.record(
            .eventConfirmedRead,
            for: "com.example.editor",
            state: &state
        )
        let second = policy.record(
            .eventConfirmedRead,
            for: "com.example.editor",
            state: &state
        )
        let third = policy.record(
            .eventConfirmedRead,
            for: "com.example.editor",
            state: &state
        )

        #expect(first == .init(previousMode: .hybrid, mode: .hybrid))
        #expect(second == .init(previousMode: .hybrid, mode: .hybrid))
        #expect(third == .init(previousMode: .hybrid, mode: .eventDriven))
        #expect(third.didChangeMode)
        #expect(policy.heartbeatInterval(for: "com.example.editor", state: state) == 1.5)
    }

    @Test("Silent key downs demote an app to polling")
    func silentKeyDownsDemote() {
        let policy = FocusedTextSignalModePolicy(silentKeyDownDemotionThreshold: 2)
        var state = FocusedTextSignalModeState()

        let first = policy.record(
            .keyDown(axNotificationObservedSinceLastKeyDown: false),
            for: "com.example.electron",
            state: &state
        )
        let second = policy.record(
            .keyDown(axNotificationObservedSinceLastKeyDown: false),
            for: "com.example.electron",
            state: &state
        )

        #expect(first.mode == .hybrid)
        #expect(second == .init(previousMode: .hybrid, mode: .polling))
        #expect(policy.heartbeatInterval(for: "com.example.electron", state: state) == 0.08)
    }

    @Test("App state is isolated by bundle identifier")
    func appStateIsIsolated() {
        let policy = FocusedTextSignalModePolicy(
            eventPromotionThreshold: 1,
            silentKeyDownDemotionThreshold: 1
        )
        var state = FocusedTextSignalModeState()

        policy.record(.eventConfirmedRead, for: "com.example.native", state: &state)
        policy.record(
            .keyDown(axNotificationObservedSinceLastKeyDown: false),
            for: "com.example.electron",
            state: &state
        )

        #expect(policy.mode(for: "com.example.native", state: state) == .eventDriven)
        #expect(policy.mode(for: "com.example.electron", state: state) == .polling)
        #expect(policy.mode(for: "com.example.unseen", state: state) == .hybrid)
    }

    @Test("Observed key downs do not break a realistic event streak")
    func observedKeyDownsPreserveEventStreak() {
        let policy = FocusedTextSignalModePolicy(eventPromotionThreshold: 3)
        var state = FocusedTextSignalModeState()

        for _ in 0..<3 {
            policy.record(.eventConfirmedRead, for: "com.example.editor", state: &state)
            policy.record(
                .keyDown(axNotificationObservedSinceLastKeyDown: true),
                for: "com.example.editor",
                state: &state
            )
        }

        #expect(policy.mode(for: "com.example.editor", state: state) == .eventDriven)
    }

    @Test("Confirmed events recover an app from polling")
    func confirmedEventsRecoverFromPolling() {
        let policy = FocusedTextSignalModePolicy(
            eventPromotionThreshold: 2,
            silentKeyDownDemotionThreshold: 1
        )
        var state = FocusedTextSignalModeState()

        policy.record(
            .keyDown(axNotificationObservedSinceLastKeyDown: false),
            for: "com.example.editor",
            state: &state
        )
        #expect(policy.mode(for: "com.example.editor", state: state) == .polling)

        let first = policy.record(
            .eventConfirmedRead,
            for: "com.example.editor",
            state: &state
        )
        let second = policy.record(
            .eventConfirmedRead,
            for: "com.example.editor",
            state: &state
        )

        #expect(first.mode == .polling)
        #expect(second == .init(previousMode: .polling, mode: .eventDriven))
    }

    @Test("A silent key down breaks event promotion progress")
    func silentKeyDownBreaksPromotionProgress() {
        let policy = FocusedTextSignalModePolicy(
            eventPromotionThreshold: 2,
            silentKeyDownDemotionThreshold: 3
        )
        var state = FocusedTextSignalModeState()

        policy.record(.eventConfirmedRead, for: "com.example.editor", state: &state)
        policy.record(
            .keyDown(axNotificationObservedSinceLastKeyDown: false),
            for: "com.example.editor",
            state: &state
        )
        policy.record(.eventConfirmedRead, for: "com.example.editor", state: &state)

        #expect(policy.mode(for: "com.example.editor", state: state) == .hybrid)
    }

    @Test("Reset forgets only the requested app")
    func resetForgetsOneApp() {
        let policy = FocusedTextSignalModePolicy(eventPromotionThreshold: 1)
        var state = FocusedTextSignalModeState()

        policy.record(.eventConfirmedRead, for: "com.example.one", state: &state)
        policy.record(.eventConfirmedRead, for: "com.example.two", state: &state)
        policy.reset(bundleIdentifier: "com.example.one", state: &state)

        #expect(policy.mode(for: "com.example.one", state: state) == .hybrid)
        #expect(policy.mode(for: "com.example.two", state: state) == .eventDriven)
    }
}
