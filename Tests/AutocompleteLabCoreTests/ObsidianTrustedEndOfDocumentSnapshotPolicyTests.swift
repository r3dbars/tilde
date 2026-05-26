import Testing
@testable import AutocompleteLabCore

@Suite("Obsidian trusted end-of-document snapshot policy")
struct ObsidianTrustedEndOfDocumentSnapshotPolicyTests {
    private let policy = ObsidianTrustedEndOfDocumentSnapshotPolicy()

    @Test("Uses trusted Obsidian end snapshot after focus loss")
    func usesTrustedObsidianEndSnapshotAfterFocusLoss() {
        let field = obsidianField()
        let trusted = snapshot(field, beforeLength: 420, after: "")

        let result = policy.repairPreviousSnapshot(
            fieldIdentity: field,
            previousSnapshot: nil,
            trustedSnapshot: trusted
        )

        #expect(result == trusted)
    }

    @Test("Prefers current clean previous snapshot")
    func prefersCurrentCleanPreviousSnapshot() {
        let field = obsidianField()
        let current = snapshot(field, beforeLength: 440, after: "")
        let trusted = snapshot(field, beforeLength: 420, after: "")

        let result = policy.repairPreviousSnapshot(
            fieldIdentity: field,
            previousSnapshot: current,
            trustedSnapshot: trusted
        )

        #expect(result == current)
    }

    @Test("Uses trusted snapshot when current previous is a poisoned split")
    func usesTrustedSnapshotWhenCurrentPreviousIsPoisonedSplit() {
        let field = obsidianField()
        let poisoned = snapshot(field, beforeLength: 390, after: " and stays")
        let trusted = snapshot(field, beforeLength: 420, after: "")

        let result = policy.repairPreviousSnapshot(
            fieldIdentity: field,
            previousSnapshot: poisoned,
            trustedSnapshot: trusted
        )

        #expect(result == trusted)
    }

    @Test("Ignores trusted snapshots outside the same Obsidian field")
    func ignoresTrustedSnapshotsOutsideSameObsidianField() {
        let field = obsidianField(elementIdentifier: 1)
        let otherField = obsidianField(elementIdentifier: 2)
        let trusted = snapshot(otherField, beforeLength: 420, after: "")
        let previous = snapshot(field, beforeLength: 40, after: " middle")

        let result = policy.repairPreviousSnapshot(
            fieldIdentity: field,
            previousSnapshot: previous,
            trustedSnapshot: trusted
        )

        #expect(result == previous)
    }

    @Test("Only remembers long Obsidian end-of-document snapshots")
    func onlyRemembersLongObsidianEndSnapshots() {
        let field = obsidianField()

        #expect(policy.shouldRemember(snapshot: snapshot(field, beforeLength: 420, after: "")))
        #expect(!policy.shouldRemember(snapshot: snapshot(field, beforeLength: 120, after: "")))
        #expect(!policy.shouldRemember(snapshot: snapshot(field, beforeLength: 420, after: " middle")))
        #expect(!policy.shouldRemember(snapshot: snapshot(chromeField(), beforeLength: 420, after: "")))
    }

    private func obsidianField(elementIdentifier: Int = 456) -> FocusedFieldIdentity {
        FocusedFieldIdentity(
            bundleIdentifier: "md.obsidian",
            processIdentifier: 123,
            elementIdentifier: elementIdentifier
        )
    }

    private func chromeField() -> FocusedFieldIdentity {
        FocusedFieldIdentity(
            bundleIdentifier: "com.google.Chrome",
            processIdentifier: 123,
            elementIdentifier: 456
        )
    }

    private func snapshot(
        _ field: FocusedFieldIdentity,
        beforeLength: Int,
        after: String
    ) -> FocusedTextSnapshot {
        FocusedTextSnapshot(
            fieldIdentity: field,
            textBeforeCursor: String(repeating: "a", count: beforeLength),
            textAfterCursor: after
        )
    }
}
