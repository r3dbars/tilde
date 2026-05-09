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

    @Test("Repairs Chrome CodeMirror trailing character cursor drift only for CodeMirror fingerprints")
    func repairsChromeCodeMirrorTrailingCharacter() {
        let policy = TextContextRepairPolicy()

        let result = policy.repair(TextContextRepairInput(
            bundleIdentifier: "com.google.Chrome",
            role: "AXTextArea",
            textBeforeCursor: "Smoke proof feels dict",
            textAfterCursor: "a",
            selectedTextLength: 0,
            fingerprintText: "Try CodeMirror"
        ))

        #expect(result.textBeforeCursor == "Smoke proof feels dicta")
        #expect(result.textAfterCursor == "")
        #expect(result.reason == .chromeCodeMirrorTrailingCharacter)

        let normalChrome = policy.repair(TextContextRepairInput(
            bundleIdentifier: "com.google.Chrome",
            role: "AXTextArea",
            textBeforeCursor: "Smoke proof feels dict",
            textAfterCursor: "a",
            selectedTextLength: 0,
            fingerprintText: "Regular textarea"
        ))
        #expect(!normalChrome.wasRepaired)
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

    @Test("Repairs Obsidian CodeMirror line drift after the first typed character")
    func repairsObsidianCodeMirrorLineDriftAfterFirstCharacter() {
        let policy = TextContextRepairPolicy()

        let result = policy.repair(TextContextRepairInput(
            bundleIdentifier: "md.obsidian",
            role: "AXTextArea",
            textBeforeCursor: "S",
            textAfterCursor: "moke proof feels",
            selectedTextLength: 0
        ))

        #expect(result.textBeforeCursor == "Smoke proof feels")
        #expect(result.textAfterCursor == "")
        #expect(result.reason == .obsidianCodeMirrorLineDrift)
    }

    @Test("Repairs Obsidian CodeMirror hidden spacer drift before the visible line")
    func repairsObsidianCodeMirrorHiddenSpacerLine() {
        let policy = TextContextRepairPolicy()
        let hiddenSpacer = "\u{200B}\t\n\u{200B}\t\n\u{200B}\t\n\u{200B}\t\n"

        let result = policy.repair(TextContextRepairInput(
            bundleIdentifier: "md.obsidian",
            role: "AXTextArea",
            textBeforeCursor: "Earlier proof line\n",
            textAfterCursor: hiddenSpacer + "Smoke proof feels inst",
            selectedTextLength: 0
        ))

        #expect(result.textBeforeCursor == "Earlier proof line\nSmoke proof feels inst")
        #expect(result.textAfterCursor == "")
        #expect(result.reason == .obsidianCodeMirrorHiddenSpacerLine)
    }

    @Test("Repairs Obsidian CodeMirror stale previous line before the active typed line")
    func repairsObsidianCodeMirrorStalePreviousLine() {
        let policy = TextContextRepairPolicy()

        let result = policy.repair(TextContextRepairInput(
            bundleIdentifier: "md.obsidian",
            role: "AXTextArea",
            textBeforeCursor: "Autocomplete Lab Obsidian p",
            textAfterCursor: "roof\nSmoke proof feels",
            selectedTextLength: 0
        ))

        #expect(result.textBeforeCursor == "Autocomplete Lab Obsidian proof\nSmoke proof feels")
        #expect(result.textAfterCursor == "")
        #expect(result.reason == .obsidianCodeMirrorStalePreviousLine)
    }

    @Test("Repairs Obsidian CodeMirror selected-range drift after typing at the visual end")
    func repairsObsidianCodeMirrorTextAfterGrowth() {
        let policy = TextContextRepairPolicy()
        let before = [
            "Autocomplete Lab Obsidian scroll filler line 89",
            "Autocomplete Lab Obsidian scroll filler line 90",
            "Autocomplete Lab Obsidian scroll ta"
        ].joined(separator: "\n")

        let result = policy.repair(TextContextRepairInput(
            bundleIdentifier: "md.obsidian",
            role: "AXTextArea",
            textBeforeCursor: before,
            textAfterCursor: "rgetSmoke proof feels",
            selectedTextLength: 0,
            previousTextBeforeCursor: before,
            previousTextAfterCursor: "rget"
        ))

        #expect(result.textBeforeCursor == before + "rgetSmoke proof feels")
        #expect(result.textAfterCursor == "")
        #expect(result.reason == .obsidianCodeMirrorTextAfterGrowth)
    }

    @Test("Repairs Obsidian CodeMirror selected range that advances only into the typed prefix")
    func repairsObsidianCodeMirrorTextAfterGrowthFromPreviousLineEnd() {
        let policy = TextContextRepairPolicy()
        let before = [
            "Autocomplete Lab Obsidian scroll filler line 90",
            "Autocomplete Lab Obsidian proof",
            "Autocomplete Lab Obsidian scroll target"
        ].joined(separator: "\n")

        let result = policy.repair(TextContextRepairInput(
            bundleIdentifier: "md.obsidian",
            role: "AXTextArea",
            textBeforeCursor: before + "S",
            textAfterCursor: "moke proof feels",
            selectedTextLength: 0,
            previousTextBeforeCursor: before,
            previousTextAfterCursor: ""
        ))

        #expect(result.textBeforeCursor == before + "Smoke proof feels")
        #expect(result.textAfterCursor == "")
        #expect(result.reason == .obsidianCodeMirrorTextAfterGrowth)
    }

    @Test("Repairs Obsidian CodeMirror trailing scaffold drift at visual line end")
    func repairsObsidianCodeMirrorTrailingScaffolding() {
        let policy = TextContextRepairPolicy()

        let result = policy.repair(TextContextRepairInput(
            bundleIdentifier: "md.obsidian",
            role: "AXTextArea",
            textBeforeCursor: "Smoke proof feels instan",
            textAfterCursor: "\u{200B}\t\n\u{FFFC}",
            selectedTextLength: 0
        ))

        #expect(result.textBeforeCursor == "Smoke proof feels instan")
        #expect(result.textAfterCursor == "")
        #expect(result.reason == .obsidianCodeMirrorTrailingScaffolding)
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

        let hiddenSpacerBeforeMiddleText = policy.repair(TextContextRepairInput(
            bundleIdentifier: "md.obsidian",
            role: "AXTextArea",
            textBeforeCursor: "Smoke proof ",
            textAfterCursor: "\u{200B}\t\nfeels instant",
            selectedTextLength: 0
        ))
        #expect(!hiddenSpacerBeforeMiddleText.wasRepaired)

        let plainTrailingSpaces = policy.repair(TextContextRepairInput(
            bundleIdentifier: "md.obsidian",
            role: "AXTextArea",
            textBeforeCursor: "Smoke proof feels instan",
            textAfterCursor: "   ",
            selectedTextLength: 0
        ))
        #expect(!plainTrailingSpaces.wasRepaired)

        let stalePreviousLineWithoutActiveTyping = policy.repair(TextContextRepairInput(
            bundleIdentifier: "md.obsidian",
            role: "AXTextArea",
            textBeforeCursor: "Autocomplete Lab Obsidian p",
            textAfterCursor: "roof\nshort",
            selectedTextLength: 0
        ))
        #expect(!stalePreviousLineWithoutActiveTyping.wasRepaired)

        let unchangedMiddle = policy.repair(TextContextRepairInput(
            bundleIdentifier: "md.obsidian",
            role: "AXTextArea",
            textBeforeCursor: "Smoke proof ",
            textAfterCursor: "feels instant",
            selectedTextLength: 0,
            previousTextBeforeCursor: "Smoke proof ",
            previousTextAfterCursor: "feels instant"
        ))
        #expect(!unchangedMiddle.wasRepaired)
    }
}
