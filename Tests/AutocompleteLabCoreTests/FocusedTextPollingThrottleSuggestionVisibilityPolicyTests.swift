import Testing
@testable import AutocompleteLabCore

@Suite("Focused text polling throttle suggestion visibility policy")
struct FocusedTextPollingThrottleSuggestionVisibilityPolicyTests {
    @Test("Preserves same-app visible suggestion during polling throttle")
    func preservesSameAppVisibleSuggestionDuringThrottle() {
        let policy = FocusedTextPollingThrottleSuggestionVisibilityPolicy()

        #expect(!policy.shouldHideVisibleSuggestion(
            currentSuggestionBundleIdentifier: "com.apple.Notes",
            currentSuggestionFieldIdentity: fieldIdentity(1),
            currentFieldIdentity: fieldIdentity(1),
            frontmostBundleIdentifier: "com.apple.Notes",
            isInvalidatedByUserTyping: false
        ))
    }

    @Test("Hides suggestion invalidated by typing")
    func hidesSuggestionInvalidatedByTyping() {
        let policy = FocusedTextPollingThrottleSuggestionVisibilityPolicy()

        #expect(policy.shouldHideVisibleSuggestion(
            currentSuggestionBundleIdentifier: "com.apple.Notes",
            currentSuggestionFieldIdentity: fieldIdentity(1),
            currentFieldIdentity: fieldIdentity(1),
            frontmostBundleIdentifier: "com.apple.Notes",
            isInvalidatedByUserTyping: true
        ))
    }

    @Test("Hides suggestion when frontmost app changes")
    func hidesSuggestionWhenFrontmostAppChanges() {
        let policy = FocusedTextPollingThrottleSuggestionVisibilityPolicy()

        #expect(policy.shouldHideVisibleSuggestion(
            currentSuggestionBundleIdentifier: "com.apple.Notes",
            currentSuggestionFieldIdentity: fieldIdentity(1),
            currentFieldIdentity: fieldIdentity(1),
            frontmostBundleIdentifier: "com.apple.TextEdit",
            isInvalidatedByUserTyping: false
        ))
    }

    @Test("Hides suggestion when app ownership is unknown")
    func hidesSuggestionWithUnknownAppOwnership() {
        let policy = FocusedTextPollingThrottleSuggestionVisibilityPolicy()

        #expect(policy.shouldHideVisibleSuggestion(
            currentSuggestionBundleIdentifier: nil,
            currentSuggestionFieldIdentity: fieldIdentity(1),
            currentFieldIdentity: fieldIdentity(1),
            frontmostBundleIdentifier: "com.apple.Notes",
            isInvalidatedByUserTyping: false
        ))
        #expect(policy.shouldHideVisibleSuggestion(
            currentSuggestionBundleIdentifier: "com.apple.Notes",
            currentSuggestionFieldIdentity: fieldIdentity(1),
            currentFieldIdentity: fieldIdentity(1),
            frontmostBundleIdentifier: nil,
            isInvalidatedByUserTyping: false
        ))
    }

    @Test("Hides suggestion when field ownership is unknown or changed")
    func hidesSuggestionWithUnknownOrChangedFieldOwnership() {
        let policy = FocusedTextPollingThrottleSuggestionVisibilityPolicy()

        #expect(policy.shouldHideVisibleSuggestion(
            currentSuggestionBundleIdentifier: "com.apple.Notes",
            currentSuggestionFieldIdentity: nil,
            currentFieldIdentity: fieldIdentity(1),
            frontmostBundleIdentifier: "com.apple.Notes",
            isInvalidatedByUserTyping: false
        ))
        #expect(policy.shouldHideVisibleSuggestion(
            currentSuggestionBundleIdentifier: "com.apple.Notes",
            currentSuggestionFieldIdentity: fieldIdentity(1),
            currentFieldIdentity: nil,
            frontmostBundleIdentifier: "com.apple.Notes",
            isInvalidatedByUserTyping: false
        ))
        #expect(policy.shouldHideVisibleSuggestion(
            currentSuggestionBundleIdentifier: "com.apple.Notes",
            currentSuggestionFieldIdentity: fieldIdentity(1),
            currentFieldIdentity: fieldIdentity(2),
            frontmostBundleIdentifier: "com.apple.Notes",
            isInvalidatedByUserTyping: false
        ))
    }

    private func fieldIdentity(_ elementIdentifier: Int) -> FocusedFieldIdentity {
        FocusedFieldIdentity(
            bundleIdentifier: "com.apple.Notes",
            processIdentifier: 123,
            elementIdentifier: elementIdentifier
        )
    }
}
