import Testing
@testable import AutocompleteLabCore

@Suite("Clipboard fallback policy")
struct ClipboardFallbackPolicyTests {
    private let restorePolicy = ClipboardFallbackRestorePolicy()

    @Test("Restore policy restores only the app fallback payload")
    func restorePolicyRestoresOnlyFallbackPayload() {
        #expect(restorePolicy.decision(
            insertedText: " accepted",
            currentString: " accepted",
            fallbackChangeCount: 12,
            currentChangeCount: 12
        ) == .restoreOriginalPasteboard)
    }

    @Test("Restore policy preserves user clipboard changes")
    func restorePolicyPreservesUserClipboardChanges() {
        #expect(restorePolicy.decision(
            insertedText: " accepted",
            currentString: " user copied text",
            fallbackChangeCount: 12,
            currentChangeCount: 13
        ) == .preserveCurrentPasteboard)

        #expect(restorePolicy.decision(
            insertedText: " accepted",
            currentString: " accepted",
            fallbackChangeCount: 12,
            currentChangeCount: 13
        ) == .preserveCurrentPasteboard)
    }

    @Test("Restore policy preserves missing or empty fallback payloads")
    func restorePolicyPreservesMissingOrEmptyFallbackPayloads() {
        #expect(restorePolicy.decision(
            insertedText: " accepted",
            currentString: nil,
            fallbackChangeCount: 12,
            currentChangeCount: 12
        ) == .preserveCurrentPasteboard)

        #expect(restorePolicy.decision(
            insertedText: "",
            currentString: "",
            fallbackChangeCount: 12,
            currentChangeCount: 12
        ) == .preserveCurrentPasteboard)
    }

    private func profile(
        insertionMode: InsertionMode = .axSelectedText,
        fallbackInsertionMode: InsertionMode? = nil,
        isSensitive: Bool = false
    ) -> CompatibilityProfile {
        CompatibilityProfile(
            bundleIdentifier: "com.example.Editor",
            displayName: "Editor",
            supportLevel: .yellow,
            supportReason: "Test profile",
            renderMode: .inlineAdjacent,
            insertionMode: insertionMode,
            fallbackInsertionMode: fallbackInsertionMode,
            isSensitive: isSensitive,
            notes: "Test profile"
        )
    }
}
