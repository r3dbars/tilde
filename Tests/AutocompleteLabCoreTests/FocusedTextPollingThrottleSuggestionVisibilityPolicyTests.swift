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

    @Test("Preserves virtual app suggestion when frontmost app is its host")
    func preservesVirtualAppSuggestionWhenFrontmostAppIsHost() {
        let policy = FocusedTextPollingThrottleSuggestionVisibilityPolicy()

        #expect(!policy.shouldHideVisibleSuggestion(
            currentSuggestionBundleIdentifier: "com.anthropic.claude-code",
            currentSuggestionHostBundleIdentifier: "com.mitchellh.ghostty",
            currentSuggestionFieldIdentity: fieldIdentity(1, bundleIdentifier: "com.mitchellh.ghostty"),
            currentFieldIdentity: fieldIdentity(1, bundleIdentifier: "com.mitchellh.ghostty"),
            frontmostBundleIdentifier: "com.mitchellh.ghostty",
            isInvalidatedByUserTyping: false,
            currentSuggestionAgeMilliseconds: 120,
            maximumPreservedAgeMilliseconds: 750
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

    @Test("Hides stale visible suggestion during polling throttle")
    func hidesStaleVisibleSuggestionDuringThrottle() {
        let policy = FocusedTextPollingThrottleSuggestionVisibilityPolicy()

        #expect(policy.shouldHideVisibleSuggestion(
            currentSuggestionBundleIdentifier: "com.apple.Notes",
            currentSuggestionFieldIdentity: fieldIdentity(1),
            currentFieldIdentity: fieldIdentity(1),
            frontmostBundleIdentifier: "com.apple.Notes",
            isInvalidatedByUserTyping: false,
            currentSuggestionAgeMilliseconds: 901,
            maximumPreservedAgeMilliseconds: 750
        ))

        #expect(!policy.shouldHideVisibleSuggestion(
            currentSuggestionBundleIdentifier: "com.apple.Notes",
            currentSuggestionFieldIdentity: fieldIdentity(1),
            currentFieldIdentity: fieldIdentity(1),
            frontmostBundleIdentifier: "com.apple.Notes",
            isInvalidatedByUserTyping: false,
            currentSuggestionAgeMilliseconds: 240,
            maximumPreservedAgeMilliseconds: 750
        ))
    }

    @Test("Hides visible suggestion with unknown age when freshness is required")
    func hidesVisibleSuggestionWithUnknownAgeWhenFreshnessRequired() {
        let policy = FocusedTextPollingThrottleSuggestionVisibilityPolicy()

        #expect(policy.shouldHideVisibleSuggestion(
            currentSuggestionBundleIdentifier: "com.apple.Notes",
            currentSuggestionFieldIdentity: fieldIdentity(1),
            currentFieldIdentity: fieldIdentity(1),
            frontmostBundleIdentifier: "com.apple.Notes",
            isInvalidatedByUserTyping: false,
            maximumPreservedAgeMilliseconds: 750
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

    private func fieldIdentity(
        _ elementIdentifier: Int,
        bundleIdentifier: String = "com.apple.Notes"
    ) -> FocusedFieldIdentity {
        FocusedFieldIdentity(
            bundleIdentifier: bundleIdentifier,
            processIdentifier: 123,
            elementIdentifier: elementIdentifier
        )
    }
}
