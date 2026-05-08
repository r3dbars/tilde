import Foundation
import Testing
@testable import AutocompleteLabCore

@Suite("Focus polling cadence policy")
struct FocusPollingCadencePolicyTests {
    @Test("Uses bounded active polling only while a suggestion is visible")
    func usesBoundedActivePollingOnlyWhileSuggestionIsVisible() {
        let policy = FocusPollingCadencePolicy()

        #expect(policy.interval(
            isTrustedForAccessibility: true,
            hasSupportedProfile: true,
            hasVisibleSuggestion: true
        ) == policy.activeSuggestionIntervalSeconds)

        #expect(policy.interval(
            isTrustedForAccessibility: true,
            hasSupportedProfile: true,
            hasVisibleSuggestion: false
        ) == policy.supportedTypingWatchIntervalSeconds)
    }

    @Test("Backs off supported polling during recent active typing")
    func backsOffSupportedPollingDuringRecentActiveTyping() {
        let policy = FocusPollingCadencePolicy(
            supportedTypingWatchIntervalSeconds: 0.12,
            recentTextChangeIntervalSeconds: 0.20,
            recentTextChangeWindowSeconds: 0.75
        )
        let now = Date(timeIntervalSince1970: 100)

        #expect(policy.hasRecentTextChange(
            lastTextChangeAt: now.addingTimeInterval(-0.7),
            now: now
        ))
        #expect(!policy.hasRecentTextChange(
            lastTextChangeAt: now.addingTimeInterval(-0.8),
            now: now
        ))
        #expect(policy.interval(
            isTrustedForAccessibility: true,
            hasSupportedProfile: true,
            hasVisibleSuggestion: false,
            hasRecentTextChange: true
        ) == policy.recentTextChangeIntervalSeconds)
    }

    @Test("Backs off when Accessibility is missing or no target app is supported")
    func backsOffWhenAccessibilityIsMissingOrNoTargetAppIsSupported() {
        let policy = FocusPollingCadencePolicy()

        #expect(policy.interval(
            isTrustedForAccessibility: false,
            hasSupportedProfile: true,
            hasVisibleSuggestion: true
        ) == policy.untrustedIntervalSeconds)

        #expect(policy.interval(
            isTrustedForAccessibility: true,
            hasSupportedProfile: false,
            hasVisibleSuggestion: false
        ) == policy.idleIntervalSeconds)
    }
}
