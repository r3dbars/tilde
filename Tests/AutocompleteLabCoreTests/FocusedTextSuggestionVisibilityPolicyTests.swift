import Testing
@testable import AutocompleteLabCore

@Suite("Focused text suggestion visibility policy")
struct FocusedTextSuggestionVisibilityPolicyTests {
    private let policy = FocusedTextSuggestionVisibilityPolicy()

    @Test("Preserves a suggestion owned by the reference app")
    func preservesSuggestionOwnedByReferenceApp() {
        #expect(!policy.shouldHideVisibleSuggestion(
            currentSuggestionBundleIdentifier: "com.apple.Notes",
            currentSuggestionFieldIdentity: fieldIdentity(1),
            currentFieldIdentity: fieldIdentity(1),
            referenceBundleIdentifier: "com.apple.Notes",
            isInvalidatedByUserTyping: false
        ))
    }

    @Test("Preserves a virtual app suggestion owned by the host app")
    func preservesVirtualAppSuggestionOwnedByHostApp() {
        #expect(!policy.shouldHideVisibleSuggestion(
            currentSuggestionBundleIdentifier: "com.anthropic.claude-code",
            currentSuggestionHostBundleIdentifier: "com.mitchellh.ghostty",
            currentSuggestionFieldIdentity: fieldIdentity(1, bundleIdentifier: "com.mitchellh.ghostty"),
            currentFieldIdentity: fieldIdentity(1, bundleIdentifier: "com.mitchellh.ghostty"),
            referenceBundleIdentifier: "com.mitchellh.ghostty",
            isInvalidatedByUserTyping: false,
            currentSuggestionAgeMilliseconds: 120,
            maximumPreservedAgeMilliseconds: 750
        ))
    }

    @Test("Hides a suggestion invalidated by typing")
    func hidesSuggestionInvalidatedByTyping() {
        #expect(policy.shouldHideVisibleSuggestion(
            currentSuggestionBundleIdentifier: "com.apple.Notes",
            currentSuggestionFieldIdentity: fieldIdentity(1),
            currentFieldIdentity: fieldIdentity(1),
            referenceBundleIdentifier: "com.apple.Notes",
            isInvalidatedByUserTyping: true
        ))
    }

    @Test("Requires a fresh suggestion when a maximum age is set")
    func requiresFreshSuggestionWhenMaximumAgeIsSet() {
        #expect(policy.shouldHideVisibleSuggestion(
            currentSuggestionBundleIdentifier: "com.apple.Notes",
            currentSuggestionFieldIdentity: fieldIdentity(1),
            currentFieldIdentity: fieldIdentity(1),
            referenceBundleIdentifier: "com.apple.Notes",
            isInvalidatedByUserTyping: false,
            currentSuggestionAgeMilliseconds: 901,
            maximumPreservedAgeMilliseconds: 750
        ))
        #expect(policy.shouldHideVisibleSuggestion(
            currentSuggestionBundleIdentifier: "com.apple.Notes",
            currentSuggestionFieldIdentity: fieldIdentity(1),
            currentFieldIdentity: fieldIdentity(1),
            referenceBundleIdentifier: "com.apple.Notes",
            isInvalidatedByUserTyping: false,
            maximumPreservedAgeMilliseconds: 750
        ))
        #expect(!policy.shouldHideVisibleSuggestion(
            currentSuggestionBundleIdentifier: "com.apple.Notes",
            currentSuggestionFieldIdentity: fieldIdentity(1),
            currentFieldIdentity: fieldIdentity(1),
            referenceBundleIdentifier: "com.apple.Notes",
            isInvalidatedByUserTyping: false,
            currentSuggestionAgeMilliseconds: 240,
            maximumPreservedAgeMilliseconds: 750
        ))
    }

    @Test("Hides a suggestion owned by a different app")
    func hidesSuggestionOwnedByDifferentApp() {
        #expect(policy.shouldHideVisibleSuggestion(
            currentSuggestionBundleIdentifier: "com.apple.Notes",
            currentSuggestionFieldIdentity: fieldIdentity(1),
            currentFieldIdentity: fieldIdentity(1),
            referenceBundleIdentifier: "com.apple.TextEdit",
            isInvalidatedByUserTyping: false
        ))
    }

    @Test("Hides a suggestion when app ownership is unknown")
    func hidesSuggestionWithUnknownAppOwnership() {
        #expect(policy.shouldHideVisibleSuggestion(
            currentSuggestionBundleIdentifier: nil,
            currentSuggestionFieldIdentity: fieldIdentity(1),
            currentFieldIdentity: fieldIdentity(1),
            referenceBundleIdentifier: "com.apple.Notes",
            isInvalidatedByUserTyping: false
        ))
        #expect(policy.shouldHideVisibleSuggestion(
            currentSuggestionBundleIdentifier: "com.apple.Notes",
            currentSuggestionFieldIdentity: fieldIdentity(1),
            currentFieldIdentity: fieldIdentity(1),
            referenceBundleIdentifier: nil,
            isInvalidatedByUserTyping: false
        ))
    }

    @Test("Hides a suggestion when field ownership is unknown or changed")
    func hidesSuggestionWithUnknownOrChangedFieldOwnership() {
        #expect(policy.shouldHideVisibleSuggestion(
            currentSuggestionBundleIdentifier: "com.apple.Notes",
            currentSuggestionFieldIdentity: nil,
            currentFieldIdentity: fieldIdentity(1),
            referenceBundleIdentifier: "com.apple.Notes",
            isInvalidatedByUserTyping: false
        ))
        #expect(policy.shouldHideVisibleSuggestion(
            currentSuggestionBundleIdentifier: "com.apple.Notes",
            currentSuggestionFieldIdentity: fieldIdentity(1),
            currentFieldIdentity: nil,
            referenceBundleIdentifier: "com.apple.Notes",
            isInvalidatedByUserTyping: false
        ))
        #expect(policy.shouldHideVisibleSuggestion(
            currentSuggestionBundleIdentifier: "com.apple.Notes",
            currentSuggestionFieldIdentity: fieldIdentity(1),
            currentFieldIdentity: fieldIdentity(2),
            referenceBundleIdentifier: "com.apple.Notes",
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
