import Foundation
import AutocompleteLabCore

public struct ObsidianProofDocumentInsertionPlan: Equatable, Sendable {
    public let replacementText: String
    public let cursorUTF16Offset: Int
    public let matchSource: String

    public init(replacementText: String, cursorUTF16Offset: Int, matchSource: String) {
        self.replacementText = replacementText
        self.cursorUTF16Offset = cursorUTF16Offset
        self.matchSource = matchSource
    }
}

public struct ObsidianProofDocumentInsertionPlanner: Equatable, Sendable {
    public init() {}

    public func plan(
        proofDocumentText: String,
        textBeforeCursor: String,
        textAfterCursor: String,
        acceptedText: String,
        marker: String = "Autocomplete Lab Obsidian proof"
    ) -> ObsidianProofDocumentInsertionPlan? {
        guard !proofDocumentText.isEmpty,
              !textBeforeCursor.isEmpty,
              !acceptedText.isEmpty,
              proofDocumentText.localizedCaseInsensitiveContains(marker) else {
            return nil
        }

        let previousText = textBeforeCursor + textAfterCursor
        let replacementSlice = textBeforeCursor + acceptedText + textAfterCursor
        if textAfterCursor.isEmpty,
           proofDocumentText.hasSuffix(textBeforeCursor) {
            return ObsidianProofDocumentInsertionPlan(
                replacementText: proofDocumentText + acceptedText,
                cursorUTF16Offset: proofDocumentText.utf16.count + acceptedText.utf16.count,
                matchSource: "proofDocumentVisibleTail"
            )
        }

        if let exactRange = proofDocumentText.range(of: previousText, options: .backwards) {
            let replacementText = proofDocumentText.replacingCharacters(
                in: exactRange,
                with: replacementSlice
            )
            let cursorUTF16Offset = proofDocumentText[..<exactRange.lowerBound].utf16.count
                + textBeforeCursor.utf16.count
                + acceptedText.utf16.count
            return ObsidianProofDocumentInsertionPlan(
                replacementText: replacementText,
                cursorUTF16Offset: cursorUTF16Offset,
                matchSource: "proofDocumentExact"
            )
        }
        return nil
    }
}
