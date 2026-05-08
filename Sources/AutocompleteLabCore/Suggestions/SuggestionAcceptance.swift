import Foundation

public extension CompletionSuggestion {
    func acceptedPrefix(wordLimit: Int) -> String {
        Self.acceptedPrefix(in: text, wordLimit: wordLimit)
    }
}
