import Testing
@testable import AutocompleteLabCore

@Suite("Keyboard capture policy")
struct KeyboardCapturePolicyTests {
    @Test("Captures keys only while a suggestion is visible")
    func capturesOnlyForVisibleSuggestion() {
        let policy = KeyboardCapturePolicy()

        #expect(policy.shouldCaptureKeys(isTrustedForAccessibility: true, hasVisibleSuggestion: true))
        #expect(!policy.shouldCaptureKeys(isTrustedForAccessibility: true, hasVisibleSuggestion: false))
    }

    @Test("Does not capture keys without Accessibility trust")
    func doesNotCaptureWithoutAccessibilityTrust() {
        let policy = KeyboardCapturePolicy()

        #expect(!policy.shouldCaptureKeys(isTrustedForAccessibility: false, hasVisibleSuggestion: true))
    }

    @Test("Does not capture keys while suggestions are globally paused")
    func doesNotCaptureKeysWhileGloballyPaused() {
        let policy = KeyboardCapturePolicy()

        #expect(!policy.shouldCaptureKeys(
            isTrustedForAccessibility: true,
            hasVisibleSuggestion: true,
            controlState: .paused
        ))
    }
}
