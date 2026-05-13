import Testing
@testable import AutocompleteLabCore

@Suite("Obsidian Tab passthrough repair")
struct ObsidianTabPassthroughRepairPolicyTests {
    private let policy = ObsidianTabPassthroughRepairPolicy()

    @Test("Repairs when Tab indents the current line while a suggestion is visible")
    func repairsLeadingTabIndent() {
        let decision = policy.decision(
            previousTextBeforeCursor: "Autocomplete Lab Obsidian proof\nSmoke proof fee",
            currentTextBeforeCursor: "Autocomplete Lab Obsidian proof\n\tSmoke proof fee",
            previousTextAfterCursor: "",
            currentTextAfterCursor: "",
            hasVisibleSuggestion: true,
            acceptedText: "l"
        )

        #expect(decision == .repair)
    }

    @Test("Repairs Obsidian CodeMirror tab spacer drift")
    func repairsCodeMirrorTabSpacerDrift() {
        let decision = policy.decision(
            previousTextBeforeCursor: "Autocomplete Lab Obsidian proof\nSmoke proof fee",
            currentTextBeforeCursor: "\u{200B}\n\u{200B}\n\nAutocomplete Lab Obsidian proof\n\u{200B}\t\nSmoke proof fee",
            previousTextAfterCursor: "",
            currentTextAfterCursor: "",
            hasVisibleSuggestion: true,
            acceptedText: "l"
        )

        #expect(decision == .repair)
    }

    @Test("Repairs when Obsidian moves the AX cursor into the indented line")
    func repairsLeadingTabIndentWhenTextAfterCursorChanges() {
        let decision = policy.decision(
            previousTextBeforeCursor: "Autocomplete Lab Obsidian proof\nSmoke proof feels inst",
            currentTextBeforeCursor: "Autocomplete Lab Obsidian proof\n\tSmoke proof fee",
            previousTextAfterCursor: "",
            currentTextAfterCursor: "ls inst",
            hasVisibleSuggestion: true,
            acceptedText: "ant"
        )

        #expect(decision == .repair)
    }

    @Test("Repairs CodeMirror tab spacer when Obsidian moves the AX cursor into the line")
    func repairsCodeMirrorTabSpacerWhenTextAfterCursorChanges() {
        let decision = policy.decision(
            previousTextBeforeCursor: "Autocomplete Lab Obsidian proof\nSmoke proof feels inst",
            currentTextBeforeCursor: "\u{200B}\n\u{200B}\n\nAutocomplete Lab Obsidian proof\n\u{200B}\t\nSmoke proof fee",
            previousTextAfterCursor: "",
            currentTextAfterCursor: "ls inst",
            hasVisibleSuggestion: true,
            acceptedText: "ant"
        )

        #expect(decision == .repair)
    }

    @Test("Repairs when Obsidian selects the indented current line after Tab")
    func repairsSelectedLineIndent() {
        let decision = policy.decision(
            previousTextBeforeCursor: "Autocomplete Lab Obsidian proof\nSmoke proof fee",
            currentTextBeforeCursor: "Autocomplete Lab Obsidian proof\n\t",
            previousTextAfterCursor: "",
            currentTextAfterCursor: "Smoke proof fee",
            currentSelectedText: "Smoke proof fee",
            hasVisibleSuggestion: true,
            acceptedText: "l"
        )

        #expect(decision == .repair)
    }

    @Test("Repairs selected-line Obsidian CodeMirror spacer drift")
    func repairsSelectedLineCodeMirrorSpacerDrift() {
        let decision = policy.decision(
            previousTextBeforeCursor: "Autocomplete Lab Obsidian proof\nSmoke proof fee",
            currentTextBeforeCursor: "\u{200B}\n\u{200B}\n\nAutocomplete Lab Obsidian proof\n\u{200B}\t\n",
            previousTextAfterCursor: "",
            currentTextAfterCursor: "Smoke proof fee",
            currentSelectedText: "Smoke proof fee",
            hasVisibleSuggestion: true,
            acceptedText: "l"
        )

        #expect(decision == .repair)
    }

    @Test("Skips when there is no visible suggestion")
    func skipsWithoutVisibleSuggestion() {
        let decision = policy.decision(
            previousTextBeforeCursor: "Smoke proof fee",
            currentTextBeforeCursor: "\tSmoke proof fee",
            previousTextAfterCursor: "",
            currentTextAfterCursor: "",
            hasVisibleSuggestion: false,
            acceptedText: "l"
        )

        #expect(decision == .skip("no-visible-suggestion"))
    }

    @Test("Skips unrelated text mutations")
    func skipsUnrelatedMutations() {
        let decision = policy.decision(
            previousTextBeforeCursor: "Smoke proof fee",
            currentTextBeforeCursor: "Smoke proof feel",
            previousTextAfterCursor: "",
            currentTextAfterCursor: "",
            hasVisibleSuggestion: true,
            acceptedText: "l"
        )

        #expect(decision == .skip("not-leading-tab-indent"))
    }
}
