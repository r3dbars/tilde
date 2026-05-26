import Foundation
import Testing
@testable import AutocompleteLabCore

@Suite("Focused text poll gate policy")
struct FocusedTextPollGatePolicyTests {
    @Test("Starts first poll immediately")
    func startsFirstPollImmediately() {
        let policy = FocusedTextPollGatePolicy()

        #expect(policy.decision(
            now: Date(timeIntervalSince1970: 1_000),
            lastPollAt: nil,
            isPollInFlight: false,
            isTrustedForAccessibility: true,
            hasSupportedProfile: true,
            hasVisibleSuggestion: false
        ) == .startPoll)
    }

    @Test("Waits during cadence window before counting in-flight skip")
    func waitsDuringCadenceWindowBeforeCountingInFlightSkip() {
        let policy = FocusedTextPollGatePolicy(cadencePolicy: FocusPollingCadencePolicy(
            activeSuggestionIntervalSeconds: 0.05,
            supportedTypingWatchIntervalSeconds: 0.2
        ))
        let startedAt = Date(timeIntervalSince1970: 1_000)

        #expect(policy.decision(
            now: startedAt.addingTimeInterval(0.19),
            lastPollAt: startedAt,
            isPollInFlight: true,
            isTrustedForAccessibility: true,
            hasSupportedProfile: true,
            hasVisibleSuggestion: false
        ) == .waitForCadence)

        #expect(policy.decision(
            now: startedAt.addingTimeInterval(0.2),
            lastPollAt: startedAt,
            isPollInFlight: true,
            isTrustedForAccessibility: true,
            hasSupportedProfile: true,
            hasVisibleSuggestion: false
        ) == .skipInFlight)
    }

    @Test("Visible suggestion uses faster cadence")
    func visibleSuggestionUsesFasterCadence() {
        let policy = FocusedTextPollGatePolicy(cadencePolicy: FocusPollingCadencePolicy(
            activeSuggestionIntervalSeconds: 0.08,
            supportedTypingWatchIntervalSeconds: 0.2
        ))
        let startedAt = Date(timeIntervalSince1970: 1_000)

        #expect(policy.decision(
            now: startedAt.addingTimeInterval(0.081),
            lastPollAt: startedAt,
            isPollInFlight: false,
            isTrustedForAccessibility: true,
            hasSupportedProfile: true,
            hasVisibleSuggestion: true
        ) == .startPoll)
    }

    @Test("Typing pause waits before starting or counting skipped polls")
    func typingPauseWaitsBeforeStartingOrCountingSkippedPolls() {
        let policy = FocusedTextPollGatePolicy(cadencePolicy: FocusPollingCadencePolicy(
            activeSuggestionIntervalSeconds: 0.05,
            supportedTypingWatchIntervalSeconds: 0.2
        ))
        let startedAt = Date(timeIntervalSince1970: 1_000)

        #expect(policy.decision(
            now: startedAt.addingTimeInterval(1),
            lastPollAt: nil,
            isPollInFlight: false,
            isTrustedForAccessibility: true,
            hasSupportedProfile: true,
            hasVisibleSuggestion: false,
            isPausedForTyping: true
        ) == .waitForTypingPause)

        #expect(policy.decision(
            now: startedAt.addingTimeInterval(1),
            lastPollAt: startedAt,
            isPollInFlight: true,
            isTrustedForAccessibility: true,
            hasSupportedProfile: true,
            hasVisibleSuggestion: false,
            isPausedForTyping: true
        ) == .waitForTypingPause)
    }
}
