import Foundation

public struct CompletionSuggestion: Equatable, Sendable {
    public let text: String
    public let maxVisibleWords: Int

    public init(text: String, maxVisibleWords: Int = CompletionModelPolicy.mvp.maxVisibleWords) {
        self.maxVisibleWords = max(1, maxVisibleWords)
        self.text = Self.cappedText(text, wordLimit: self.maxVisibleWords)
    }

    public var visibleText: String {
        acceptedPrefix(wordLimit: maxVisibleWords)
    }

    public var visibleWordCount: Int {
        visibleText.split(whereSeparator: { $0.isWhitespace }).count
    }

    public var isEmpty: Bool {
        visibleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static func cappedText(_ text: String, wordLimit: Int) -> String {
        CompletionSuggestion(text: text, maxVisibleWordsForCappingOnly: wordLimit).acceptedPrefix(wordLimit: wordLimit)
    }

    private init(text: String, maxVisibleWordsForCappingOnly maxVisibleWords: Int) {
        self.text = text
        self.maxVisibleWords = max(1, maxVisibleWords)
    }
}
