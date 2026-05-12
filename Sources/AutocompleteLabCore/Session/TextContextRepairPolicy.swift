import Foundation

public enum TextContextRepairReason: String, Equatable, Sendable {
    case notesTextAfterCursorTyping = "notes-text-after-cursor-typing"
    case notesTextAfterCursorStable = "notes-text-after-cursor-stable"
    case obsidianCodeMirrorTrailingCharacter = "obsidian-codemirror-trailing-character"
    case obsidianCodeMirrorTrailingScaffolding = "obsidian-codemirror-trailing-scaffolding"
    case obsidianCodeMirrorHiddenSpacerLine = "obsidian-codemirror-hidden-spacer-line"
    case obsidianCodeMirrorLineDrift = "obsidian-codemirror-line-drift"
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

    public init(
        bundleIdentifier: String,
        role: String?,
        textBeforeCursor: String,
        textAfterCursor: String,
        selectedTextLength: Int,
        previousTextBeforeCursor: String? = nil,
        previousTextAfterCursor: String? = nil,
        windowTitle: String? = nil
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.role = role
        self.textBeforeCursor = textBeforeCursor
        self.textAfterCursor = textAfterCursor
        self.selectedTextLength = max(0, selectedTextLength)
        self.previousTextBeforeCursor = previousTextBeforeCursor
        self.previousTextAfterCursor = previousTextAfterCursor
        self.windowTitle = windowTitle
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
        if let obsidianRepair = obsidianCodeMirrorTrailingCharacterRepair(input) {
            return obsidianRepair
        }
        if let obsidianRepair = obsidianCodeMirrorTrailingScaffoldingRepair(input) {
            return obsidianRepair
        }
        if let obsidianRepair = obsidianCodeMirrorHiddenSpacerLineRepair(input) {
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

    private func obsidianCodeMirrorLineDriftRepair(_ input: TextContextRepairInput) -> TextContextRepairResult? {
        guard input.bundleIdentifier == "md.obsidian",
              input.role == "AXTextArea",
              input.selectedTextLength == 0 else {
            return nil
        }

        let currentLineBefore = currentLine(in: input.textBeforeCursor)
        let lineAfterCursor = firstLine(in: input.textAfterCursor)
        guard currentLineBefore.count >= 2,
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
