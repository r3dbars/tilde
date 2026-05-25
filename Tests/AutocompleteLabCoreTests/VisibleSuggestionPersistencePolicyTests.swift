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
            currentSuggestionTextBeforeCursor: "I am writing a useful note",
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
            currentSuggestionTextBeforeCursor: "I am writing a useful note",
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
            currentSuggestionTextBeforeCursor: "I am writing a useful note",
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
            currentSuggestionTextBeforeCursor: "I am writing a useful note",
            currentSuggestionAgeMilliseconds: 350,
            isInvalidatedByUserTyping: false,
            textBeforeCursor: "",
            textAfterCursor: ""
        ))
    }

    @Test("preserves a fresh suggestion through a transient same-text middle split")
    func preservesFreshSuggestionThroughTransientSameTextMiddleSplit() {
        let policy = VisibleSuggestionPersistencePolicy()
        let fieldIdentity = FocusedFieldIdentity(
            bundleIdentifier: "com.google.Chrome",
            processIdentifier: 42,
            elementIdentifier: 99
        )

        #expect(policy.shouldPreserveAfterActivationBlock(
            blockReason: .middleOfLine,
            appBundleIdentifier: "com.google.Chrome",
            fieldIdentity: fieldIdentity,
            currentSuggestionBundleIdentifier: "com.google.Chrome",
            currentSuggestionFieldIdentity: fieldIdentity,
            currentSuggestionTextBeforeCursor: "Smoke proof feels instant and stays inst",
            currentSuggestionAgeMilliseconds: 350,
            isInvalidatedByUserTyping: false,
            textBeforeCursor: "Smoke pro",
            textAfterCursor: "of feels instant and stays inst"
        ))

        #expect(!policy.shouldPreserveAfterActivationBlock(
            blockReason: .middleOfLine,
            appBundleIdentifier: "com.google.Chrome",
            fieldIdentity: fieldIdentity,
            currentSuggestionBundleIdentifier: "com.google.Chrome",
            currentSuggestionFieldIdentity: fieldIdentity,
            currentSuggestionTextBeforeCursor: "Smoke proof feels instant and stays inst",
            currentSuggestionAgeMilliseconds: 350,
            isInvalidatedByUserTyping: false,
            textBeforeCursor: "Different pro",
            textAfterCursor: "of text"
        ))
    }
}
