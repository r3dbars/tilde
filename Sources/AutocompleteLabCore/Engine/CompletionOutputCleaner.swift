import Foundation

public struct CompletionOutputCleaner: Equatable, Sendable {
    public let maxVisibleWords: Int

    public init(maxVisibleWords: Int = CompletionModelPolicy.mvp.maxVisibleWords) {
        self.maxVisibleWords = max(1, maxVisibleWords)
    }

    public func clean(_ rawOutput: String) -> CompletionSuggestion? {
        let withoutThinking = rawOutput
            .replacingOccurrences(
                of: #"<think>[\s\S]*?</think>"#,
                with: "",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"</?think>"#,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'`"))

        guard !withoutThinking.isEmpty else {
            return nil
        }

        let singleLine = withoutThinking
            .components(separatedBy: .newlines)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !singleLine.isEmpty else {
            return nil
        }

        return CompletionSuggestion(text: ensureLeadingSpace(singleLine), maxVisibleWords: maxVisibleWords)
    }

    private func ensureLeadingSpace(_ text: String) -> String {
        guard let first = text.first, !first.isWhitespace else {
            return text
        }

        return " " + text
    }
}
