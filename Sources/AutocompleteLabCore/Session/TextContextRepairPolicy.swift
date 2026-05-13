import Foundation

public enum TextContextRepairReason: String, Equatable, Sendable {
    case notesTextAfterCursorTyping = "notes-text-after-cursor-typing"
    case notesTextAfterCursorStable = "notes-text-after-cursor-stable"
    case obsidianCodeMirrorTrailingCharacter = "obsidian-codemirror-trailing-character"
    case obsidianCodeMirrorTrailingScaffolding = "obsidian-codemirror-trailing-scaffolding"
    case obsidianCodeMirrorHiddenSpacerLine = "obsidian-codemirror-hidden-spacer-line"
    case obsidianCodeMirrorStalePreviousLine = "obsidian-codemirror-stale-previous-line"
    case obsidianCodeMirrorTextAfterGrowth = "obsidian-codemirror-text-after-growth"
    case obsidianCodeMirrorEndOfDocumentGrowth = "obsidian-codemirror-end-of-document-growth"
    case obsidianCodeMirrorEndOfDocumentTypingDrift = "obsidian-codemirror-end-of-document-typing-drift"
    case obsidianCodeMirrorViewportEndOfDocument = "obsidian-codemirror-viewport-end-of-document"
    case obsidianCodeMirrorViewportTailLine = "obsidian-codemirror-viewport-tail-line"
    case obsidianCodeMirrorShortDocumentStructureTail = "obsidian-codemirror-short-document-structure-tail"
    case obsidianCodeMirrorShortDocumentTailLine = "obsidian-codemirror-short-document-tail-line"
    case obsidianCodeMirrorLineStartTail = "obsidian-codemirror-line-start-tail"
    case obsidianCodeMirrorTextAfterTypingGrowth = "obsidian-codemirror-text-after-typing-growth"
    case obsidianCodeMirrorLineDrift = "obsidian-codemirror-line-drift"
    case obsidianCodeMirrorLeadingWordDrift = "obsidian-codemirror-leading-word-drift"
    case obsidianCodeMirrorTextAfterActiveLine = "obsidian-codemirror-text-after-active-line"
    case chromeCodeMirrorTrailingCharacter = "chrome-codemirror-trailing-character"
    case chromeCodeMirrorSoftWrapCursor = "chrome-codemirror-soft-wrap-cursor"
    case chromeCodeMirrorTrailingScaffolding = "chrome-codemirror-trailing-scaffolding"
}

public struct TextContextRepairInput: Equatable, Sendable {
    public let bundleIdentifier: String
    public let role: String?
    public let textBeforeCursor: String
    public let textAfterCursor: String
    public let selectedTextLength: Int
    public let previousTextBeforeCursor: String?
    public let previousTextAfterCursor: String?
    public let windowTitle: String?
    public let fingerprintText: String

    public init(
        bundleIdentifier: String,
        role: String?,
        textBeforeCursor: String,
        textAfterCursor: String,
        selectedTextLength: Int,
        previousTextBeforeCursor: String? = nil,
        previousTextAfterCursor: String? = nil,
        windowTitle: String? = nil,
        fingerprintText: String = ""
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.role = role
        self.textBeforeCursor = textBeforeCursor
        self.textAfterCursor = textAfterCursor
        self.selectedTextLength = max(0, selectedTextLength)
        self.previousTextBeforeCursor = previousTextBeforeCursor
        self.previousTextAfterCursor = previousTextAfterCursor
        self.windowTitle = windowTitle
        self.fingerprintText = fingerprintText
    }
}

public struct TextContextRepairResult: Equatable, Sendable {
    public let textBeforeCursor: String
    public let textAfterCursor: String
    public let reason: TextContextRepairReason?

    public init(
        textBeforeCursor: String,
        textAfterCursor: String,
        reason: TextContextRepairReason? = nil
    ) {
        self.textBeforeCursor = textBeforeCursor
        self.textAfterCursor = textAfterCursor
        self.reason = reason
    }

    public var wasRepaired: Bool {
        reason != nil
    }
}

public struct TextContextRepairPolicy: Equatable, Sendable {
    public init() {}

    public func repair(_ input: TextContextRepairInput) -> TextContextRepairResult {
        if let chromeRepair = chromeCodeMirrorTrailingCharacterRepair(input) {
            return chromeRepair
        }
        if let obsidianRepair = obsidianCodeMirrorTrailingCharacterRepair(input) {
            return obsidianRepair
        }
        if let obsidianRepair = obsidianCodeMirrorTrailingScaffoldingRepair(input) {
            return obsidianRepair
        }
        if let obsidianRepair = obsidianCodeMirrorHiddenSpacerLineRepair(input) {
            return obsidianRepair
        }
        if let obsidianRepair = obsidianCodeMirrorLeadingWordDriftRepair(input) {
            return obsidianRepair
        }
        if let obsidianRepair = obsidianCodeMirrorStalePreviousLineRepair(input) {
            return obsidianRepair
        }
        if let obsidianRepair = obsidianCodeMirrorEndOfDocumentGrowthRepair(input) {
            return obsidianRepair
        }
        if let obsidianRepair = obsidianCodeMirrorViewportEndOfDocumentRepair(input) {
            return obsidianRepair
        }
        if let obsidianRepair = obsidianCodeMirrorViewportTailLineRepair(input) {
            return obsidianRepair
        }
        if let obsidianRepair = obsidianCodeMirrorShortDocumentStructureTailRepair(input) {
            return obsidianRepair
        }
        if let obsidianRepair = obsidianCodeMirrorShortDocumentTailLineRepair(input) {
            return obsidianRepair
        }
        if let obsidianRepair = obsidianCodeMirrorLineStartTailRepair(input) {
            return obsidianRepair
        }
        if let obsidianRepair = obsidianCodeMirrorTextAfterTypingGrowthRepair(input) {
            return obsidianRepair
        }
        if let obsidianRepair = obsidianCodeMirrorTextAfterGrowthRepair(input) {
            return obsidianRepair
        }
        if let obsidianRepair = obsidianCodeMirrorTextAfterActiveLineRepair(input) {
            return obsidianRepair
        }
        if let obsidianRepair = obsidianCodeMirrorLineDriftRepair(input) {
            return obsidianRepair
        }
        if let chromeRepair = chromeCodeMirrorSoftWrapCursorRepair(input) {
            return chromeRepair
        }
        if let chromeRepair = chromeCodeMirrorTrailingScaffoldingRepair(input) {
            return chromeRepair
        }

        return notesTextAfterCursorRepair(input)
    }

    private func chromeCodeMirrorTrailingCharacterRepair(_ input: TextContextRepairInput) -> TextContextRepairResult? {
        guard input.bundleIdentifier == "com.google.Chrome",
              input.role == "AXTextArea",
              input.selectedTextLength == 0,
              input.fingerprintText.localizedCaseInsensitiveContains("codemirror"),
              let lastCharacterBeforeCursor = input.textBeforeCursor.last,
              lastCharacterBeforeCursor.isLetter else {
            return nil
        }

        let lineAfterCursor = firstLine(in: input.textAfterCursor)
        guard lineAfterCursor.count == 1,
              lineAfterCursor.allSatisfy(\.isLetter) else {
            return nil
        }

        let repairedTextBeforeCursor = input.textBeforeCursor + lineAfterCursor
        let repairedTextAfterCursor = String(input.textAfterCursor.dropFirst(lineAfterCursor.count))
        guard isPlausibleActiveTypingLine(currentLine(in: repairedTextBeforeCursor)) else {
            return nil
        }

        return TextContextRepairResult(
            textBeforeCursor: repairedTextBeforeCursor,
            textAfterCursor: repairedTextAfterCursor,
            reason: .chromeCodeMirrorTrailingCharacter
        )
    }

    private func notesTextAfterCursorRepair(_ input: TextContextRepairInput) -> TextContextRepairResult {
        guard input.bundleIdentifier == "com.apple.Notes",
              input.role == "AXTextArea",
              input.selectedTextLength == 0 else {
            return unchanged(input)
        }

        let currentLineBefore = currentLine(in: input.textBeforeCursor)
        guard contentWordCount(in: currentLineBefore) < 2 else {
            return unchanged(input)
        }

        let lineAfterCursor = firstLine(in: input.textAfterCursor)
        guard isPlausibleActiveTypingLine(lineAfterCursor) else {
            return unchanged(input)
        }

        let repairedTextBeforeCursor = input.textBeforeCursor + lineAfterCursor
        let repairedTextAfterCursor = String(input.textAfterCursor.dropFirst(lineAfterCursor.count))

        if let previousTextBeforeCursor = input.previousTextBeforeCursor,
           let previousTextAfterCursor = input.previousTextAfterCursor,
           previousTextBeforeCursor == repairedTextBeforeCursor,
           previousTextAfterCursor == repairedTextAfterCursor {
            return TextContextRepairResult(
                textBeforeCursor: repairedTextBeforeCursor,
                textAfterCursor: repairedTextAfterCursor,
                reason: .notesTextAfterCursorStable
            )
        }

        if let typingGrowthRepair = typingGrowthRepair(
            input: input,
            repairedTextBeforeCursor: repairedTextBeforeCursor,
            repairedTextAfterCursor: repairedTextAfterCursor
        ) {
            return typingGrowthRepair
        }

        guard let previousTextBeforeCursor = input.previousTextBeforeCursor,
              let previousTextAfterCursor = input.previousTextAfterCursor,
              !previousTextBeforeCursor.isEmpty,
              repairedTextBeforeCursor.hasPrefix(previousTextBeforeCursor),
              repairedTextBeforeCursor.count > previousTextBeforeCursor.count,
              input.textAfterCursor.hasPrefix(previousTextAfterCursor) else {
            return unchanged(input)
        }

        return TextContextRepairResult(
            textBeforeCursor: repairedTextBeforeCursor,
            textAfterCursor: repairedTextAfterCursor,
            reason: .notesTextAfterCursorTyping
        )
    }

    private func obsidianCodeMirrorTrailingCharacterRepair(_ input: TextContextRepairInput) -> TextContextRepairResult? {
        guard input.bundleIdentifier == "md.obsidian",
              input.role == "AXTextArea",
              input.selectedTextLength == 0,
              let lastCharacterBeforeCursor = input.textBeforeCursor.last,
              lastCharacterBeforeCursor.isLetter else {
            return nil
        }

        let lineAfterCursor = firstLine(in: input.textAfterCursor)
        guard lineAfterCursor.count == 1,
              lineAfterCursor.allSatisfy(\.isLetter) else {
            return nil
        }

        let repairedTextBeforeCursor = input.textBeforeCursor + lineAfterCursor
        let repairedTextAfterCursor = String(input.textAfterCursor.dropFirst(lineAfterCursor.count))
        let repairedCurrentLine = currentLine(in: repairedTextBeforeCursor)
        guard isPlausibleActiveTypingLine(repairedCurrentLine) else {
            return nil
        }

        return TextContextRepairResult(
            textBeforeCursor: repairedTextBeforeCursor,
            textAfterCursor: repairedTextAfterCursor,
            reason: .obsidianCodeMirrorTrailingCharacter
        )
    }

    private func obsidianCodeMirrorTrailingScaffoldingRepair(_ input: TextContextRepairInput) -> TextContextRepairResult? {
        guard input.bundleIdentifier == "md.obsidian",
              input.role == "AXTextArea",
              input.selectedTextLength == 0,
              !input.textAfterCursor.isEmpty,
              input.textAfterCursor.count <= 12,
              input.textAfterCursor.containsCodeMirrorScaffolding,
              input.textAfterCursor.trimmingCodeMirrorScaffolding().isEmpty,
              isPlausibleActiveTypingLine(currentLine(in: input.textBeforeCursor)) else {
            return nil
        }

        return TextContextRepairResult(
            textBeforeCursor: input.textBeforeCursor,
            textAfterCursor: "",
            reason: .obsidianCodeMirrorTrailingScaffolding
        )
    }

    private func obsidianCodeMirrorHiddenSpacerLineRepair(_ input: TextContextRepairInput) -> TextContextRepairResult? {
        guard input.bundleIdentifier == "md.obsidian",
              input.role == "AXTextArea",
              input.selectedTextLength == 0,
              currentLine(in: input.textBeforeCursor).trimmingCodeMirrorScaffolding().isEmpty else {
            return nil
        }

        let skipped = leadingCodeMirrorSpacerPrefix(in: input.textAfterCursor)
        guard !skipped.prefix.isEmpty else {
            return nil
        }

        let activeLine = firstLine(in: skipped.remaining)
        guard activeLine.count <= 100,
              isPlausibleActiveTypingLine(activeLine) else {
            return nil
        }

        return TextContextRepairResult(
            textBeforeCursor: input.textBeforeCursor + activeLine,
            textAfterCursor: String(skipped.remaining.dropFirst(activeLine.count)),
            reason: .obsidianCodeMirrorHiddenSpacerLine
        )
    }

    private func obsidianCodeMirrorStalePreviousLineRepair(_ input: TextContextRepairInput) -> TextContextRepairResult? {
        guard input.bundleIdentifier == "md.obsidian",
              input.role == "AXTextArea",
              input.selectedTextLength == 0,
              let newlineIndex = input.textAfterCursor.firstIndex(where: \.isNewline) else {
            return nil
        }

        let staleLineSuffix = String(input.textAfterCursor[..<newlineIndex])
        guard !staleLineSuffix.isEmpty,
              staleLineSuffix.count <= 40,
              !staleLineSuffix.contains(where: \.isWhitespace) else {
            return nil
        }

        let activeLineStart = input.textAfterCursor.index(after: newlineIndex)
        let remainingAfterStaleLine = String(input.textAfterCursor[activeLineStart...])
        let activeLine = firstLine(in: remainingAfterStaleLine)
        guard activeLine.count <= 100,
              isPlausibleActiveTypingLine(activeLine) else {
            return nil
        }

        let repairedTextBeforeCursor = input.textBeforeCursor
            + staleLineSuffix
            + String(input.textAfterCursor[newlineIndex])
            + activeLine
        return TextContextRepairResult(
            textBeforeCursor: repairedTextBeforeCursor,
            textAfterCursor: String(remainingAfterStaleLine.dropFirst(activeLine.count)),
            reason: .obsidianCodeMirrorStalePreviousLine
        )
    }

    private func obsidianCodeMirrorTextAfterGrowthRepair(_ input: TextContextRepairInput) -> TextContextRepairResult? {
        guard input.bundleIdentifier == "md.obsidian",
              input.role == "AXTextArea",
              input.selectedTextLength == 0,
              let previousTextBeforeCursor = input.previousTextBeforeCursor,
              let previousTextAfterCursor = input.previousTextAfterCursor else {
            return nil
        }

        if !previousTextAfterCursor.isEmpty {
            guard previousTextBeforeCursor == input.textBeforeCursor,
                  input.textAfterCursor.hasPrefix(previousTextAfterCursor),
                  input.textAfterCursor.count > previousTextAfterCursor.count else {
                return nil
            }
        } else {
            guard !previousTextBeforeCursor.isEmpty,
                  input.textBeforeCursor.hasPrefix(previousTextBeforeCursor),
                  input.textBeforeCursor.count > previousTextBeforeCursor.count,
                  input.textBeforeCursor.count <= previousTextBeforeCursor.count + 8,
                  input.textAfterCursor.count >= 2 else {
                return nil
            }

            let driftPrefix = String(input.textBeforeCursor.dropFirst(previousTextBeforeCursor.count))
            guard driftPrefix.allSatisfy(\.isLetter) else {
                return nil
            }
        }

        let lineAfterCursor = firstLine(in: input.textAfterCursor)
        let repairedTextBeforeCursor = input.textBeforeCursor + lineAfterCursor
        let repairedTextAfterCursor = String(input.textAfterCursor.dropFirst(lineAfterCursor.count))
        let repairedCurrentLine = currentLine(in: repairedTextBeforeCursor)
        guard isPlausibleActiveTypingLine(repairedCurrentLine) else {
            return nil
        }

        return TextContextRepairResult(
            textBeforeCursor: repairedTextBeforeCursor,
            textAfterCursor: repairedTextAfterCursor,
            reason: .obsidianCodeMirrorTextAfterGrowth
        )
    }

    private func obsidianCodeMirrorEndOfDocumentGrowthRepair(_ input: TextContextRepairInput) -> TextContextRepairResult? {
        guard input.bundleIdentifier == "md.obsidian",
              input.role == "AXTextArea",
              input.selectedTextLength == 0,
              let previousTextBeforeCursor = input.previousTextBeforeCursor,
              let previousTextAfterCursor = input.previousTextAfterCursor,
              !previousTextBeforeCursor.isEmpty,
              previousTextAfterCursor.isEmpty,
              !input.textAfterCursor.isEmpty else {
            return nil
        }

        let currentText = input.textBeforeCursor + input.textAfterCursor
        if let cappedWindowRepair = obsidianCodeMirrorCappedEndOfDocumentGrowthRepair(
            input: input,
            previousTextBeforeCursor: previousTextBeforeCursor,
            currentText: currentText
        ) {
            return cappedWindowRepair
        }
        if let typingDriftRepair = obsidianCodeMirrorEndOfDocumentTypingDriftRepair(
            input: input,
            previousTextBeforeCursor: previousTextBeforeCursor,
            currentText: currentText
        ) {
            return typingDriftRepair
        }

        guard currentText.hasPrefix(previousTextBeforeCursor),
              currentText.count > previousTextBeforeCursor.count,
              currentText.count <= previousTextBeforeCursor.count + 160,
              input.textBeforeCursor.count < previousTextBeforeCursor.count else {
            return nil
        }

        guard isPlausibleActiveTypingLine(currentLine(in: currentText)) else {
            return nil
        }

        return TextContextRepairResult(
            textBeforeCursor: currentText,
            textAfterCursor: "",
            reason: .obsidianCodeMirrorEndOfDocumentGrowth
        )
    }

    private func obsidianCodeMirrorEndOfDocumentTypingDriftRepair(
        input: TextContextRepairInput,
        previousTextBeforeCursor: String,
        currentText: String
    ) -> TextContextRepairResult? {
        guard currentText.hasPrefix(previousTextBeforeCursor),
              currentText.count > previousTextBeforeCursor.count,
              currentText.count <= previousTextBeforeCursor.count + 200,
              previousTextBeforeCursor.last?.isNewline == true,
              input.textBeforeCursor.count >= previousTextBeforeCursor.count,
              input.textBeforeCursor.count < currentText.count,
              input.textAfterCursor.count <= 80 else {
            return nil
        }

        let appendedText = String(currentText.dropFirst(previousTextBeforeCursor.count))
        guard !appendedText.isEmpty,
              appendedText.count <= 160,
              appendedText.contains(where: \.isLetter),
              isPlausibleActiveTypingLine(currentLine(in: currentText)) else {
            return nil
        }

        return TextContextRepairResult(
            textBeforeCursor: currentText,
            textAfterCursor: "",
            reason: .obsidianCodeMirrorEndOfDocumentTypingDrift
        )
    }

    private func obsidianCodeMirrorTextAfterTypingGrowthRepair(_ input: TextContextRepairInput) -> TextContextRepairResult? {
        guard input.bundleIdentifier == "md.obsidian",
              input.role == "AXTextArea",
              input.selectedTextLength == 0,
              let previousTextBeforeCursor = input.previousTextBeforeCursor,
              let previousTextAfterCursor = input.previousTextAfterCursor,
              !previousTextBeforeCursor.isEmpty,
              previousTextAfterCursor.isEmpty,
              previousTextBeforeCursor == input.textBeforeCursor,
              !input.textAfterCursor.isEmpty,
              input.textAfterCursor.count <= 160 else {
            return nil
        }

        let activeLine = firstLine(in: input.textAfterCursor)
        let remainingAfterLine = String(input.textAfterCursor.dropFirst(activeLine.count))
        let strippedRemaining = remainingAfterLine
            .trimmingCodeMirrorScaffolding()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard activeLine.count <= 120,
              strippedRemaining.isEmpty else {
            return nil
        }

        let currentLineBefore = currentLine(in: input.textBeforeCursor)
        let canJoinSameLine = currentLineBefore.last?.isLetter == true
            || currentLineBefore.last?.isWhitespace == true
        if canJoinSameLine,
           isPlausibleActiveTypingLine(currentLineBefore + activeLine) {
            return TextContextRepairResult(
                textBeforeCursor: input.textBeforeCursor + activeLine,
                textAfterCursor: remainingAfterLine,
                reason: .obsidianCodeMirrorTextAfterTypingGrowth
            )
        }

        guard input.textBeforeCursor.contains(where: \.isNewline),
              isPlausibleActiveTypingLine(activeLine) else {
            return nil
        }

        let separator = input.textBeforeCursor.last?.isNewline == true ? "" : "\n"
        return TextContextRepairResult(
            textBeforeCursor: input.textBeforeCursor + separator + activeLine,
            textAfterCursor: remainingAfterLine,
            reason: .obsidianCodeMirrorTextAfterTypingGrowth
        )
    }

    private func obsidianCodeMirrorViewportEndOfDocumentRepair(_ input: TextContextRepairInput) -> TextContextRepairResult? {
        guard input.bundleIdentifier == "md.obsidian",
              input.role == "AXTextArea",
              input.selectedTextLength == 0,
              input.textBeforeCursor.count >= 500,
              !input.textAfterCursor.isEmpty,
              input.textAfterCursor.count <= 260 else {
            return nil
        }

        let currentLineBefore = currentLine(in: input.textBeforeCursor)
        let lineAfterCursor = firstLine(in: input.textAfterCursor)
        guard !currentLineBefore.isEmpty,
              !lineAfterCursor.isEmpty,
              currentLineBefore.count <= 48,
              lineAfterCursor.count <= 120 else {
            return nil
        }

        let stitchedViewportLine = currentLineBefore + lineAfterCursor
        guard stitchedViewportLine.contains(where: \.isNumber),
              contentWordCount(in: stitchedViewportLine) >= 4 else {
            return nil
        }

        let remainingAfterViewportLine = String(input.textAfterCursor.dropFirst(lineAfterCursor.count))
        guard remainingAfterViewportLine.first?.isNewline == true else {
            return nil
        }

        let remainingTailLines = remainingAfterViewportLine
            .split(omittingEmptySubsequences: true, whereSeparator: \.isNewline)
            .map(String.init)
        guard !remainingTailLines.isEmpty,
              remainingTailLines.count <= 3,
              let activeLine = remainingTailLines.last,
              isPlausibleActiveTypingLine(activeLine) else {
            return nil
        }

        let currentText = input.textBeforeCursor + input.textAfterCursor
        guard currentLine(in: currentText) == activeLine else {
            return nil
        }

        return TextContextRepairResult(
            textBeforeCursor: currentText,
            textAfterCursor: "",
            reason: .obsidianCodeMirrorViewportEndOfDocument
        )
    }

    private func obsidianCodeMirrorViewportTailLineRepair(_ input: TextContextRepairInput) -> TextContextRepairResult? {
        guard input.bundleIdentifier == "md.obsidian",
              input.role == "AXTextArea",
              input.selectedTextLength == 0,
              input.textBeforeCursor.count >= 300,
              !input.textAfterCursor.isEmpty,
              input.textAfterCursor.count <= 260 else {
            return nil
        }

        let lineAfterCursor = firstLine(in: input.textAfterCursor)
        let remainingAfterLine = String(input.textAfterCursor.dropFirst(lineAfterCursor.count))
        guard remainingAfterLine.first?.isNewline == true else {
            return nil
        }

        let staleAnchorLine = currentLine(in: input.textBeforeCursor) + lineAfterCursor
        guard staleAnchorLine.count >= 6,
              staleAnchorLine.count <= 120,
              contentWordCount(in: staleAnchorLine) >= 2 else {
            return nil
        }

        let tailLines = remainingAfterLine
            .split(omittingEmptySubsequences: true, whereSeparator: \.isNewline)
            .map(String.init)
        guard tailLines.count == 1,
              let activeLine = tailLines.last,
              activeLine != staleAnchorLine,
              isPlausibleActiveTypingLine(activeLine) else {
            return nil
        }

        let currentText = input.textBeforeCursor + input.textAfterCursor
        guard currentLine(in: currentText.trimmingCodeMirrorScaffoldingRight()) == activeLine else {
            return nil
        }

        return TextContextRepairResult(
            textBeforeCursor: currentText,
            textAfterCursor: "",
            reason: .obsidianCodeMirrorViewportTailLine
        )
    }

    private func obsidianCodeMirrorShortDocumentStructureTailRepair(_ input: TextContextRepairInput) -> TextContextRepairResult? {
        guard input.bundleIdentifier == "md.obsidian",
              input.role == "AXTextArea",
              input.selectedTextLength == 0,
              input.textBeforeCursor.count <= 240,
              !input.textAfterCursor.isEmpty,
              input.textAfterCursor.count <= 360,
              input.textAfterCursor.contains(where: \.isNewline) else {
            return nil
        }

        let staleLine = currentLine(in: input.textBeforeCursor)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard staleLine.count >= 18,
              staleLine.count <= 120,
              contentWordCount(in: staleLine) >= 3 else {
            return nil
        }

        let currentText = input.textBeforeCursor + input.textAfterCursor
        let repairedTextBeforeCursor = currentText.trimmingCodeMirrorScaffoldingRight()
        let tailLine = currentLine(in: repairedTextBeforeCursor)
            .removingCodeMirrorScaffoldingMarkers()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let meaningfulAfterLines = meaningfulLines(in: input.textAfterCursor)
        guard repairedTextBeforeCursor.count > input.textBeforeCursor.count,
              !meaningfulAfterLines.isEmpty,
              meaningfulAfterLines.last == tailLine,
              isBareMarkdownStructureLine(tailLine) else {
            return nil
        }

        return TextContextRepairResult(
            textBeforeCursor: repairedTextBeforeCursor,
            textAfterCursor: "",
            reason: .obsidianCodeMirrorShortDocumentStructureTail
        )
    }

    private func obsidianCodeMirrorShortDocumentTailLineRepair(_ input: TextContextRepairInput) -> TextContextRepairResult? {
        guard input.bundleIdentifier == "md.obsidian",
              input.role == "AXTextArea",
              input.selectedTextLength == 0,
              input.textBeforeCursor.count <= 240,
              !input.textAfterCursor.isEmpty,
              input.textAfterCursor.count <= 360,
              input.textAfterCursor.contains(where: \.isNewline) else {
            return nil
        }

        let staleLine = currentLine(in: input.textBeforeCursor)
        let trimmedStaleLine = staleLine.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedStaleLine.count >= 18,
              trimmedStaleLine.count <= 120,
              contentWordCount(in: trimmedStaleLine) >= 3 else {
            return nil
        }

        let currentText = input.textBeforeCursor + input.textAfterCursor
        let repairedTextBeforeCursor = currentText.trimmingCodeMirrorScaffoldingRight()
        let activeLine = currentLine(in: repairedTextBeforeCursor)
        let trimmedActiveLine = activeLine
            .removingCodeMirrorScaffoldingMarkers()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard repairedTextBeforeCursor.count > input.textBeforeCursor.count,
              trimmedActiveLine != trimmedStaleLine,
              trimmedActiveLine.count <= 260,
              isPlausibleActiveTypingLine(trimmedActiveLine) else {
            return nil
        }

        let previousAfterGrewAtTail = input.previousTextBeforeCursor == input.textBeforeCursor
            && !(input.previousTextAfterCursor ?? "").isEmpty
            && input.textAfterCursor.hasPrefix(input.previousTextAfterCursor ?? "")
            && input.textAfterCursor.count > (input.previousTextAfterCursor ?? "").count

        let meaningfulAfterLines = meaningfulLines(in: input.textAfterCursor)
        let hasMarkdownOrCodeMirrorScaffold = input.textAfterCursor.containsCodeMirrorInvisibleScaffolding
            || meaningfulAfterLines.dropLast().contains(where: isMarkdownStructureLine)
        let hasStructuredTailEvidence = meaningfulAfterLines.count >= 2
            && (previousAfterGrewAtTail || hasMarkdownOrCodeMirrorScaffold)
        let hasLongRunOnTailEvidence = meaningfulAfterLines.count == 1
            && input.textAfterCursor.hasPrefix("\n\n")
            && input.textBeforeCursor.count <= 80
            && trimmedActiveLine.count >= 120
            && contentWordCount(in: trimmedActiveLine) >= 16
            && !isMarkdownStructureLine(trimmedActiveLine)
        guard meaningfulAfterLines.last == trimmedActiveLine,
              hasStructuredTailEvidence || hasLongRunOnTailEvidence else {
            return nil
        }

        return TextContextRepairResult(
            textBeforeCursor: repairedTextBeforeCursor,
            textAfterCursor: "",
            reason: .obsidianCodeMirrorShortDocumentTailLine
        )
    }

    private func obsidianCodeMirrorLineStartTailRepair(_ input: TextContextRepairInput) -> TextContextRepairResult? {
        guard input.bundleIdentifier == "md.obsidian",
              input.role == "AXTextArea",
              input.selectedTextLength == 0,
              input.textBeforeCursor.count >= 300,
              input.textBeforeCursor.last?.isNewline == true,
              !input.textAfterCursor.isEmpty,
              input.textAfterCursor.count <= 120,
              let previousTextBeforeCursor = input.previousTextBeforeCursor else {
            return nil
        }

        let activeLine = firstLine(in: input.textAfterCursor)
        let repairedTextBeforeCursor = input.textBeforeCursor + activeLine
        let remainingAfterLine = String(input.textAfterCursor.dropFirst(activeLine.count))
        let strippedRemaining = remainingAfterLine
            .trimmingCodeMirrorScaffolding()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let isNewTailGrowth = input.textBeforeCursor.count > previousTextBeforeCursor.count
        let isStableLineStartReread = previousTextBeforeCursor == repairedTextBeforeCursor
        guard activeLine.count <= 80,
              isPlausibleActiveTypingLine(activeLine),
              strippedRemaining.isEmpty,
              isNewTailGrowth || isStableLineStartReread else {
            return nil
        }

        return TextContextRepairResult(
            textBeforeCursor: repairedTextBeforeCursor,
            textAfterCursor: remainingAfterLine,
            reason: .obsidianCodeMirrorLineStartTail
        )
    }

    private func obsidianCodeMirrorCappedEndOfDocumentGrowthRepair(
        input: TextContextRepairInput,
        previousTextBeforeCursor: String,
        currentText: String
    ) -> TextContextRepairResult? {
        guard currentText.count >= 120,
              currentText.count <= 640,
              !previousTextBeforeCursor.hasSuffix(currentText),
              input.textBeforeCursor.count <= 32,
              input.textBeforeCursor.count < previousTextBeforeCursor.count,
              currentText.count < previousTextBeforeCursor.count else {
            return nil
        }

        let minimumOverlap = 120
        guard let overlap = suffixPrefixOverlap(
            previousTextBeforeCursor,
            currentText,
            minimumLength: minimumOverlap
        ) else {
            return nil
        }

        let appendedText = String(currentText.dropFirst(overlap))
        guard !appendedText.isEmpty,
              appendedText.count <= 160,
              appendedText.contains(where: \.isLetter),
              isPlausibleActiveTypingLine(currentLine(in: currentText)) else {
            return nil
        }

        return TextContextRepairResult(
            textBeforeCursor: currentText,
            textAfterCursor: "",
            reason: .obsidianCodeMirrorEndOfDocumentGrowth
        )
    }

    private func obsidianCodeMirrorLineDriftRepair(_ input: TextContextRepairInput) -> TextContextRepairResult? {
        guard input.bundleIdentifier == "md.obsidian",
              input.role == "AXTextArea",
              input.selectedTextLength == 0 else {
            return nil
        }

        let currentLineBefore = currentLine(in: input.textBeforeCursor)
        let lineAfterCursor = firstLine(in: input.textAfterCursor)
        let currentLineWordCount = contentWordCount(in: currentLineBefore)
        let isMarkdownListLine = isMarkdownListStructureLine(currentLineBefore)
        let trailingFragment = trailingWordFragment(in: currentLineBefore) ?? ""
        let standardLineDrift = currentLineBefore.count <= 24
            && currentLineWordCount <= 2
            && (lineAfterCursor.contains(where: \.isWhitespace) || trailingFragment.count <= 1)
        let leadingWhitespaceLineDrift = standardLineDrift
            && lineAfterCursor.first?.isWhitespace == true
            && contentWordCount(in: lineAfterCursor) >= 1
            && contentWordCount(in: lineAfterCursor) <= 8
            && obsidianCodeMirrorLooksLikeDocumentTailGrowth(input)
        let markdownListLineDrift = isMarkdownListLine
            && currentLineBefore.count <= 80
            && currentLineWordCount <= 8
            && lineAfterCursor.allSatisfy(\.isLetter)
        let shortTrailingWordSplit = currentLineBefore.count <= 80
            && input.textBeforeCursor.contains(where: \.isNewline)
            && currentLineWordCount <= 8
            && trailingFragment.count >= 1
            && trailingFragment.count <= 4
            && lineAfterCursor.count <= 8
            && lineAfterCursor.allSatisfy(\.isLetter)

        guard currentLineBefore.count >= 1,
              lineAfterCursor.count >= 2,
              lineAfterCursor.count <= 80,
              standardLineDrift || leadingWhitespaceLineDrift || markdownListLineDrift || shortTrailingWordSplit,
              let lastCharacterBeforeCursor = currentLineBefore.last,
              lastCharacterBeforeCursor.isLetter,
              obsidianCodeMirrorLineDriftAfterCursorStartsSafely(
                  lineAfterCursor,
                  allowsLeadingWhitespace: leadingWhitespaceLineDrift
              ) else {
            return nil
        }

        let repairedLine = currentLineBefore + lineAfterCursor
        guard isPlausibleActiveTypingLine(repairedLine) else {
            return nil
        }

        let remainingAfterLine = String(input.textAfterCursor.dropFirst(lineAfterCursor.count))
        let strippedRemainingAfterLine = remainingAfterLine
            .trimmingCodeMirrorScaffolding()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard strippedRemainingAfterLine.isEmpty else {
            return nil
        }
        let repairedTextAfterCursor = remainingAfterLine.trimmingCodeMirrorScaffolding().isEmpty
            ? ""
            : remainingAfterLine

        return TextContextRepairResult(
            textBeforeCursor: input.textBeforeCursor + lineAfterCursor,
            textAfterCursor: repairedTextAfterCursor,
            reason: .obsidianCodeMirrorLineDrift
        )
    }

    private func obsidianCodeMirrorLooksLikeDocumentTailGrowth(_ input: TextContextRepairInput) -> Bool {
        guard let previousTextBeforeCursor = input.previousTextBeforeCursor,
              let previousTextAfterCursor = input.previousTextAfterCursor,
              !previousTextBeforeCursor.isEmpty,
              previousTextAfterCursor.isEmpty else {
            return false
        }

        let currentText = input.textBeforeCursor + input.textAfterCursor
        return currentText.hasPrefix(previousTextBeforeCursor)
            && currentText.count > previousTextBeforeCursor.count
            && currentText.count <= previousTextBeforeCursor.count + 200
    }

    private func obsidianCodeMirrorLineDriftAfterCursorStartsSafely(
        _ lineAfterCursor: String,
        allowsLeadingWhitespace: Bool
    ) -> Bool {
        guard let firstCharacterAfterCursor = lineAfterCursor.first else {
            return false
        }
        if firstCharacterAfterCursor.isLetter {
            return true
        }
        guard allowsLeadingWhitespace,
              firstCharacterAfterCursor.isWhitespace else {
            return false
        }
        return lineAfterCursor
            .drop(while: \.isWhitespace)
            .first?
            .isLetter == true
    }

    private func obsidianCodeMirrorTextAfterActiveLineRepair(_ input: TextContextRepairInput) -> TextContextRepairResult? {
        guard input.bundleIdentifier == "md.obsidian",
              input.role == "AXTextArea",
              input.selectedTextLength == 0,
              !input.textBeforeCursor.isEmpty,
              input.textAfterCursor.count <= 120 else {
            return nil
        }

        let currentLineBefore = currentLine(in: input.textBeforeCursor)
        guard input.textBeforeCursor.contains(where: \.isNewline),
              currentLineBefore.count >= 24,
              currentLineBefore.count <= 100,
              contentWordCount(in: currentLineBefore) >= 3 else {
            return nil
        }

        let lineAfterCursor = firstLine(in: input.textAfterCursor)
        guard isPlausibleActiveTypingLine(lineAfterCursor) else {
            return nil
        }

        let remainingAfterLine = String(input.textAfterCursor.dropFirst(lineAfterCursor.count))
        let strippedRemaining = remainingAfterLine
            .trimmingCodeMirrorScaffolding()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard strippedRemaining.isEmpty else {
            return nil
        }

        return TextContextRepairResult(
            textBeforeCursor: input.textBeforeCursor + "\n" + lineAfterCursor,
            textAfterCursor: remainingAfterLine,
            reason: .obsidianCodeMirrorTextAfterActiveLine
        )
    }

    private func obsidianCodeMirrorLeadingWordDriftRepair(_ input: TextContextRepairInput) -> TextContextRepairResult? {
        guard input.bundleIdentifier == "md.obsidian",
              input.role == "AXTextArea",
              input.selectedTextLength == 0 else {
            return nil
        }

        let currentLineBefore = currentLine(in: input.textBeforeCursor)
        guard currentLineBefore.count >= 6,
              currentLineBefore.count <= 80,
              contentWordCount(in: currentLineBefore) >= 2,
              contentWordCount(in: currentLineBefore) <= 8,
              currentLineBefore.last?.isLetter == true else {
            return nil
        }

        let lineAfterCursor = firstLine(in: input.textAfterCursor)
        guard let consumedAfterCursor = leadingWhitespaceWordDrift(in: lineAfterCursor) else {
            return nil
        }

        let repairedLine = currentLineBefore + consumedAfterCursor
        guard isPlausibleActiveTypingLine(repairedLine) else {
            return nil
        }

        return TextContextRepairResult(
            textBeforeCursor: input.textBeforeCursor + consumedAfterCursor,
            textAfterCursor: String(input.textAfterCursor.dropFirst(consumedAfterCursor.count)),
            reason: .obsidianCodeMirrorLeadingWordDrift
        )
    }

    private func chromeCodeMirrorTrailingScaffoldingRepair(_ input: TextContextRepairInput) -> TextContextRepairResult? {
        guard input.bundleIdentifier == "com.google.Chrome",
              input.role == "AXTextArea",
              input.selectedTextLength == 0,
              input.windowTitle?.localizedCaseInsensitiveContains("CodeMirror") == true,
              !input.textAfterCursor.isEmpty,
              input.textAfterCursor.count <= 12,
              input.textAfterCursor.containsCodeMirrorScaffolding,
              input.textAfterCursor.trimmingCodeMirrorScaffolding().isEmpty,
              isPlausibleActiveTypingLine(currentLine(in: input.textBeforeCursor)) else {
            return nil
        }

        return TextContextRepairResult(
            textBeforeCursor: input.textBeforeCursor,
            textAfterCursor: "",
            reason: .chromeCodeMirrorTrailingScaffolding
        )
    }

    private func chromeCodeMirrorSoftWrapCursorRepair(_ input: TextContextRepairInput) -> TextContextRepairResult? {
        guard input.bundleIdentifier == "com.google.Chrome",
              input.role == "AXTextArea",
              input.selectedTextLength == 0,
              input.windowTitle?.localizedCaseInsensitiveContains("CodeMirror") == true,
              input.textBeforeCursor.contains("\n\n"),
              !input.textAfterCursor.isEmpty,
              input.textAfterCursor.count <= 4,
              input.textAfterCursor.allSatisfy(\.isLetter) else {
            return nil
        }

        let repairedText = (input.textBeforeCursor + input.textAfterCursor)
            .replacingOccurrences(of: "\n\n", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        guard repairedText != input.textBeforeCursor + input.textAfterCursor,
              repairedText.count <= 160,
              isPlausibleActiveTypingLine(repairedText) else {
            return nil
        }

        return TextContextRepairResult(
            textBeforeCursor: repairedText,
            textAfterCursor: "",
            reason: .chromeCodeMirrorSoftWrapCursor
        )
    }

    private func typingGrowthRepair(
        input: TextContextRepairInput,
        repairedTextBeforeCursor: String,
        repairedTextAfterCursor: String
    ) -> TextContextRepairResult? {
        guard let previousTextBeforeCursor = input.previousTextBeforeCursor,
              let previousTextAfterCursor = input.previousTextAfterCursor,
              previousTextBeforeCursor == input.textBeforeCursor,
              input.textAfterCursor.hasPrefix(previousTextAfterCursor),
              input.textAfterCursor.count > previousTextAfterCursor.count else {
            return nil
        }

        return TextContextRepairResult(
            textBeforeCursor: repairedTextBeforeCursor,
            textAfterCursor: repairedTextAfterCursor,
            reason: .notesTextAfterCursorTyping
        )
    }

    private func unchanged(_ input: TextContextRepairInput) -> TextContextRepairResult {
        TextContextRepairResult(
            textBeforeCursor: input.textBeforeCursor,
            textAfterCursor: input.textAfterCursor
        )
    }

    private func currentLine(in text: String) -> String {
        text.split(
            omittingEmptySubsequences: false,
            whereSeparator: \.isNewline
        ).last.map(String.init) ?? ""
    }

    private func firstLine(in text: String) -> String {
        text.split(
            omittingEmptySubsequences: false,
            whereSeparator: \.isNewline
        ).first.map(String.init) ?? ""
    }

    private func meaningfulLines(in text: String) -> [String] {
        text
            .split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
            .map { line in
                String(line)
                    .removingCodeMirrorScaffoldingMarkers()
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }
    }

    private func isMarkdownStructureLine(_ line: String) -> Bool {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedLine == "-"
            || trimmedLine == "*"
            || trimmedLine == "+"
            || trimmedLine.hasPrefix("- ")
            || trimmedLine.hasPrefix("* ")
            || trimmedLine.hasPrefix("+ ")
            || trimmedLine.hasPrefix("#")
            || trimmedLine.hasPrefix(">")
            || trimmedLine.hasPrefix("|")
            || trimmedLine.hasPrefix("```")
    }

    private func isMarkdownListStructureLine(_ line: String) -> Bool {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedLine.hasPrefix("- ")
            || trimmedLine.hasPrefix("* ")
            || trimmedLine.hasPrefix("+ ")
    }

    private func isBareMarkdownStructureLine(_ line: String) -> Bool {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedLine == "-"
            || trimmedLine == "*"
            || trimmedLine == "+"
    }

    private func leadingCodeMirrorSpacerPrefix(in text: String) -> (prefix: String, remaining: String) {
        var prefix = ""
        var remaining = text

        while let newlineIndex = remaining.firstIndex(where: \.isNewline) {
            let line = String(remaining[..<newlineIndex])
            guard line.trimmingCodeMirrorScaffolding().isEmpty else {
                break
            }

            let nextIndex = remaining.index(after: newlineIndex)
            prefix += String(remaining[..<nextIndex])
            remaining = String(remaining[nextIndex...])
        }

        return (prefix, remaining)
    }

    private func isPlausibleActiveTypingLine(_ line: String) -> Bool {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedLine.count >= 6,
              contentWordCount(in: trimmedLine) >= 2 else {
            return false
        }

        guard let trailingFragment = trailingWordFragment(in: trimmedLine) else {
            return false
        }

        return trailingFragment.count >= 2
            && trailingFragment.count <= 16
            && trailingFragment.allSatisfy(\.isLetter)
    }

    private func contentWordCount(in text: String) -> Int {
        text
            .split(whereSeparator: \.isWhitespace)
            .map { token in
                token.trimmingCharacters(in: .punctuationCharacters)
            }
            .filter { token in
                token.contains(where: \.isLetter)
            }
            .count
    }

    private func trailingWordFragment(in text: String) -> String? {
        text.split(whereSeparator: \.isWhitespace)
            .last
            .map(String.init)?
            .trimmingCharacters(in: .punctuationCharacters)
    }

    private func leadingWhitespaceWordDrift(in text: String) -> String? {
        var index = text.startIndex
        var consumed = ""

        while index < text.endIndex,
              text[index].isWhitespace,
              !text[index].isNewline {
            consumed.append(text[index])
            index = text.index(after: index)
        }

        guard !consumed.isEmpty else {
            return nil
        }

        var word = ""
        while index < text.endIndex,
              text[index].isLetter {
            word.append(text[index])
            index = text.index(after: index)
        }

        guard word.count >= 2,
              word.count <= 16 else {
            return nil
        }

        let sameLineRemainder = String(text[index...])
        let strippedRemainder = sameLineRemainder
            .trimmingCodeMirrorScaffolding()
            .trimmingCharacters(in: .whitespaces)
        guard strippedRemainder.isEmpty else {
            return nil
        }

        return consumed + word
    }

    private func suffixPrefixOverlap(
        _ previousText: String,
        _ currentText: String,
        minimumLength: Int
    ) -> Int? {
        let maximumLength = min(previousText.count, currentText.count - 1)
        guard maximumLength >= minimumLength else {
            return nil
        }

        for length in stride(from: maximumLength, through: minimumLength, by: -1) {
            if previousText.suffix(length) == currentText.prefix(length) {
                return length
            }
        }

        return nil
    }
}

private extension String {
    var containsCodeMirrorScaffolding: Bool {
        unicodeScalars.contains(where: \.isCodeMirrorScaffoldingMarker)
    }

    var containsCodeMirrorInvisibleScaffolding: Bool {
        unicodeScalars.contains(where: \.isCodeMirrorInvisibleScaffoldingMarker)
    }

    func trimmingCodeMirrorScaffolding() -> String {
        String(unicodeScalars.filter { scalar in
            !scalar.isCodeMirrorScaffolding
        })
    }

    func trimmingCodeMirrorScaffoldingRight() -> String {
        var scalars = unicodeScalars
        while let last = scalars.last,
              last.isCodeMirrorScaffolding {
            scalars.removeLast()
        }
        return String(scalars)
    }

    func removingCodeMirrorScaffoldingMarkers() -> String {
        String(unicodeScalars.filter { scalar in
            !scalar.isCodeMirrorScaffoldingMarker
        })
    }
}

private extension Unicode.Scalar {
    var isCodeMirrorInvisibleScaffoldingMarker: Bool {
        switch value {
        case 0x0009, // tab
             0x200B, // zero-width space
             0x200C, // zero-width non-joiner
             0x200D, // zero-width joiner
             0x2060, // word joiner
             0xFEFF, // zero-width no-break space
             0xFFFC: // object replacement character
            return true
        default:
            return false
        }
    }

    var isCodeMirrorScaffoldingMarker: Bool {
        switch value {
        case 0x0009, // tab
             0x000A, // line feed
             0x000D, // carriage return
             0x200B, // zero-width space
             0x200C, // zero-width non-joiner
             0x200D, // zero-width joiner
             0x2060, // word joiner
             0xFEFF, // zero-width no-break space
             0xFFFC: // object replacement character
            return true
        default:
            return false
        }
    }

    var isCodeMirrorScaffolding: Bool {
        isCodeMirrorScaffoldingMarker || CharacterSet.whitespacesAndNewlines.contains(self)
    }
}
