import Testing
@testable import AutocompleteLabCore

@Suite("Text context repair policy")
struct TextContextRepairPolicyTests {
    @Test("Repairs Notes checklist text that grows after the AX cursor")
    func repairsNotesTextAfterCursorTyping() {
        let policy = TextContextRepairPolicy()

        let result = policy.repair(TextContextRepairInput(
            bundleIdentifier: "com.apple.Notes",
            role: "AXTextArea",
            textBeforeCursor: "",
            textAfterCursor: "Smoke proof feels inst",
            selectedTextLength: 0,
            previousTextBeforeCursor: "",
            previousTextAfterCursor: ""
        ))

        #expect(result.textBeforeCursor == "Smoke proof feels inst")
        #expect(result.textAfterCursor == "")
        #expect(result.reason == .notesTextAfterCursorTyping)
    }

    @Test("Keeps repaired Notes text stable across repeated stale AX reads")
    func keepsStableNotesRepair() {
        let policy = TextContextRepairPolicy()

        let result = policy.repair(TextContextRepairInput(
            bundleIdentifier: "com.apple.Notes",
            role: "AXTextArea",
            textBeforeCursor: "",
            textAfterCursor: "Smoke proof feels inst",
            selectedTextLength: 0,
            previousTextBeforeCursor: "Smoke proof feels inst",
            previousTextAfterCursor: ""
        ))

        #expect(result.textBeforeCursor == "Smoke proof feels inst")
        #expect(result.textAfterCursor == "")
        #expect(result.reason == .notesTextAfterCursorStable)
    }

    @Test("Repairs Notes text when accepted text extends the previously repaired line")
    func repairsAcceptedTextGrowthAfterPreviousRepair() {
        let policy = TextContextRepairPolicy()

        let result = policy.repair(TextContextRepairInput(
            bundleIdentifier: "com.apple.Notes",
            role: "AXTextArea",
            textBeforeCursor: "",
            textAfterCursor: "Smoke proof feels instant",
            selectedTextLength: 0,
            previousTextBeforeCursor: "Smoke proof feels inst",
            previousTextAfterCursor: ""
        ))

        #expect(result.textBeforeCursor == "Smoke proof feels instant")
        #expect(result.textAfterCursor == "")
        #expect(result.reason == .notesTextAfterCursorTyping)
    }

    @Test("Does not repair unrelated apps or normal Notes middle-of-line text")
    func doesNotRepairUnprovenContexts() {
        let policy = TextContextRepairPolicy()

        let chrome = policy.repair(TextContextRepairInput(
            bundleIdentifier: "com.google.Chrome",
            role: "AXTextArea",
            textBeforeCursor: "",
            textAfterCursor: "Smoke proof feels inst",
            selectedTextLength: 0,
            previousTextBeforeCursor: "",
            previousTextAfterCursor: ""
        ))
        #expect(!chrome.wasRepaired)

        let normalNotesMiddle = policy.repair(TextContextRepairInput(
            bundleIdentifier: "com.apple.Notes",
            role: "AXTextArea",
            textBeforeCursor: "Smoke proof ",
            textAfterCursor: "feels instant",
            selectedTextLength: 0,
            previousTextBeforeCursor: "Smoke proof ",
            previousTextAfterCursor: "feels instant"
        ))
        #expect(!normalNotesMiddle.wasRepaired)
    }

    @Test("Does not repair when the user selected text")
    func doesNotRepairSelectedText() {
        let policy = TextContextRepairPolicy()

        let result = policy.repair(TextContextRepairInput(
            bundleIdentifier: "com.apple.Notes",
            role: "AXTextArea",
            textBeforeCursor: "",
            textAfterCursor: "Smoke proof feels inst",
            selectedTextLength: 5,
            previousTextBeforeCursor: "",
            previousTextAfterCursor: ""
        ))

        #expect(!result.wasRepaired)
    }
}
