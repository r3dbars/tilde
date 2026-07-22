import Foundation

public enum TextContextRepairReason: String, Equatable, Sendable {
    case notesTextAfterCursorTyping = "notes-text-after-cursor-typing"
    case notesTextAfterCursorStable = "notes-text-after-cursor-stable"
    case textEditNativeInlineCompletionTail = "textedit-native-inline-completion-tail"
    case obsidianCodeMirrorTrailingCharacter = "obsidian-codemirror-trailing-character"
    case obsidianCodeMirrorTrailingScaffolding = "obsidian-codemirror-trailing-scaffolding"
    case obsidianCodeMirrorHiddenSpacerLine = "obsidian-codemirror-hidden-spacer-line"
    case obsidianCodeMirrorStalePreviousLine = "obsidian-codemirror-stale-previous-line"
    case obsidianCodeMirrorTextAfterGrowth = "obsidian-codemirror-text-after-growth"
    case obsidianCodeMirrorEndOfDocumentGrowth = "obsidian-codemirror-end-of-document-growth"
    case obsidianCodeMirrorEndOfDocumentTypingDrift = "obsidian-codemirror-end-of-document-typing-drift"
    case obsidianCodeMirrorViewportEndOfDocumentStable = "obsidian-codemirror-viewport-end-of-document-stable"
    case obsidianCodeMirrorViewportEndOfDocumentGrowth = "obsidian-codemirror-viewport-end-of-document-growth"
    case obsidianCodeMirrorViewportEndOfDocument = "obsidian-codemirror-viewport-end-of-document"
    case obsidianCodeMirrorViewportTailLine = "obsidian-codemirror-viewport-tail-line"
    case obsidianCodeMirrorShortDocumentStructureTail = "obsidian-codemirror-short-document-structure-tail"
    case obsidianCodeMirrorShortDocumentTailLine = "obsidian-codemirror-short-document-tail-line"
    case obsidianCodeMirrorLineStartTail = "obsidian-codemirror-line-start-tail"
    case obsidianCodeMirrorTextAfterTypingGrowth = "obsidian-codemirror-text-after-typing-growth"
    case obsidianCodeMirrorLineDrift = "obsidian-codemirror-line-drift"
    case obsidianCodeMirrorLeadingWordDrift = "obsidian-codemirror-leading-word-drift"
    case obsidianCodeMirrorDocumentCoordinateDrift = "obsidian-codemirror-document-coordinate-drift"
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
    /// All 22 `md.obsidian`-guarded CodeMirror repair heuristics live in their own
    /// type (`ObsidianCodeMirrorRepair.swift`) behind this single entry point, so
    /// this file only has to reason about the generic (Chrome/TextEdit/Notes)
    /// repairs plus one delegated call.
    private let obsidianRepairPolicy = ObsidianCodeMirrorRepairPolicy()

    public init() {}

    public func repair(_ input: TextContextRepairInput) -> TextContextRepairResult {
        if let chromeRepair = chromeCodeMirrorTrailingCharacterRepair(input) {
            return chromeRepair
        }
        if let textEditRepair = textEditNativeInlineCompletionTailRepair(input) {
            return textEditRepair
        }
        if let obsidianRepair = obsidianRepairPolicy.repair(input) {
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

    private func textEditNativeInlineCompletionTailRepair(_ input: TextContextRepairInput) -> TextContextRepairResult? {
        guard input.bundleIdentifier == "com.apple.TextEdit",
              input.role == "AXTextArea",
              input.selectedTextLength == 0,
              let previousTextBeforeCursor = input.previousTextBeforeCursor,
              let previousTextAfterCursor = input.previousTextAfterCursor,
              previousTextBeforeCursor == input.textBeforeCursor,
              previousTextAfterCursor.isEmpty,
              !input.textAfterCursor.isEmpty,
              input.textAfterCursor.count <= 16,
              !input.textAfterCursor.contains(where: \.isNewline),
              isPlausibleActiveTypingLine(currentLine(in: input.textBeforeCursor)) else {
            return nil
        }

        let trimmedTail = input.textAfterCursor.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTail.isEmpty,
              trimmedTail.count <= 16,
              trimmedTail.contains(where: \.isLetter),
              trimmedTail.allSatisfy({ $0.isLetter || $0.isPunctuation }) else {
            return nil
        }

        return TextContextRepairResult(
            textBeforeCursor: input.textBeforeCursor,
            textAfterCursor: "",
            reason: .textEditNativeInlineCompletionTail
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
}

// MARK: - Shared line/word helpers
//
// Used by both the generic repairs above and the Obsidian-specific repairs in
// `ObsidianCodeMirrorRepair.swift`. Free functions (rather than private methods)
// so both files can call them without threading a shared instance around.

func currentLine(in text: String) -> String {
    text.split(
        omittingEmptySubsequences: false,
        whereSeparator: \.isNewline
    ).last.map(String.init) ?? ""
}

func firstLine(in text: String) -> String {
    text.split(
        omittingEmptySubsequences: false,
        whereSeparator: \.isNewline
    ).first.map(String.init) ?? ""
}

func isPlausibleActiveTypingLine(_ line: String) -> Bool {
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

func contentWordCount(in text: String) -> Int {
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

func trailingWordFragment(in text: String) -> String? {
    text.split(whereSeparator: \.isWhitespace)
        .last
        .map(String.init)?
        .trimmingCharacters(in: .punctuationCharacters)
}

extension String {
    var containsCodeMirrorScaffolding: Bool {
        unicodeScalars.contains(where: \.isCodeMirrorScaffoldingMarker)
    }

    func trimmingCodeMirrorScaffolding() -> String {
        String(unicodeScalars.filter { scalar in
            !scalar.isCodeMirrorScaffolding
        })
    }
}

extension Unicode.Scalar {
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
