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

    @Test("Blocks accept when target fingerprint changes")
    func blocksAcceptWhenTargetFingerprintChanges() {
        let shown = snapshot(
            targetFingerprint: targetFingerprint(
                elementRect: RoundedFocusedRect(x: 20, y: 40, width: 300, height: 44),
                caretRect: RoundedFocusedRect(x: 120, y: 52, width: 1, height: 20)
            )
        )
        let movedCaret = snapshot(
            targetFingerprint: targetFingerprint(
                elementRect: RoundedFocusedRect(x: 20, y: 40, width: 300, height: 44),
                caretRect: RoundedFocusedRect(x: 180, y: 52, width: 1, height: 20)
            )
        )
        let movedWindow = snapshot(
            targetFingerprint: targetFingerprint(
                elementRect: RoundedFocusedRect(x: 20, y: 120, width: 300, height: 44),
                caretRect: RoundedFocusedRect(x: 120, y: 52, width: 1, height: 20)
            )
        )
        let changedWindowIdentifier = snapshot(
            targetFingerprint: targetFingerprint(windowIdentifier: 43)
        )

        #expect(guardPolicy.decision(shown: shown, current: movedCaret) == .block(.targetFingerprintChanged))
        #expect(guardPolicy.decision(shown: shown, current: movedWindow) == .block(.targetFingerprintChanged))
        #expect(guardPolicy.decision(shown: shown, current: changedWindowIdentifier) == .block(.targetFingerprintChanged))
    }

    @Test("Advanced target fingerprints keep target lock while allowing natural caret movement")
    func advancedTargetFingerprintAllowsNaturalCaretMovement() {
        let shown = snapshot(
            targetFingerprint: targetFingerprint()
                .advancingTextRevision(textBeforeCursor: "Please send this", textAfterCursor: ""),
            textBeforeCursor: "Please send this"
        )
        let current = snapshot(
            targetFingerprint: targetFingerprint(
                caretRect: RoundedFocusedRect(x: 240, y: 52, width: 1, height: 20),
                textBeforeCursor: "Please send this",
                textAfterCursor: ""
            ),
            textBeforeCursor: "Please send this"
        )

        #expect(guardPolicy.decision(shown: shown, current: current) == .allow)
    }

    @Test("Advanced acceptance snapshots allow typed-through suggestion progress")
    func advancedAcceptanceSnapshotAllowsTypedThroughSuggestionProgress() {
        let shown = snapshot(textBeforeCursor: "Smoke proof feels inst")
            .advancingTextRevision(
                textBeforeCursor: "Smoke proof feels insta",
                textAfterCursor: ""
            )
        let current = snapshot(
            targetFingerprint: targetFingerprint(
                caretRect: RoundedFocusedRect(x: 180, y: 52, width: 1, height: 20),
                textBeforeCursor: "Smoke proof feels insta",
                textAfterCursor: ""
            ),
            textBeforeCursor: "Smoke proof feels insta"
        )

        #expect(guardPolicy.decision(shown: shown, current: current) == .allow)
    }

    @Test("Missing snapshots fail closed")
    func missingSnapshotsFailClosed() {
        let shown = snapshot()

        #expect(guardPolicy.decision(shown: nil, current: shown) == .block(.missingShownSnapshot))
        #expect(guardPolicy.decision(shown: shown, current: nil) == .block(.missingCurrentSnapshot))
    }

    private func snapshot(
        fieldIdentity: FocusedFieldIdentity = identity(),
        targetFingerprint: FocusedTargetFingerprint = Self.targetFingerprint(),
        textBeforeCursor: String = "Please send",
        textAfterCursor: String = "",
        selectedTextLength: Int = 0
    ) -> SuggestionAcceptanceSnapshot {
        SuggestionAcceptanceSnapshot(
            fieldIdentity: fieldIdentity,
            targetFingerprint: targetFingerprint,
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

    private static func targetFingerprint(
        role: String? = "AXTextArea",
        subrole: String? = nil,
        windowIdentifier: Int? = 42,
        elementRect: RoundedFocusedRect? = RoundedFocusedRect(x: 20, y: 40, width: 300, height: 44),
        windowRect: RoundedFocusedRect? = RoundedFocusedRect(x: 0, y: 0, width: 800, height: 600),
        caretRect: RoundedFocusedRect? = RoundedFocusedRect(x: 120, y: 52, width: 1, height: 20),
        textBeforeCursor: String = "Please send",
        textAfterCursor: String = ""
    ) -> FocusedTargetFingerprint {
        FocusedTargetFingerprint(
            role: role,
            subrole: subrole,
            elementFingerprint: FocusedElementFingerprint(
                identifier: "editor",
                title: "Draft",
                placeholder: "Message",
                windowTitle: "Window"
            ),
            windowIdentifier: windowIdentifier,
            elementBounds: elementRect,
            windowBounds: windowRect,
            caretBounds: caretRect,
            surroundingTextRevision: FocusedTextRevision(
                textBeforeCursor: textBeforeCursor,
                textAfterCursor: textAfterCursor
            )
        )
    }

    private func targetFingerprint(
        role: String? = "AXTextArea",
        subrole: String? = nil,
        windowIdentifier: Int? = 42,
        elementRect: RoundedFocusedRect? = RoundedFocusedRect(x: 20, y: 40, width: 300, height: 44),
        windowRect: RoundedFocusedRect? = RoundedFocusedRect(x: 0, y: 0, width: 800, height: 600),
        caretRect: RoundedFocusedRect? = RoundedFocusedRect(x: 120, y: 52, width: 1, height: 20),
        textBeforeCursor: String = "Please send",
        textAfterCursor: String = ""
    ) -> FocusedTargetFingerprint {
        Self.targetFingerprint(
            role: role,
            subrole: subrole,
            windowIdentifier: windowIdentifier,
            elementRect: elementRect,
            windowRect: windowRect,
            caretRect: caretRect,
            textBeforeCursor: textBeforeCursor,
            textAfterCursor: textAfterCursor
        )
    }
}
