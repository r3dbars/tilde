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

    @Test("preserves unchanged text during fresh caret geometry churn")
    func preservesUnchangedTextDuringFreshCaretGeometryChurn() {
        let policy = VisibleSuggestionPersistencePolicy()
        let fieldIdentity = FocusedFieldIdentity(
            bundleIdentifier: "com.openai.codex",
            processIdentifier: 42,
            elementIdentifier: 99
        )
        let text = "I want this suggestion to remain visible"

        #expect(policy.shouldPreserveDuringGeometryInvalidation(
            invalidationReason: .caretChanged,
            appBundleIdentifier: "com.openai.codex",
            fieldIdentity: fieldIdentity,
            currentSuggestionBundleIdentifier: "com.openai.codex",
            currentSuggestionFieldIdentity: fieldIdentity,
            currentSuggestionTextBeforeCursor: text,
            currentSuggestionAgeMilliseconds: 350,
            isInvalidatedByUserTyping: false,
            textBeforeCursor: text,
            textAfterCursor: ""
        ))

        #expect(!policy.shouldPreserveDuringGeometryInvalidation(
            invalidationReason: .caretChanged,
            appBundleIdentifier: "com.openai.codex",
            fieldIdentity: fieldIdentity,
            currentSuggestionBundleIdentifier: "com.openai.codex",
            currentSuggestionFieldIdentity: fieldIdentity,
            currentSuggestionTextBeforeCursor: text,
            currentSuggestionAgeMilliseconds: 5_001,
            isInvalidatedByUserTyping: false,
            textBeforeCursor: text,
            textAfterCursor: ""
        ))

        #expect(!policy.shouldPreserveDuringGeometryInvalidation(
            invalidationReason: .caretChanged,
            appBundleIdentifier: "com.openai.codex",
            fieldIdentity: fieldIdentity,
            currentSuggestionBundleIdentifier: "com.openai.codex",
            currentSuggestionFieldIdentity: fieldIdentity,
            currentSuggestionTextBeforeCursor: text,
            currentSuggestionAgeMilliseconds: 350,
            isInvalidatedByUserTyping: false,
            textBeforeCursor: "The text changed",
            textAfterCursor: ""
        ))
    }

    @Test("preserves matching optimistic type-through while AX text catches up")
    func preservesOptimisticTypeThroughAXLag() {
        let policy = VisibleSuggestionPersistencePolicy()
        let fieldIdentity = FocusedFieldIdentity(
            bundleIdentifier: "com.apple.TextEdit",
            processIdentifier: 42,
            elementIdentifier: 99
        )

        #expect(policy.shouldPreserveDuringGeometryInvalidation(
            invalidationReason: .caretChanged,
            appBundleIdentifier: "com.apple.TextEdit",
            fieldIdentity: fieldIdentity,
            currentSuggestionBundleIdentifier: "com.apple.TextEdit",
            currentSuggestionFieldIdentity: fieldIdentity,
            currentSuggestionTextBeforeCursor: "I can pred",
            currentSuggestionAgeMilliseconds: 700,
            isInvalidatedByUserTyping: false,
            optimisticTypedPrefix: "ed",
            textBeforeCursor: "I can pr",
            textAfterCursor: ""
        ))

        #expect(policy.shouldPreserveDuringGeometryInvalidation(
            invalidationReason: .textLineChanged,
            appBundleIdentifier: "com.apple.TextEdit",
            fieldIdentity: fieldIdentity,
            currentSuggestionBundleIdentifier: "com.apple.TextEdit",
            currentSuggestionFieldIdentity: fieldIdentity,
            currentSuggestionTextBeforeCursor: "I can pred",
            currentSuggestionAgeMilliseconds: 700,
            isInvalidatedByUserTyping: false,
            optimisticTypedPrefix: "ed",
            textBeforeCursor: "I can pre",
            textAfterCursor: ""
        ))
    }

    @Test("does not preserve divergent or invalidated optimistic typing")
    func rejectsDivergentOptimisticTypeThrough() {
        let policy = VisibleSuggestionPersistencePolicy()
        let fieldIdentity = FocusedFieldIdentity(
            bundleIdentifier: "com.apple.TextEdit",
            processIdentifier: 42,
            elementIdentifier: 99
        )

        #expect(!policy.shouldPreserveDuringGeometryInvalidation(
            invalidationReason: .caretChanged,
            appBundleIdentifier: "com.apple.TextEdit",
            fieldIdentity: fieldIdentity,
            currentSuggestionBundleIdentifier: "com.apple.TextEdit",
            currentSuggestionFieldIdentity: fieldIdentity,
            currentSuggestionTextBeforeCursor: "I can pred",
            currentSuggestionAgeMilliseconds: 700,
            isInvalidatedByUserTyping: false,
            optimisticTypedPrefix: "ed",
            textBeforeCursor: "I can prox",
            textAfterCursor: ""
        ))

        #expect(!policy.shouldPreserveDuringGeometryInvalidation(
            invalidationReason: .caretChanged,
            appBundleIdentifier: "com.apple.TextEdit",
            fieldIdentity: fieldIdentity,
            currentSuggestionBundleIdentifier: "com.apple.TextEdit",
            currentSuggestionFieldIdentity: fieldIdentity,
            currentSuggestionTextBeforeCursor: "I can pred",
            currentSuggestionAgeMilliseconds: 700,
            isInvalidatedByUserTyping: true,
            optimisticTypedPrefix: "ed",
            textBeforeCursor: "I can pre",
            textAfterCursor: ""
        ))
    }

    @Test("preserves active Codex proof suggestions through AX target churn")
    func preservesActiveCodexProofSuggestionsThroughAXTargetChurn() {
        let policy = VisibleSuggestionPersistencePolicy()
        let shownFieldIdentity = FocusedFieldIdentity(
            bundleIdentifier: "com.openai.codex",
            processIdentifier: 42,
            elementIdentifier: 7
        )
        let refreshedFieldIdentity = FocusedFieldIdentity(
            bundleIdentifier: "com.openai.codex",
            processIdentifier: 42,
            elementIdentifier: 99
        )
        let proofText = "AUTOCOMPLETE_LAB_CODEX_PROOF write a tiny test"

        #expect(policy.shouldPreserveDuringGeometryInvalidation(
            invalidationReason: .caretChanged,
            appBundleIdentifier: "com.openai.codex",
            fieldIdentity: refreshedFieldIdentity,
            currentSuggestionBundleIdentifier: "com.openai.codex",
            currentSuggestionFieldIdentity: shownFieldIdentity,
            currentSuggestionTextBeforeCursor: proofText,
            currentSuggestionAgeMilliseconds: 89,
            isInvalidatedByUserTyping: false,
            textBeforeCursor: proofText,
            textAfterCursor: "",
            promptProofModeEnabled: true,
            promptProofBundleIdentifier: "com.openai.codex",
            promptProofMarker: "AUTOCOMPLETE_LAB_CODEX_PROOF"
        ))

        #expect(policy.shouldPreserveDuringGeometryInvalidation(
            invalidationReason: .caretChanged,
            appBundleIdentifier: "com.openai.codex",
            fieldIdentity: refreshedFieldIdentity,
            currentSuggestionBundleIdentifier: "com.openai.codex",
            currentSuggestionFieldIdentity: shownFieldIdentity,
            currentSuggestionTextBeforeCursor: proofText,
            currentSuggestionAgeMilliseconds: 8_000,
            isInvalidatedByUserTyping: false,
            textBeforeCursor: proofText,
            textAfterCursor: "",
            promptProofModeEnabled: true,
            promptProofBundleIdentifier: "com.openai.codex",
            promptProofMarker: "AUTOCOMPLETE_LAB_CODEX_PROOF"
        ))

        #expect(!policy.shouldPreserveDuringGeometryInvalidation(
            invalidationReason: .caretChanged,
            appBundleIdentifier: "com.openai.codex",
            fieldIdentity: refreshedFieldIdentity,
            currentSuggestionBundleIdentifier: "com.openai.codex",
            currentSuggestionFieldIdentity: shownFieldIdentity,
            currentSuggestionTextBeforeCursor: proofText,
            currentSuggestionAgeMilliseconds: 10_001,
            isInvalidatedByUserTyping: false,
            textBeforeCursor: proofText,
            textAfterCursor: "",
            promptProofModeEnabled: true,
            promptProofBundleIdentifier: "com.openai.codex",
            promptProofMarker: "AUTOCOMPLETE_LAB_CODEX_PROOF"
        ))

        #expect(!policy.shouldPreserveDuringGeometryInvalidation(
            invalidationReason: .caretChanged,
            appBundleIdentifier: "com.openai.codex",
            fieldIdentity: refreshedFieldIdentity,
            currentSuggestionBundleIdentifier: "com.openai.codex",
            currentSuggestionFieldIdentity: shownFieldIdentity,
            currentSuggestionTextBeforeCursor: proofText,
            currentSuggestionAgeMilliseconds: 89,
            isInvalidatedByUserTyping: true,
            textBeforeCursor: proofText,
            textAfterCursor: "",
            promptProofModeEnabled: true,
            promptProofBundleIdentifier: "com.openai.codex",
            promptProofMarker: "AUTOCOMPLETE_LAB_CODEX_PROOF"
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
