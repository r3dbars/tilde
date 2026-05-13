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

    @Test("Repairs Obsidian CodeMirror line drift with trailing newline noise")
    func repairsObsidianCodeMirrorLineDriftWithTrailingNewlineNoise() {
        let policy = TextContextRepairPolicy()

        let result = policy.repair(TextContextRepairInput(
            bundleIdentifier: "md.obsidian",
            role: "AXTextArea",
            textBeforeCursor: "Autocomplete Lab Obsidian proof\nSmoke proo",
            textAfterCursor: "f feels inst\n",
            selectedTextLength: 0
        ))

        #expect(result.textBeforeCursor == "Autocomplete Lab Obsidian proof\nSmoke proof feels inst")
        #expect(result.textAfterCursor == "")
        #expect(result.reason == .obsidianCodeMirrorLineDrift)
    }

    @Test("Repairs Obsidian CodeMirror active line reported after the AX cursor")
    func repairsObsidianCodeMirrorTextAfterActiveLine() {
        let policy = TextContextRepairPolicy()

        let result = policy.repair(TextContextRepairInput(
            bundleIdentifier: "md.obsidian",
            role: "AXTextArea",
            textBeforeCursor: "AL scroll 45\nAutocomplete Lab Obsidian proof",
            textAfterCursor: "Smoke proof feels",
            selectedTextLength: 0
        ))

        #expect(result.textBeforeCursor == "AL scroll 45\nAutocomplete Lab Obsidian proof\nSmoke proof feels")
        #expect(result.textAfterCursor == "")
        #expect(result.reason == .obsidianCodeMirrorTextAfterActiveLine)
    }

    @Test("Does not repair Obsidian after-cursor active line when later content is on another line")
    func doesNotRepairObsidianTextAfterActiveLineWithMoreDocumentContent() {
        let policy = TextContextRepairPolicy()

        let result = policy.repair(TextContextRepairInput(
            bundleIdentifier: "md.obsidian",
            role: "AXTextArea",
            textBeforeCursor: "AL scroll 45\nAutocomplete Lab Obsidian proof",
            textAfterCursor: "Smoke proof feels\nExisting note content",
            selectedTextLength: 0
        ))

        #expect(!result.wasRepaired)
    }

    @Test("Repairs Obsidian CodeMirror leading word drift in a long note")
    func repairsObsidianCodeMirrorLeadingWordDrift() {
        let policy = TextContextRepairPolicy()

        let result = policy.repair(TextContextRepairInput(
            bundleIdentifier: "md.obsidian",
            role: "AXTextArea",
            textBeforeCursor: "AL scroll 44\nSmoke proof",
            textAfterCursor: " stays\nAutocomplete Lab Obsidian proof",
            selectedTextLength: 0
        ))

        #expect(result.textBeforeCursor == "AL scroll 44\nSmoke proof stays")
        #expect(result.textAfterCursor == "\nAutocomplete Lab Obsidian proof")
        #expect(result.reason == .obsidianCodeMirrorLeadingWordDrift)
    }

    @Test("Does not repair Obsidian leading word drift when more same-line text remains")
    func doesNotRepairObsidianLeadingWordInRealMiddleOfLine() {
        let policy = TextContextRepairPolicy()

        let result = policy.repair(TextContextRepairInput(
            bundleIdentifier: "md.obsidian",
            role: "AXTextArea",
            textBeforeCursor: "Smoke proof",
            textAfterCursor: " stays in the middle",
            selectedTextLength: 0
        ))

        #expect(!result.wasRepaired)
    }

    @Test("Repairs Obsidian viewport tail line when AX stays in the previous visible line")
    func repairsObsidianViewportTailLineWithoutNumberedAnchor() {
        let policy = TextContextRepairPolicy()
        let beforeCursor = (80...90)
            .map { "Autocomplete Lab Obsidian scroll filler line \($0)" }
            .joined(separator: "\n")
            + "\nAutocomplete Lab Obs"
        let afterCursor = "idian proof\nSmoke proof feels inst\n"

        let result = policy.repair(TextContextRepairInput(
            bundleIdentifier: "md.obsidian",
            role: "AXTextArea",
            textBeforeCursor: beforeCursor,
            textAfterCursor: afterCursor,
            selectedTextLength: 0
        ))

        #expect(result.textBeforeCursor == beforeCursor + afterCursor)
        #expect(result.textAfterCursor == "")
        #expect(result.reason == .obsidianCodeMirrorViewportTailLine)
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

    @Test("Repairs Obsidian CodeMirror typing growth reported after a stable cursor")
    func repairsObsidianCodeMirrorTextAfterTypingGrowth() {
        let policy = TextContextRepairPolicy()
        let before = "Smoke proof"

        let result = policy.repair(TextContextRepairInput(
            bundleIdentifier: "md.obsidian",
            role: "AXTextArea",
            textBeforeCursor: before,
            textAfterCursor: " feels inst",
            selectedTextLength: 0,
            previousTextBeforeCursor: before,
            previousTextAfterCursor: ""
        ))

        #expect(result.textBeforeCursor == "Smoke proof feels inst")
        #expect(result.textAfterCursor == "")
        #expect(result.reason == .obsidianCodeMirrorTextAfterTypingGrowth)
    }

    @Test("Repairs Obsidian long-note active line reported after the prior line")
    func repairsObsidianCodeMirrorLongNoteActiveLineAfterStableCursor() {
        let policy = TextContextRepairPolicy()
        let before = [
            "Autocomplete Lab Obsidian scroll filler line 90",
            "AL scroll 45"
        ].joined(separator: "\n")

        let result = policy.repair(TextContextRepairInput(
            bundleIdentifier: "md.obsidian",
            role: "AXTextArea",
            textBeforeCursor: before,
            textAfterCursor: "Smoke proof feels inst",
            selectedTextLength: 0,
            previousTextBeforeCursor: before,
            previousTextAfterCursor: ""
        ))

        #expect(result.textBeforeCursor == before + "\nSmoke proof feels inst")
        #expect(result.textAfterCursor == "")
        #expect(result.reason == .obsidianCodeMirrorTextAfterTypingGrowth)
    }

    @Test("Does not repair Obsidian typing growth when later content remains")
    func doesNotRepairObsidianTextAfterTypingGrowthWithLaterContent() {
        let policy = TextContextRepairPolicy()
        let before = "Smoke proof"

        let result = policy.repair(TextContextRepairInput(
            bundleIdentifier: "md.obsidian",
            role: "AXTextArea",
            textBeforeCursor: before,
            textAfterCursor: " feels inst\nExisting note content",
            selectedTextLength: 0,
            previousTextBeforeCursor: before,
            previousTextAfterCursor: ""
        ))

        #expect(!result.wasRepaired)
    }

    @Test("Repairs Obsidian CodeMirror stale cursor after end-of-document growth")
    func repairsObsidianCodeMirrorEndOfDocumentGrowth() {
        let policy = TextContextRepairPolicy()
        let previous = [
            "Autocomplete Lab Obsidian scroll filler line 89",
            "Autocomplete Lab Obsidian scroll filler line 90",
            "Autocomplete Lab Obsidian proof",
            "Smoke proof feels instant"
        ].joined(separator: "\n")
        let current = previous + " and stays inst"
        let staleBefore = [
            "Autocomplete Lab Obsidian scroll filler line 89",
            "Autocomplete Lab Obsidian scroll filler line 90"
        ].joined(separator: "\n")
        let staleAfter = String(current.dropFirst(staleBefore.count))

        let result = policy.repair(TextContextRepairInput(
            bundleIdentifier: "md.obsidian",
            role: "AXTextArea",
            textBeforeCursor: staleBefore,
            textAfterCursor: staleAfter,
            selectedTextLength: 0,
            previousTextBeforeCursor: previous,
            previousTextAfterCursor: ""
        ))

        #expect(result.textBeforeCursor == current)
        #expect(result.textAfterCursor == "")
        #expect(result.reason == .obsidianCodeMirrorEndOfDocumentGrowth)
    }

    @Test("Repairs Obsidian end-of-document typing drift inside the new suffix")
    func repairsObsidianEndOfDocumentTypingDriftInsideNewSuffix() {
        let policy = TextContextRepairPolicy()
        let previous = [
            "Autocomplete Lab Obsidian scroll filler line 89",
            "Autocomplete Lab Obsidian scroll filler line 90",
            "Autocomplete Lab Obsidian proof",
            ""
        ].joined(separator: "\n")
        let current = previous + "Smoke proof feels inst"
        let staleBefore = previous + "Smoke proo"
        let staleAfter = "f feels inst"

        let result = policy.repair(TextContextRepairInput(
            bundleIdentifier: "md.obsidian",
            role: "AXTextArea",
            textBeforeCursor: staleBefore,
            textAfterCursor: staleAfter,
            selectedTextLength: 0,
            previousTextBeforeCursor: previous,
            previousTextAfterCursor: ""
        ))

        #expect(result.textBeforeCursor == current)
        #expect(result.textAfterCursor == "")
        #expect(result.reason == .obsidianCodeMirrorEndOfDocumentTypingDrift)
    }

    @Test("Repairs Obsidian CodeMirror capped end-of-document text window")
    func repairsObsidianCodeMirrorCappedEndOfDocumentGrowth() {
        let policy = TextContextRepairPolicy()
        let previousHead = (1...18)
            .map { "Autocomplete Lab Obsidian scroll filler line \($0)" }
            .joined(separator: "\n")
        let overlappingTail = [
            "Autocomplete Lab Obsidian scroll filler line 89",
            "Autocomplete Lab Obsidian scroll filler line 90",
            "Autocomplete Lab Obsidian proof",
            "Smoke proof feels instant"
        ].joined(separator: "\n")
        let previous = previousHead + "\n" + overlappingTail
        let cappedWindow = overlappingTail + " and stays inst"
        let staleBefore = String(cappedWindow.prefix(11))
        let staleAfter = String(cappedWindow.dropFirst(staleBefore.count))

        let result = policy.repair(TextContextRepairInput(
            bundleIdentifier: "md.obsidian",
            role: "AXTextArea",
            textBeforeCursor: staleBefore,
            textAfterCursor: staleAfter,
            selectedTextLength: 0,
            previousTextBeforeCursor: previous,
            previousTextAfterCursor: ""
        ))

        #expect(result.textBeforeCursor == cappedWindow)
        #expect(result.textAfterCursor == "")
        #expect(result.reason == .obsidianCodeMirrorEndOfDocumentGrowth)
    }

    @Test("Repairs Obsidian CodeMirror viewport cursor drift at the document end")
    func repairsObsidianCodeMirrorViewportEndOfDocumentDrift() {
        let policy = TextContextRepairPolicy()
        let previousLines = (1...89)
            .map { "Autocomplete Lab Obsidian scroll filler line \($0)" }
            .joined(separator: "\n")
        let textBefore = previousLines + "\nAutoc"
        let textAfter = [
            "omplete Lab Obsidian scroll filler line 90",
            "Autocomplete Lab Obsidian proof",
            "Smoke proof feels"
        ].joined(separator: "\n")
        let currentText = textBefore + textAfter

        let result = policy.repair(TextContextRepairInput(
            bundleIdentifier: "md.obsidian",
            role: "AXTextArea",
            textBeforeCursor: textBefore,
            textAfterCursor: textAfter,
            selectedTextLength: 0
        ))

        #expect(result.textBeforeCursor == currentText)
        #expect(result.textAfterCursor == "")
        #expect(result.reason == .obsidianCodeMirrorViewportEndOfDocument)
    }

    @Test("Does not repair Obsidian viewport drift without a numbered stale line")
    func doesNotRepairObsidianViewportDriftWithoutNumberedLine() {
        let policy = TextContextRepairPolicy()
        let previousLines = (1...20)
            .map { "Long Obsidian paragraph with enough words for context \($0)" }
            .joined(separator: "\n")
        let textBefore = previousLines + "\nDraft"
        let textAfter = [
            " idea",
            "Another note section",
            "Smoke proof feels"
        ].joined(separator: "\n")

        let result = policy.repair(TextContextRepairInput(
            bundleIdentifier: "md.obsidian",
            role: "AXTextArea",
            textBeforeCursor: textBefore,
            textAfterCursor: textAfter,
            selectedTextLength: 0
        ))

        #expect(!result.wasRepaired)
    }

    @Test("Does not repair Obsidian capped window without document-end overlap")
    func doesNotRepairObsidianCappedEndOfDocumentGrowthWithoutOverlap() {
        let policy = TextContextRepairPolicy()
        let previous = (1...18)
            .map { "Autocomplete Lab Obsidian scroll filler line \($0)" }
            .joined(separator: "\n") + "\nSmoke proof feels instant"
        let cappedWindow = [
            "Different Obsidian scroll filler line 89",
            "Different Obsidian scroll filler line 90",
            "Different Obsidian proof",
            "Smoke proof feels instant and stays inst"
        ].joined(separator: "\n")
        let staleBefore = String(cappedWindow.prefix(11))
        let staleAfter = String(cappedWindow.dropFirst(staleBefore.count))

        let result = policy.repair(TextContextRepairInput(
            bundleIdentifier: "md.obsidian",
            role: "AXTextArea",
            textBeforeCursor: staleBefore,
            textAfterCursor: staleAfter,
            selectedTextLength: 0,
            previousTextBeforeCursor: previous,
            previousTextAfterCursor: ""
        ))

        #expect(!result.wasRepaired)
    }

    @Test("Does not repair Obsidian capped window without new document-end growth")
    func doesNotRepairObsidianCappedEndOfDocumentGrowthWithoutGrowth() {
        let policy = TextContextRepairPolicy()
        let previousHead = (1...18)
            .map { "Autocomplete Lab Obsidian scroll filler line \($0)" }
            .joined(separator: "\n")
        let overlappingTail = [
            "Autocomplete Lab Obsidian scroll filler line 89",
            "Autocomplete Lab Obsidian scroll filler line 90",
            "Autocomplete Lab Obsidian proof",
            "Smoke proof feels instant"
        ].joined(separator: "\n")
        let previous = previousHead + "\n" + overlappingTail
        let staleBefore = String(overlappingTail.prefix(11))
        let staleAfter = String(overlappingTail.dropFirst(staleBefore.count))

        let result = policy.repair(TextContextRepairInput(
            bundleIdentifier: "md.obsidian",
            role: "AXTextArea",
            textBeforeCursor: staleBefore,
            textAfterCursor: staleAfter,
            selectedTextLength: 0,
            previousTextBeforeCursor: previous,
            previousTextAfterCursor: ""
        ))

        #expect(!result.wasRepaired)
    }

    @Test("Does not repair Obsidian stale cursor when prior snapshot was not at document end")
    func doesNotRepairObsidianEndOfDocumentGrowthWithPreviousAfterText() {
        let policy = TextContextRepairPolicy()
        let previousBefore = "Draft section"

        let result = policy.repair(TextContextRepairInput(
            bundleIdentifier: "md.obsidian",
            role: "AXTextArea",
            textBeforeCursor: "Draft",
            textAfterCursor: " section\nSmoke proof feels instant",
            selectedTextLength: 0,
            previousTextBeforeCursor: previousBefore,
            previousTextAfterCursor: "\nExisting later note"
        ))

        #expect(!result.wasRepaired)
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

    @Test("Repairs official Chrome CodeMirror trailing scaffold drift")
    func repairsChromeCodeMirrorTrailingScaffolding() {
        let policy = TextContextRepairPolicy()

        let result = policy.repair(TextContextRepairInput(
            bundleIdentifier: "com.google.Chrome",
            role: "AXTextArea",
            textBeforeCursor: "Smoke proof feels inst",
            textAfterCursor: "\u{200B}\n",
            selectedTextLength: 0,
            windowTitle: "Try CodeMirror"
        ))

        #expect(result.textBeforeCursor == "Smoke proof feels inst")
        #expect(result.textAfterCursor == "")
        #expect(result.reason == .chromeCodeMirrorTrailingScaffolding)
    }

    @Test("Repairs official Chrome CodeMirror soft-wrap cursor offset")
    func repairsChromeCodeMirrorSoftWrapCursorOffset() {
        let policy = TextContextRepairPolicy()

        let result = policy.repair(TextContextRepairInput(
            bundleIdentifier: "com.google.Chrome",
            role: "AXTextArea",
            textBeforeCursor: "Smoke \n\nproof feels in",
            textAfterCursor: "st",
            selectedTextLength: 0,
            windowTitle: "Try CodeMirror"
        ))

        #expect(result.textBeforeCursor == "Smoke proof feels inst")
        #expect(result.textAfterCursor == "")
        #expect(result.reason == .chromeCodeMirrorSoftWrapCursor)
    }

    @Test("Does not repair Chrome CodeMirror scaffolding outside the official CodeMirror page")
    func doesNotRepairChromeCodeMirrorScaffoldingWithoutTitleProof() {
        let policy = TextContextRepairPolicy()

        let result = policy.repair(TextContextRepairInput(
            bundleIdentifier: "com.google.Chrome",
            role: "AXTextArea",
            textBeforeCursor: "Smoke proof feels inst",
            textAfterCursor: "\u{200B}\n",
            selectedTextLength: 0,
            windowTitle: "Untitled form"
        ))

        #expect(!result.wasRepaired)

        let softWrap = policy.repair(TextContextRepairInput(
            bundleIdentifier: "com.google.Chrome",
            role: "AXTextArea",
            textBeforeCursor: "Smoke \n\nproof feels in",
            textAfterCursor: "st",
            selectedTextLength: 0,
            windowTitle: "Untitled form"
        ))

        #expect(!softWrap.wasRepaired)
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
