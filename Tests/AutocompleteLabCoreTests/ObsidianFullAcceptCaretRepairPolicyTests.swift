import Testing
@testable import AutocompleteLabCore

struct ObsidianFullAcceptCaretRepairPolicyTests {
    private let policy = ObsidianFullAcceptCaretRepairPolicy()

    @Test("Repairs Obsidian full accept when the accepted snapshot is at the field end")
    func repairsObsidianFullAcceptAtFieldEnd() {
        let identity = FocusedFieldIdentity(
            bundleIdentifier: "md.obsidian",
            processIdentifier: 123,
            elementIdentifier: 456
        )
        let snapshot = FocusedTextSnapshot(
            fieldIdentity: identity,
            textBeforeCursor: "Autocomplete Lab Obsidian proof\nSmoke proof feels instant and stays",
            textAfterCursor: ""
        )

        #expect(policy.shouldRepair(
            bundleIdentifier: "md.obsidian",
            action: .acceptAllVisible,
            snapshot: snapshot,
            currentFieldIdentity: identity
        ))
    }

    @Test("Skips non-Obsidian, partial accept, after-cursor, and field mismatch cases")
    func skipsUnsafeRepairCases() {
        let identity = FocusedFieldIdentity(
            bundleIdentifier: "md.obsidian",
            processIdentifier: 123,
            elementIdentifier: 456
        )
        let snapshot = FocusedTextSnapshot(
            fieldIdentity: identity,
            textBeforeCursor: "Smoke proof feels instant and stays",
            textAfterCursor: ""
        )
        let middleSnapshot = FocusedTextSnapshot(
            fieldIdentity: identity,
            textBeforeCursor: "Smoke proof feels",
            textAfterCursor: " instant and stays"
        )
        let otherIdentity = FocusedFieldIdentity(
            bundleIdentifier: "md.obsidian",
            processIdentifier: 123,
            elementIdentifier: 789
        )

        #expect(!policy.shouldRepair(
            bundleIdentifier: "com.apple.TextEdit",
            action: .acceptAllVisible,
            snapshot: snapshot,
            currentFieldIdentity: identity
        ))
        #expect(!policy.shouldRepair(
            bundleIdentifier: "md.obsidian",
            action: .acceptNextWord,
            snapshot: snapshot,
            currentFieldIdentity: identity
        ))
        #expect(!policy.shouldRepair(
            bundleIdentifier: "md.obsidian",
            action: .acceptAllVisible,
            snapshot: middleSnapshot,
            currentFieldIdentity: identity
        ))
        #expect(!policy.shouldRepair(
            bundleIdentifier: "md.obsidian",
            action: .acceptAllVisible,
            snapshot: snapshot,
            currentFieldIdentity: otherIdentity
        ))
    }
}
