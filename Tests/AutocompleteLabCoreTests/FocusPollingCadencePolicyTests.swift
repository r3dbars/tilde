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
