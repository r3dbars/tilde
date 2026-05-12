import Testing
@testable import AutocompleteLabCore

@Suite("Workspace focus change policy")
struct WorkspaceFocusChangePolicyTests {
    private let policy = WorkspaceFocusChangePolicy()

    @Test("Same app activation keeps current suggestion state")
    func sameAppActivationKeepsCurrentSuggestionState() {
        #expect(!policy.shouldClearFocus(
            kind: .activated,
            notificationBundleIdentifier: "com.google.Chrome",
            frontmostBundleIdentifier: "com.google.Chrome",
            currentFieldIdentity: chromeField
        ))
    }

    @Test("Different app activation clears current suggestion state")
    func differentAppActivationClearsCurrentSuggestionState() {
        #expect(policy.shouldClearFocus(
            kind: .activated,
            notificationBundleIdentifier: "com.apple.TextEdit",
            frontmostBundleIdentifier: "com.apple.TextEdit",
            currentFieldIdentity: chromeField
        ))
    }

    @Test("Same app deactivation clears current suggestion state")
    func sameAppDeactivationClearsCurrentSuggestionState() {
        #expect(policy.shouldClearFocus(
            kind: .deactivated,
            notificationBundleIdentifier: "com.google.Chrome",
            frontmostBundleIdentifier: "com.apple.TextEdit",
            currentFieldIdentity: chromeField
        ))
    }

    @Test("Stale same app deactivation keeps current suggestion state when app is still frontmost")
    func staleSameAppDeactivationKeepsCurrentSuggestionStateWhenAppIsStillFrontmost() {
        #expect(!policy.shouldClearFocus(
            kind: .deactivated,
            notificationBundleIdentifier: "com.google.Chrome",
            frontmostBundleIdentifier: "com.google.Chrome",
            currentFieldIdentity: chromeField
        ))
    }

    @Test("Different app deactivation keeps current suggestion state")
    func differentAppDeactivationKeepsCurrentSuggestionState() {
        #expect(!policy.shouldClearFocus(
            kind: .deactivated,
            notificationBundleIdentifier: "com.apple.TextEdit",
            frontmostBundleIdentifier: "com.google.Chrome",
            currentFieldIdentity: chromeField
        ))
    }

    @Test("Unknown activation fails closed")
    func unknownActivationFailsClosed() {
        #expect(policy.shouldClearFocus(
            kind: .activated,
            notificationBundleIdentifier: nil,
            frontmostBundleIdentifier: nil,
            currentFieldIdentity: chromeField
        ))
    }

    @Test("Missing current field fails closed")
    func missingCurrentFieldFailsClosed() {
        #expect(policy.shouldClearFocus(
            kind: .activated,
            notificationBundleIdentifier: "com.google.Chrome",
            frontmostBundleIdentifier: "com.google.Chrome",
            currentFieldIdentity: nil
        ))
    }

    private var chromeField: FocusedFieldIdentity {
        FocusedFieldIdentity(
            bundleIdentifier: "com.google.Chrome",
            processIdentifier: 123,
            elementIdentifier: 456
        )
    }
}
