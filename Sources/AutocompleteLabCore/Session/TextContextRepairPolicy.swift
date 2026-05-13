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
        guard currentLineBefore.count >= 1,
              currentLineBefore.count <= 24,
              lineAfterCursor.count >= 2,
              lineAfterCursor.count <= 80,
              contentWordCount(in: currentLineBefore) <= 1,
              let lastCharacterBeforeCursor = currentLineBefore.last,
              let firstCharacterAfterCursor = lineAfterCursor.first,
              lastCharacterBeforeCursor.isLetter,
              firstCharacterAfterCursor.isLetter else {
            return nil
        }

        let repairedLine = currentLineBefore + lineAfterCursor
        guard isPlausibleActiveTypingLine(repairedLine) else {
            return nil
        }

        return TextContextRepairResult(
            textBeforeCursor: input.textBeforeCursor + lineAfterCursor,
            textAfterCursor: String(input.textAfterCursor.dropFirst(lineAfterCursor.count)),
            reason: .obsidianCodeMirrorLineDrift
        )
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

    func trimmingCodeMirrorScaffolding() -> String {
        String(unicodeScalars.filter { scalar in
            !scalar.isCodeMirrorScaffolding
        })
    }
}

private extension Unicode.Scalar {
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
