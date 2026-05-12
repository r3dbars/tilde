import Testing
@testable import AutocompleteLabCore

@Suite("Visible suggestion persistence policy")
struct VisibleSuggestionPersistencePolicyTests {
    @Test("preserves a fresh suggestion through a transient empty AX snapshot")
    func preservesFreshSuggestionThroughTransientEmptyContext() {
        let policy = VisibleSuggestionPersistencePolicy()
        let fieldIdentity = FocusedFieldIdentity(
            bundleIdentifier: "com.apple.Notes",
            processIdentifier: 42,
            elementIdentifier: 99
        )

        #expect(policy.shouldPreserveAfterActivationBlock(
            blockReason: .tooLittleContext,
            appBundleIdentifier: "com.apple.Notes",
            fieldIdentity: fieldIdentity,
            currentSuggestionBundleIdentifier: "com.apple.Notes",
            currentSuggestionFieldIdentity: fieldIdentity,
            currentSuggestionAgeMilliseconds: 350,
            isInvalidatedByUserTyping: false,
            textBeforeCursor: "",
            textAfterCursor: ""
        ))
    }

    @Test("does not preserve stale or user-invalidated suggestions")
    func doesNotPreserveStaleOrUserInvalidatedSuggestions() {
        let policy = VisibleSuggestionPersistencePolicy()
        let fieldIdentity = FocusedFieldIdentity(
            bundleIdentifier: "com.apple.Notes",
            processIdentifier: 42,
            elementIdentifier: 99
        )

        #expect(!policy.shouldPreserveAfterActivationBlock(
            blockReason: .tooLittleContext,
            appBundleIdentifier: "com.apple.Notes",
            fieldIdentity: fieldIdentity,
            currentSuggestionBundleIdentifier: "com.apple.Notes",
            currentSuggestionFieldIdentity: fieldIdentity,
            currentSuggestionAgeMilliseconds: 1_201,
            isInvalidatedByUserTyping: false,
            textBeforeCursor: "",
            textAfterCursor: ""
        ))
        #expect(!policy.shouldPreserveAfterActivationBlock(
            blockReason: .tooLittleContext,
            appBundleIdentifier: "com.apple.Notes",
            fieldIdentity: fieldIdentity,
            currentSuggestionBundleIdentifier: "com.apple.Notes",
            currentSuggestionFieldIdentity: fieldIdentity,
            currentSuggestionAgeMilliseconds: 350,
            isInvalidatedByUserTyping: true,
            textBeforeCursor: "",
            textAfterCursor: ""
        ))
        #expect(!policy.shouldPreserveAfterActivationBlock(
            blockReason: .middleOfLine,
            appBundleIdentifier: "com.apple.Notes",
            fieldIdentity: fieldIdentity,
            currentSuggestionBundleIdentifier: "com.apple.Notes",
            currentSuggestionFieldIdentity: fieldIdentity,
            currentSuggestionAgeMilliseconds: 350,
            isInvalidatedByUserTyping: false,
            textBeforeCursor: "",
            textAfterCursor: ""
        ))
    }
}
