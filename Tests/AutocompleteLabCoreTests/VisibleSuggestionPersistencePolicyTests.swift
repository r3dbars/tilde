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
            currentSuggestionAgeMilliseconds: 4_999,
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
            currentSuggestionAgeMilliseconds: 5_001,
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

    @Test("preserves same-text middle splits during geometry invalidation")
    func preservesSameTextMiddleSplitsDuringGeometryInvalidation() {
        let policy = VisibleSuggestionPersistencePolicy()
        let fieldIdentity = FocusedFieldIdentity(
            bundleIdentifier: "com.google.Chrome",
            processIdentifier: 42,
            elementIdentifier: 99
        )

        #expect(policy.shouldPreserveDuringGeometryInvalidation(
            invalidationReason: .caretChanged,
            appBundleIdentifier: "com.google.Chrome",
            fieldIdentity: fieldIdentity,
            currentSuggestionBundleIdentifier: "com.google.Chrome",
            currentSuggestionFieldIdentity: fieldIdentity,
            currentSuggestionTextBeforeCursor: "Smoke proof feels instant and stays inst",
            currentSuggestionAgeMilliseconds: 4_999,
            isInvalidatedByUserTyping: false,
            textBeforeCursor: "Smoke pro",
            textAfterCursor: "of feels instant and stays inst"
        ))

        #expect(policy.shouldPreserveDuringGeometryInvalidation(
            invalidationReason: .textLineChanged,
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

        #expect(!policy.shouldPreserveDuringGeometryInvalidation(
            invalidationReason: .caretChanged,
            appBundleIdentifier: "com.google.Chrome",
            fieldIdentity: fieldIdentity,
            currentSuggestionBundleIdentifier: "com.google.Chrome",
            currentSuggestionFieldIdentity: fieldIdentity,
            currentSuggestionTextBeforeCursor: "Smoke proof feels instant and stays inst",
            currentSuggestionAgeMilliseconds: 5_001,
            isInvalidatedByUserTyping: false,
            textBeforeCursor: "Smoke pro",
            textAfterCursor: "of feels instant and stays inst"
        ))
    }

    @Test("preserves Obsidian suggestions through document-start AX teleport")
    func preservesObsidianSuggestionsThroughDocumentStartAXTeleport() {
        let policy = VisibleSuggestionPersistencePolicy()
        let fieldIdentity = FocusedFieldIdentity(
            bundleIdentifier: "md.obsidian",
            processIdentifier: 42,
            elementIdentifier: 99
        )
        let visibleTail = "This long wrapped Obsidian line keeps the caret at the end while Smoke proof feels instant and stays"

        #expect(policy.shouldPreserveAfterActivationBlock(
            blockReason: .tooLittleContext,
            appBundleIdentifier: "md.obsidian",
            fieldIdentity: fieldIdentity,
            currentSuggestionBundleIdentifier: "md.obsidian",
            currentSuggestionFieldIdentity: fieldIdentity,
            currentSuggestionTextBeforeCursor: visibleTail,
            currentSuggestionAgeMilliseconds: 92,
            isInvalidatedByUserTyping: false,
            textBeforeCursor: "",
            textAfterCursor: visibleTail
        ))
        #expect(policy.shouldPreserveAfterActivationBlock(
            blockReason: .markdownCodeContext,
            appBundleIdentifier: "md.obsidian",
            fieldIdentity: fieldIdentity,
            currentSuggestionBundleIdentifier: "md.obsidian",
            currentSuggestionFieldIdentity: fieldIdentity,
            currentSuggestionTextBeforeCursor: visibleTail,
            currentSuggestionAgeMilliseconds: 92,
            isInvalidatedByUserTyping: false,
            textBeforeCursor: "`",
            textAfterCursor: visibleTail
        ))
        #expect(policy.shouldPreserveDuringGeometryInvalidation(
            invalidationReason: .caretChanged,
            appBundleIdentifier: "md.obsidian",
            fieldIdentity: fieldIdentity,
            currentSuggestionBundleIdentifier: "md.obsidian",
            currentSuggestionFieldIdentity: fieldIdentity,
            currentSuggestionTextBeforeCursor: visibleTail,
            currentSuggestionAgeMilliseconds: 92,
            isInvalidatedByUserTyping: false,
            textBeforeCursor: "",
            textAfterCursor: visibleTail
        ))
        #expect(policy.shouldPreserveDuringGeometryInvalidation(
            invalidationReason: .caretChanged,
            appBundleIdentifier: "md.obsidian",
            fieldIdentity: fieldIdentity,
            currentSuggestionBundleIdentifier: "md.obsidian",
            currentSuggestionFieldIdentity: fieldIdentity,
            currentSuggestionTextBeforeCursor: visibleTail,
            currentSuggestionAgeMilliseconds: 1_700,
            isInvalidatedByUserTyping: false,
            textBeforeCursor: "",
            textAfterCursor: visibleTail
        ))
        #expect(!policy.shouldPreserveAfterActivationBlock(
            blockReason: .markdownCodeContext,
            appBundleIdentifier: "md.obsidian",
            fieldIdentity: fieldIdentity,
            currentSuggestionBundleIdentifier: "md.obsidian",
            currentSuggestionFieldIdentity: fieldIdentity,
            currentSuggestionTextBeforeCursor: visibleTail,
            currentSuggestionAgeMilliseconds: 92,
            isInvalidatedByUserTyping: true,
            textBeforeCursor: "`",
            textAfterCursor: visibleTail
        ))
        #expect(!policy.shouldPreserveDuringGeometryInvalidation(
            invalidationReason: .windowChanged,
            appBundleIdentifier: "md.obsidian",
            fieldIdentity: fieldIdentity,
            currentSuggestionBundleIdentifier: "md.obsidian",
            currentSuggestionFieldIdentity: fieldIdentity,
            currentSuggestionTextBeforeCursor: visibleTail,
            currentSuggestionAgeMilliseconds: 92,
            isInvalidatedByUserTyping: false,
            textBeforeCursor: "",
            textAfterCursor: visibleTail
        ))
        #expect(!policy.shouldPreserveDuringGeometryInvalidation(
            invalidationReason: .caretChanged,
            appBundleIdentifier: "md.obsidian",
            fieldIdentity: fieldIdentity,
            currentSuggestionBundleIdentifier: "md.obsidian",
            currentSuggestionFieldIdentity: fieldIdentity,
            currentSuggestionTextBeforeCursor: visibleTail,
            currentSuggestionAgeMilliseconds: 2_501,
            isInvalidatedByUserTyping: false,
            textBeforeCursor: "",
            textAfterCursor: visibleTail
        ))
    }
}
