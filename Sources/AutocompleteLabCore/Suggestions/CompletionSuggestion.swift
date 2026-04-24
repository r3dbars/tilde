import Foundation

public struct CompletionSuggestion: Equatable, Sendable {
    public let text: String
    public let maxVisibleWords: Int

    public init(text: String, maxVisibleWords: Int = CompletionModelPolicy.mvp.maxVisibleWords) {
        self.text = text
        self.maxVisibleWords = max(1, maxVisibleWords)
    }

    public var visibleText: String {
        acceptedPrefix(wordLimit: maxVisibleWords)
    }

    public var isEmpty: Bool {
        visibleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var nonEmpty: CompletionSuggestion? {
        isEmpty ? nil : self
    }
}
