import Foundation
import Testing
@testable import AutocompleteLabCore

struct ObsidianProofDocumentInsertionPlannerTests {
    @Test("Proof document planner appends accepted text after visible scrolled tail")
    func appendsAcceptedTextAfterVisibleTail() {
        let hiddenPrefix = (1...75)
            .map { String(format: "Autocomplete Lab Obsidian scroll filler line %02d", $0) }
            .joined(separator: "\n") + "\n"
        let visibleTail = (76...90)
            .map { String(format: "Autocomplete Lab Obsidian scroll filler line %02d", $0) }
            .joined(separator: "\n") + "\nAutocomplete Lab Obsidian proof\nSmoke proof feels instant and stays"
        let proofDocument = hiddenPrefix + visibleTail

        let plan = ObsidianProofDocumentInsertionPlanner().plan(
            proofDocumentText: proofDocument,
            textBeforeCursor: visibleTail,
            textAfterCursor: "",
            acceptedText: " instant"
        )

        #expect(plan?.replacementText == proofDocument + " instant")
        #expect(plan?.cursorUTF16Offset == (proofDocument + " instant").utf16.count)
        #expect(plan?.matchSource == "proofDocumentVisibleTail")
    }

    @Test("Proof document planner can recover when only the visible tail suffix matches")
    func recoversFromVisibleTailSuffix() {
        let visibleTail = "Autocomplete Lab Obsidian proof\nSmoke proof feels instant and stays"
        let proofDocument = "Hidden line\n" + visibleTail

        let plan = ObsidianProofDocumentInsertionPlanner().plan(
            proofDocumentText: proofDocument,
            textBeforeCursor: visibleTail,
            textAfterCursor: "",
            acceptedText: " instant"
        )

        #expect(plan?.replacementText == proofDocument + " instant")
        #expect(plan?.cursorUTF16Offset == (proofDocument + " instant").utf16.count)
        #expect(plan?.matchSource == "proofDocumentVisibleTail")
    }

    @Test("Proof document planner refuses non-proof text")
    func refusesNonProofText() {
        let plan = ObsidianProofDocumentInsertionPlanner().plan(
            proofDocumentText: "Hidden line\nSmoke proof feels instant and stays",
            textBeforeCursor: "Smoke proof feels instant and stays",
            textAfterCursor: "",
            acceptedText: " instant"
        )

        #expect(plan == nil)
    }
}
