import Testing
@testable import AutocompleteLabCore

@Suite("Suggestion acceptance guard")
struct SuggestionAcceptanceGuardTests {
    private let guardPolicy = SuggestionAcceptanceGuard()

    @Test("Allows accept when field and text snapshot match")
    func allowsAcceptWhenSnapshotMatches() {
        let shown = snapshot()

        #expect(guardPolicy.decision(shown: shown, current: shown) == .allow)
    }

    @Test("Blocks accept after app bundle changes")
    func blocksAcceptAfterAppBundleChanges() {
        let shown = snapshot()
        let current = snapshot(
            fieldIdentity: identity(bundleIdentifier: "com.google.Chrome")
        )

        #expect(guardPolicy.decision(shown: shown, current: current) == .block(.appChanged))
    }

    @Test("Blocks accept after process changes")
    func blocksAcceptAfterProcessChanges() {
        let shown = snapshot()
        let current = snapshot(
            fieldIdentity: identity(processIdentifier: 43)
        )

        #expect(guardPolicy.decision(shown: shown, current: current) == .block(.appChanged))
    }

    @Test("Blocks accept after focused element changes")
    func blocksAcceptAfterFocusedElementChanges() {
        let shown = snapshot()
        let current = snapshot(
            fieldIdentity: identity(elementIdentifier: 10)
        )

        #expect(guardPolicy.decision(shown: shown, current: current) == .block(.fieldChanged))
    }

    @Test("Blocks accept when selected text appears")
    func blocksAcceptWhenSelectedTextAppears() {
        let shown = snapshot()
        let current = snapshot(selectedTextLength: 3)

        #expect(guardPolicy.decision(shown: shown, current: current) == .block(.selectedTextChanged))
    }

    @Test("Blocks accept when text before cursor changed")
    func blocksAcceptWhenTextBeforeCursorChanged() {
        let shown = snapshot(textBeforeCursor: "Please send")
        let current = snapshot(textBeforeCursor: "Please send this")

        #expect(guardPolicy.decision(shown: shown, current: current) == .block(.textBeforeCursorChanged))
    }

    @Test("Blocks accept when text after cursor changed")
    func blocksAcceptWhenTextAfterCursorChanged() {
        let shown = snapshot(textAfterCursor: " today")
        let current = snapshot(textAfterCursor: " tomorrow")

        #expect(guardPolicy.decision(shown: shown, current: current) == .block(.textAfterCursorChanged))
    }

    @Test("Missing snapshots fail closed")
    func missingSnapshotsFailClosed() {
        let shown = snapshot()

        #expect(guardPolicy.decision(shown: nil, current: shown) == .block(.missingShownSnapshot))
        #expect(guardPolicy.decision(shown: shown, current: nil) == .block(.missingCurrentSnapshot))
    }

    private func snapshot(
        fieldIdentity: FocusedFieldIdentity = identity(),
        textBeforeCursor: String = "Please send",
        textAfterCursor: String = "",
        selectedTextLength: Int = 0
    ) -> SuggestionAcceptanceSnapshot {
        SuggestionAcceptanceSnapshot(
            fieldIdentity: fieldIdentity,
            textBeforeCursor: textBeforeCursor,
            textAfterCursor: textAfterCursor,
            selectedTextLength: selectedTextLength
        )
    }

    private static func identity(
        bundleIdentifier: String = "com.apple.TextEdit",
        processIdentifier: Int32 = 42,
        elementIdentifier: Int = 9
    ) -> FocusedFieldIdentity {
        FocusedFieldIdentity(
            bundleIdentifier: bundleIdentifier,
            processIdentifier: processIdentifier,
            elementIdentifier: elementIdentifier
        )
    }

    private func identity(
        bundleIdentifier: String = "com.apple.TextEdit",
        processIdentifier: Int32 = 42,
        elementIdentifier: Int = 9
    ) -> FocusedFieldIdentity {
        Self.identity(
            bundleIdentifier: bundleIdentifier,
            processIdentifier: processIdentifier,
            elementIdentifier: elementIdentifier
        )
    }
}
