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

    @Test("Repairs Obsidian CodeMirror trailing character cursor drift")
    func repairsObsidianCodeMirrorTrailingCharacter() {
        let policy = TextContextRepairPolicy()

        let result = policy.repair(TextContextRepairInput(
            bundleIdentifier: "md.obsidian",
            role: "AXTextArea",
            textBeforeCursor: "Smoke proof feels inst",
            textAfterCursor: "a",
            selectedTextLength: 0
        ))

        #expect(result.textBeforeCursor == "Smoke proof feels insta")
        #expect(result.textAfterCursor == "")
        #expect(result.reason == .obsidianCodeMirrorTrailingCharacter)
    }

    @Test("Repairs Obsidian CodeMirror line drift at the visual line end")
    func repairsObsidianCodeMirrorLineDrift() {
        let policy = TextContextRepairPolicy()

        let result = policy.repair(TextContextRepairInput(
            bundleIdentifier: "md.obsidian",
            role: "AXTextArea",
            textBeforeCursor: "Smoke proof feels instant\nSmok",
            textAfterCursor: "e proof feels inst",
            selectedTextLength: 0
        ))

        #expect(result.textBeforeCursor == "Smoke proof feels instant\nSmoke proof feels inst")
        #expect(result.textAfterCursor == "")
        #expect(result.reason == .obsidianCodeMirrorLineDrift)
    }

    @Test("Does not repair broad Obsidian middle-of-line text")
    func doesNotRepairBroadObsidianMiddleOfLineText() {
        let policy = TextContextRepairPolicy()

        let multiCharacterAfter = policy.repair(TextContextRepairInput(
            bundleIdentifier: "md.obsidian",
            role: "AXTextArea",
            textBeforeCursor: "Smoke proof feels inst",
            textAfterCursor: "ant",
            selectedTextLength: 0
        ))
        #expect(!multiCharacterAfter.wasRepaired)

        let selectedText = policy.repair(TextContextRepairInput(
            bundleIdentifier: "md.obsidian",
            role: "AXTextArea",
            textBeforeCursor: "Smoke proof feels inst",
            textAfterCursor: "a",
            selectedTextLength: 1
        ))
        #expect(!selectedText.wasRepaired)

        let unrelatedApp = policy.repair(TextContextRepairInput(
            bundleIdentifier: "com.google.Chrome",
            role: "AXTextArea",
            textBeforeCursor: "Smoke proof feels inst",
            textAfterCursor: "a",
            selectedTextLength: 0
        ))
        #expect(!unrelatedApp.wasRepaired)

        let broadMiddle = policy.repair(TextContextRepairInput(
            bundleIdentifier: "md.obsidian",
            role: "AXTextArea",
            textBeforeCursor: "Smoke proof",
            textAfterCursor: " feels instant",
            selectedTextLength: 0
        ))
        #expect(!broadMiddle.wasRepaired)
    }
}
