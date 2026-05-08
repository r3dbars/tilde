import Foundation

public enum TextContextRepairReason: String, Equatable, Sendable {
    case notesTextAfterCursorTyping = "notes-text-after-cursor-typing"
    case notesTextAfterCursorStable = "notes-text-after-cursor-stable"
}

public struct TextContextRepairInput: Equatable, Sendable {
    public let bundleIdentifier: String
    public let role: String?
    public let textBeforeCursor: String
    public let textAfterCursor: String
    public let selectedTextLength: Int
    public let previousTextBeforeCursor: String?
    public let previousTextAfterCursor: String?

    public init(
        bundleIdentifier: String,
        role: String?,
        textBeforeCursor: String,
        textAfterCursor: String,
        selectedTextLength: Int,
        previousTextBeforeCursor: String? = nil,
        previousTextAfterCursor: String? = nil
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.role = role
        self.textBeforeCursor = textBeforeCursor
        self.textAfterCursor = textAfterCursor
        self.selectedTextLength = max(0, selectedTextLength)
        self.previousTextBeforeCursor = previousTextBeforeCursor
        self.previousTextAfterCursor = previousTextAfterCursor
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
